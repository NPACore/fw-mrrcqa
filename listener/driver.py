#!/usr/bin/env python3
"""
One-shot driver for cron: find the series on /disk/mace2/scan_data that settled
since the previous run, pick a pipeline for each with RULES, run it, save the
new cutoff, exit.

Finding the new series (windows, state file, lock) is poller.py's job; this file
decides what to do with each one and does it. State is kept in var/poll_state.json.

What runs on a series is decided by RULES below (study + series name). Series
that match no rule are only counted, never run.

Needs poller.py, shim.py, tsnr.py, settings.py, mailer_func.py and config/ next to this file.

Usage:
    driver.py             # normal run (what cron calls)
    driver.py --seed      # move the cutoff to "now" WITHOUT running anything --
                          # run once before turning OBSERVE_ONLY off
                          # so going live doesn't backfill
    driver.py --since 24  # ignore the saved cutoff, look back 24 hours
                          # (for trials; with OBSERVE_ONLY it just logs)
"""

import json
import logging
import os
import re
import shlex
import sys
import tempfile
import time
from email.message import EmailMessage

import mailer_func
import settings
import poller
import shim
import tsnr
from poller import acquire_lock, first_dicom, load_state, save_state

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

OBSERVE_ONLY = True  # flip to False once the rules/outputs look right

# A launch that raises is retried on later runs, up to this many attempts.
MAX_ATTEMPTS = 3
# "once_per" bookkeeping is forgotten after this long.
DONE_KEEP = 3 * 24 * 3600
# Pipelines that only read data, so they also run while OBSERVE_ONLY is on.
READ_ONLY_PIPELINES = {"shim"}
# Real emails go out only when this is True; otherwise the email is just logged.
SEND_EMAIL = False
EMAIL_TOML = os.path.join(settings.CONFIG_DIR, "email.toml")

# Which series get which pipeline. Each rule is matched (case-insensitive,
# re.search) against the path parts below the scan folder (poller.WATCHDIR):
#     <study>/<session>/<subject-or-visit>/<series>
# First matching rule wins. A series that matches NO rule is only counted in the
# summary line, never run -- so new studies are safe by default.
# pipelines: "tsnr" = tSNR phantom QA (MATLAB Singularity container, see tsnr.py)
#            "shim" = Z-shim check from the CSA header (per-scanner threshold)
# once_per:  "session" = only the first series (lowest number) of each session
# session:   optional regex for the 2nd path part (homeless/<patient>/... layout)
RULES = [
    {"name": "phantom-qa",
     "study": r"^PRISMA\dQC$",
     "series": r"^ep2d_bold_p2_s2_5min",
     "pipelines": ["tsnr"]},
    # Prisma1/2/3 daily phantoms land in homeless/Brain^PrismaNQC/<session>/PRISMANQA<date>/<series>
    {"name": "phantom-qa-homeless",
     "study": r"^homeless$",
     "session": r"^Brain\^Prisma\dQC$",
     "series": r"^ep2d_bold_p2_s2_5min",
     "pipelines": ["tsnr"]},
    # Every study except the phantom folders. The shim value is the same for the
    # whole session, so one series per session is enough.
    {"name": "shim",
     "study": r"^(?!PRISMA\dQC$|homeless$)",
     "series": r".",
     "pipelines": ["shim"],
     "once_per": "session"},
]


# ----------------------------------------------------------------- rules / run

def match_rule(series_dir):
    """First RULES entry matching this series' study and series names, or None."""
    parts = os.path.relpath(series_dir, poller.WATCHDIR).split(os.sep)
    if len(parts) < 4:
        return None
    study, session, series = parts[0], parts[1], parts[-1]
    for rule in RULES:
        if not (re.search(rule["study"], study, re.I) and re.search(rule["series"], series, re.I)):
            continue
        if "session" in rule and not re.search(rule["session"], session, re.I):
            continue
        return rule
    return None


