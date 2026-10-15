#!/usr/bin/env python3
"""
One-shot poller for cron: scan /disk/mace2/scan_data once, handle every
series that settled since the previous run, save the new cutoff, exit.

How "new" is decided: each run handles series whose folder mtime falls in
    [previous run's cutoff, this run's cutoff)
where cutoff = (time of run) - SETTLE_SECONDS. The next run starts exactly
where this one stopped, so nothing is missed and nothing is handled twice,
and if cron skips a run the next one just covers the longer gap. The only
state is that one number (plus a short retry list for failed launches).

Series newer than the cutoff are still "settling" (upload may be in
progress); they fall into the next run's window automatically.

What runs on a new series is decided by RULES below (study + series name).
Series that match no rule are only counted, never run.

Usage:
    mace2_poll_cron.py             # normal run (what cron calls)
    mace2_poll_cron.py --seed      # move the cutoff to "now" WITHOUT firing --
                                   # run once before turning OBSERVE_ONLY off
                                   # so going live doesn't backfill
    mace2_poll_cron.py --since 24  # ignore saved cutoff, look back 24 hours
                                   # (for trials; with OBSERVE_ONLY it just logs)
"""

import fcntl
import importlib.util
import json
import logging
import os
import re
import subprocess
import sys
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

OBSERVE_ONLY = True  # flip to False once the rules/outputs look right

WATCHDIR = os.environ.get("MACE2_WATCHDIR", "/disk/mace2/scan_data/")

# A series is handled once its folder has been quiet this long (upload done).
SETTLE_SECONDS = 5 * 60
# With no saved cutoff (first run), look back this far.
FIRST_RUN_LOOKBACK = 2 * 3600
# Never look back further than this, even if cron was down for days.
MAX_LOOKBACK = 24 * 3600
# Study/session folders are stamped once, when the session starts, so they
# can be much older than the series being written inside them. These only
# limit which parts of the tree get walked.
STUDY_SLACK = 72 * 3600
SESSION_SLACK = 48 * 3600
# A launch that raises is retried on later runs, up to this many attempts.
MAX_ATTEMPTS = 3
# "once_per" bookkeeping is forgotten after this long.
DONE_KEEP = 3 * 24 * 3600
# A folder whose own mtime is older than the window by more than this can't
# hold a series written inside the window (a series folder appears when the
# series starts and is finished within this long), so it isn't walked.
SERIES_SLACK = 6 * 3600
# Top-level folders whose layout isn't <study>/<session>/..., so their own
# mtime says nothing about new sessions (their children are patient folders):
# always look inside.
ALWAYS_WALK = {"homeless"}

# Z-shim threshold per scanner, keyed by the DICOM StationName.
# (values taken from file-curator/examples/shim_settings.toml)
SCANNERS = {
    "MRC67078":  ("P1", 9931.513661),
    "AWP167046": ("P2", 4505.258657),
    "MRC35073":  ("P3", 11652.571269),
}
# Pipelines that only read data, so they also run while OBSERVE_ONLY is on.
READ_ONLY_PIPELINES = {"shim"}

FILEDIR = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.environ.get("MACE2_STATE", os.path.join(FILEDIR, "mace2_poll_state.json"))
LOCK_FILE = os.environ.get("MACE2_LOCK", "/tmp/mace2_poll.lock")  # local disk: flock is unreliable on NFS
RUN_FWID = os.path.join(FILEDIR, "run-fwid.py")
RUN_FWID_CWD = "/raidzeus/src/fw-mrrcqa"

DICOM_RE = re.compile(r"^MR\.|\.dcm$|\.IMA$")