def run_tsnr(series_dir, dcm_path):
    """Run the tSNR container on one phantom series and wait for it to finish.
    Raises if the container fails or times out (so the series is retried)."""
    outdir = tsnr.run(dcm_path)
    logging.info("tsnr done: %s -> %s", os.path.relpath(series_dir, poller.WATCHDIR), outdir)


def send_email(subject, body):
    """Send one email with Mallory's mailer_func.mailer(), which is left as she
    wrote it. That function sends the `msg` text from a TOML file, as plain
    ASCII, so here the whole email (headers included) is built as an ASCII-safe
    MIME message -- the check marks and symbols are encoded -- and put in as
    `msg` in a temporary copy of config/email.toml. Everything else (to, from,
    ...) is copied from the real file."""
    cfg = settings.load_toml(EMAIL_TOML)
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = cfg["from"]
    msg["To"] = cfg["to"] if isinstance(cfg["to"], str) else ", ".join(cfg["to"])
    msg.set_content(body, charset="utf-8", cte="base64")
    cfg["msg"] = msg.as_string()
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "email.toml")
        with open(path, "w") as f:
            for key, value in cfg.items():
                f.write(f"{key} = {json.dumps(value)}\n")  # JSON strings/lists are valid TOML
        mailer_func.mailer(path)


def shim_message(result, session):
    """(subject, body) of the email for one shim.check() result, e.g.
        ⛔ P2 z ShimQA BAD
        P2 ⛔: z=4397.00 < 4505.26 – BAD SHIM
        Session: <study>/<session>"""
    name, z, threshold = result["scanner"], result["z"], result["threshold"]
    if result["ok"]:
        return (f"✅ {name} z ShimQA okay",
                f"{name} ✅: z={z:.2f} ≥ {threshold:.2f} – value okay.\nSession: {session}")
    return (f"⛔ {name} z ShimQA BAD",
            f"{name} ⛔: z={z:.2f} < {threshold:.2f} – BAD SHIM\nSession: {session}")


def run_shim(series_dir, dcm_path):
    """Check the Z shim of one series, log PASS/FAIL against the scanner's
    threshold, and email the result (see SEND_EMAIL). Returns shim.check's
    result. Raises if the DICOM can't be read."""
    result = shim.check(dcm_path)
    where = os.path.relpath(series_dir, poller.WATCHDIR)
    if result["threshold"] is None:
        logging.warning("shim: unknown scanner %s, z=%.2f, no threshold set -- add it to config/shim.toml (%s)",
                        result["station"], result["z"], where)
    else:
        logging.info("shim %s: %s (StationName=%s) z=%.2f threshold=%.2f  %s",
                     "PASS" if result["ok"] else "FAIL", result["scanner"], result["station"],
                     result["z"], result["threshold"], where)
        subject, body = shim_message(result, session_key(series_dir))
        if SEND_EMAIL:
            send_email(subject, body)
        else:
            logging.info("SEND_EMAIL is off: would email '%s' -- %s", subject, body)
    return result


PIPELINES = {"tsnr": run_tsnr, "shim": run_shim}


def session_key(series_dir):
    """<study>/<session> part of a series path."""
    return os.sep.join(os.path.relpath(series_dir, poller.WATCHDIR).split(os.sep)[:2])


def series_sort_key(series_dir):
    """Group by parent folder, then by series number (the .N suffix)."""
    m = re.search(r"\.(\d+)$", os.path.basename(series_dir))
    return (os.path.dirname(series_dir), int(m.group(1)) if m else 10**9, series_dir)


def fire_trigger(series_dir, dcm_path, rule):
    for name in rule["pipelines"]:
        if OBSERVE_ONLY and name not in READ_ONLY_PIPELINES:
            logging.info("OBSERVE_ONLY: rule '%s' would run [%s] on %s (first dicom %s)",
                         rule["name"], name, series_dir, os.path.basename(dcm_path))
            if name == "tsnr":
                try:  # reading the header is harmless, so show exactly what would be run
                    logging.info("OBSERVE_ONLY: tsnr command would be: %s", shlex.join(tsnr.command(dcm_path)[2]))
                except Exception as e:
                    logging.warning("OBSERVE_ONLY: can't work out the tsnr command for %s (%s)", series_dir, e)
            continue
        logging.info("rule '%s' -> running [%s] on %s", rule["name"], name, series_dir)
        PIPELINES[name](series_dir, dcm_path)


def poll_once(state, now=None, seed=False, since=None):
    """One scan. Updates state['cutoff'], state['retry'] and state['done'] in place.
    since = seconds to look back, overriding the saved cutoff (trials)."""
    now = time.time() if now is None else now
    found, counts, new_cutoff = poller.find_new(state, now, since)
    counts.update({"retried": 0, "failed": 0, "gave_up": 0, "unmatched": 0, "skipped": 0})

    retry = state["retry"]
    state["retry"] = {}
    done = state.setdefault("done", {})
    if not seed:
        counts["retried"] = len([p for p in retry if p not in found])
        targets = {p: None for p in retry}
        targets.update(found)
        for series_dir, dcm_path in sorted(targets.items(), key=lambda kv: series_sort_key(kv[0])):
            rule = match_rule(series_dir)
            if rule is None:
                counts["unmatched"] += 1
                logging.debug("no rule for %s, not running", series_dir)
                continue
            once_key = None
            if rule.get("once_per") == "session":
                once_key = f"{rule['name']}|{session_key(series_dir)}"
                if once_key in done:
                    counts["skipped"] += 1
                    continue
            if dcm_path is None:
                dcm_path = first_dicom(series_dir)
                if dcm_path is None:
                    logging.warning("retry target %s is gone or empty, dropping", series_dir)
                    continue
            try:
                fire_trigger(series_dir, dcm_path, rule)
            except Exception:
                attempts = retry.get(series_dir, 0) + 1
                if attempts >= MAX_ATTEMPTS:
                    logging.exception("trigger failed for %s %d times, giving up", series_dir, attempts)
                    counts["gave_up"] += 1
                else:
                    logging.exception("trigger failed for %s (attempt %d), will retry next run",
                                      series_dir, attempts)
                    state["retry"][series_dir] = attempts
                    counts["failed"] += 1
            else:
                if once_key:
                    done[once_key] = now
    for key in [k for k, t in done.items() if t < now - DONE_KEEP]:
        del done[key]

    state["cutoff"] = new_cutoff
    return counts


def main():
    args = sys.argv[1:]
    seed = "--seed" in args
    since = float(args[args.index("--since") + 1]) * 3600 if "--since" in args else None
    lock = acquire_lock()  # noqa: F841 (held for the life of the process)
    started = time.time()

    try:
        scanners = shim.load_config()
    except Exception as e:
        logging.error("can't load config/shim.toml (%s); not continuing", e)
        sys.exit(1)
    if SEND_EMAIL and not os.path.exists(EMAIL_TOML):
        logging.error("SEND_EMAIL is on but %s is missing; not running", EMAIL_TOML)
        sys.exit(1)
    logging.info("shim.toml: %d scanners (%s)", len(scanners), ", ".join(n for n, _ in scanners.values()))

    state = load_state()
    first_run = not os.path.exists(poller.STATE_FILE)

    counts = poll_once(state, started, seed=seed, since=since)
    save_state(state)  # only reached if the scan finished, so a crash re-covers the window

    logging.info(
        "%s complete: %d recent studies, %d recent sessions, %d %s (%d without a rule), "
        "%d retried, %d settling, %d failed, %d gave up, %d already checked (%.1fs)%s",
        "seed" if seed else "run", counts["studies"], counts["sessions"], counts["new"],
        "marked handled" if seed else "new series", counts["unmatched"], counts["retried"],
        counts["settling"], counts["failed"], counts["gave_up"], counts["skipped"],
        time.time() - started,
        " [first run, no prior state]" if first_run else "",
    )


if __name__ == "__main__":
    main()