# Which series get which pipeline. Each rule is matched (case-insensitive,
# re.search) against the path parts below WATCHDIR:
#     <study>/<session>/<subject-or-visit>/<series>
# First matching rule wins. A series that matches NO rule is only counted in
# the summary line, never run -- so new studies are safe by default.
# pipelines: "qa"   = run-fwid.py (dcm2niix + MATLAB QA container)
#            "shim" = Z-shim check from the CSA header (per-scanner threshold)
# once_per:  "session" = only the first series (lowest number) of each session
# session:   optional regex for the 2nd path part (homeless/<patient>/... layout)
RULES = [
    {"name": "phantom-qa",
     "study": r"^PRISMA\dQC$",
     "series": r"^ep2d_bold_p2_s2_5min",
     "pipelines": ["qa"]},
    # Prisma1/2/3 daily phantoms land in homeless/Brain^PrismaNQC/<session>/PRISMANQA<date>/<series>
    {"name": "phantom-qa-homeless",
     "study": r"^homeless$",
     "session": r"^Brain\^Prisma\dQC$",
     "series": r"^ep2d_bold_p2_s2_5min",
     "pipelines": ["qa"]},
    # Every study except the phantom folders. The shim value is the same for the
    # whole session, so one series per session is enough.
    {"name": "shim",
     "study": r"^(?!PRISMA\dQC$|homeless$)",
     "series": r".",
     "pipelines": ["shim"],
     "once_per": "session"},
]

_shimcheck = None


def get_shimcheck():
    """Load shimcheck lazily so observe-only runs don't need nibabel/pydicom."""
    global _shimcheck
    if _shimcheck is None:
        try:
            import flywheel  # noqa: F401
        except ImportError:
            # shimcheck/run.py imports the Flywheel SDK at the top but the
            # functions we use never touch it; a stand-in lets the import work.
            import types
            fw = types.ModuleType("flywheel")
            fw.GearContext = object
            sys.modules["flywheel"] = fw
        spec = importlib.util.spec_from_file_location(
            "shimcheck", os.path.join(FILEDIR, "shimcheck", "run.py")
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _shimcheck = module  # only set once the import fully worked
    return _shimcheck


def load_state():
    """{"cutoff": float|None, "retry": {series_dir: attempts}, "done": {key: time}}.
    Missing file = first run. Unreadable file = stop: silently starting fresh
    could skip or repeat a stretch of scans."""
    if not os.path.exists(STATE_FILE):
        return {"cutoff": None, "retry": {}, "done": {}}
    try:
        with open(STATE_FILE) as f:
            raw = json.load(f)
        retry = {str(k): int(v) for k, v in dict(raw.get("retry", {})).items()}
        done = {str(k): float(v) for k, v in dict(raw.get("done", {})).items()}
        return {"cutoff": float(raw["cutoff"]), "retry": retry, "done": done}
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as e:
        logging.error("state file %s unreadable (%s); fix or delete it, not continuing", STATE_FILE, e)
        sys.exit(1)


def save_state(state):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1, sort_keys=True)
    os.replace(tmp, STATE_FILE)  # atomic: a crash can't leave half a file


def acquire_lock():
    """Exit quietly if the previous run is still going."""
    handle = open(LOCK_FILE, "w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        logging.warning("previous run still in progress, exiting")
        sys.exit(0)
    return handle  # keep a reference; the lock lives as long as this is open


def safe_scandir(path):
    """Subdirectories of path as DirEntry objects; [] if unreadable."""
    try:
        with os.scandir(path) as it:
            return [e for e in it if e.is_dir()]
    except OSError as e:
        logging.warning("can't list %s (%s), skipping", path, e)
        return []


def mtime_of(entry_or_path):
    """Folder mtime, or None if unreadable."""
    try:
        if isinstance(entry_or_path, os.DirEntry):
            return entry_or_path.stat().st_mtime
        return os.stat(entry_or_path).st_mtime
    except OSError:
        return None


def newer_than(entry_or_path, t):
    m = mtime_of(entry_or_path)
    return m is not None and m >= t


def first_dicom(series_dir):
    """Path of the first DICOM-named file in series_dir, or None."""
    try:
        names = sorted(f for f in os.listdir(series_dir) if DICOM_RE.search(f))
    except OSError:
        return None
    return os.path.join(series_dir, names[0]) if names else None


def find_series(session_path, last_cutoff, new_cutoff, counts):
    """Series dirs under session_path holding a DICOM whose mtime is in
    [last_cutoff, new_cutoff). Newer ones are still settling and are left for
    the next run. Yields (series_dir, first_dicom)."""
    for dirpath, dirnames, filenames in os.walk(session_path):
        # don't descend into folders that stopped changing long before the window
        dirnames[:] = [d for d in dirnames
                       if newer_than(os.path.join(dirpath, d), last_cutoff - SERIES_SLACK)]
        matches = sorted(f for f in filenames if DICOM_RE.search(f))
        if not matches:
            continue
        m = mtime_of(dirpath)
        if m is None or m < last_cutoff:
            continue
        if m >= new_cutoff:
            counts["settling"] += 1
            continue
        yield dirpath, os.path.join(dirpath, matches[0])


def match_rule(series_dir):
    """First RULES entry matching this series' study and series names, or None."""
    parts = os.path.relpath(series_dir, WATCHDIR).split(os.sep)
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


def run_qa(series_dir, dcm_path):
    # sys.executable = the Python running us, so cron uses the venv's Python
    subprocess.Popen([sys.executable, RUN_FWID, series_dir], cwd=RUN_FWID_CWD)


def run_shim(series_dir, dcm_path):
    """Read the Z shim from one DICOM and log PASS/FAIL against the scanner's
    threshold. Logging only -- nothing is sent anywhere. Raises if the DICOM
    can't be read (so the next series in the session is tried)."""
    shimcheck = get_shimcheck()
    dcm = shimcheck.first_dicom_from(dcm_path)
    z = float(shimcheck.read_z(dcm))
    station = (getattr(dcm, "StationName", "") or "").strip() or "UNKNOWN"
    where = os.path.relpath(series_dir, WATCHDIR)
    name, threshold = SCANNERS.get(station, (station, None))
    if threshold is None:
        logging.warning("shim: unknown scanner %s, z=%.2f, no threshold set -- add it to SCANNERS (%s)",
                        station, z, where)
        return
    ok = z >= threshold
    logging.info("shim %s: %s (StationName=%s) z=%.2f threshold=%.2f  %s",
                 "PASS" if ok else "FAIL", name, station, z, threshold, where)


PIPELINES = {"qa": run_qa, "shim": run_shim}


def session_key(series_dir):
    """<study>/<session> part of a series path."""
    return os.sep.join(os.path.relpath(series_dir, WATCHDIR).split(os.sep)[:2])


def series_sort_key(series_dir):
    """Group by parent folder, then by series number (the .N suffix)."""
    m = re.search(r"\.(\d+)$", os.path.basename(series_dir))
    return (os.path.dirname(series_dir), int(m.group(1)) if m else 10**9, series_dir)


def fire_trigger(series_dir, dcm_path, rule):
    for name in rule["pipelines"]:
        if OBSERVE_ONLY and name not in READ_ONLY_PIPELINES:
            logging.info("OBSERVE_ONLY: rule '%s' would run [%s] on %s (first dicom %s)",
                         rule["name"], name, series_dir, os.path.basename(dcm_path))
            continue
        logging.info("rule '%s' -> running [%s] on %s", rule["name"], name, series_dir)
        PIPELINES[name](series_dir, dcm_path)


def poll_once(state, now=None, seed=False, since=None):
    """One scan. Updates state['cutoff'] and state['retry'] in place.
    since = seconds to look back, overriding the saved cutoff (trials)."""
    now = time.time() if now is None else now
    counts = {"studies": 0, "sessions": 0, "new": 0, "retried": 0,
              "settling": 0, "failed": 0, "gave_up": 0, "unmatched": 0, "skipped": 0}

    if since is not None:
        last_cutoff = now - since
    elif state["cutoff"] is None:
        last_cutoff = now - FIRST_RUN_LOOKBACK
    else:
        last_cutoff = state["cutoff"]
    floor = now - MAX_LOOKBACK
    if last_cutoff < floor:
        logging.warning("last cutoff is older than %dh (cron down?); only looking back that far",
                        MAX_LOOKBACK // 3600)
        last_cutoff = floor
    new_cutoff = max(now - SETTLE_SECONDS, last_cutoff)  # never move backwards
    logging.info("window: %s -> %s", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(last_cutoff)),
                 time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(new_cutoff)))

    found = {}
    for study in safe_scandir(WATCHDIR):
        if study.name not in ALWAYS_WALK and not newer_than(study, last_cutoff - STUDY_SLACK):
            continue
        counts["studies"] += 1
        for session in safe_scandir(study.path):
            if not newer_than(session, last_cutoff - SESSION_SLACK):
                continue
            counts["sessions"] += 1
            for series_dir, dcm_path in find_series(session.path, last_cutoff, new_cutoff, counts):
                found[series_dir] = dcm_path
    counts["new"] = len(found)

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
    state = load_state()
    first_run = not os.path.exists(STATE_FILE)

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
