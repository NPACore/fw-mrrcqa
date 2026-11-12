#!/usr/bin/env python3
"""
Driver for the scan listener. Cron runs this every 5 minutes.
"""

import logging
import time
import os
import json
import tempfile
from email.message import EmailMessage

import tsnr
import mailer_func
import settings
import shim
import poller

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
SEND_EMAIL = True
EMAIL_TOML = os.path.join(settings.CONFIG_DIR, "email.toml")
RUN_TSNR = True
MAX_ATTEMPTS = 3
DONE_KEEP = 3 * 24 * 3600

PHANTOM_STUDIES = ["PRISMA1QC", "PRISMA2QC", "PRISMA3QC"]
PHANTOM_HOMELESS = ["Brain^Prisma1QC", "Brain^Prisma2QC", "Brain^Prisma3QC"]

def is_phantom(series_dir):
    """True if this series folder belongs to a daily QA session."""
    parts = os.path.relpath(series_dir, poller.WATCHDIR).split(os.sep)
    if parts[0] in PHANTOM_STUDIES:
        return True
    if parts[0] == "homeless" and parts[1] in PHANTOM_HOMELESS:
        return True
    return False


def is_bold(series_dir):
    """True for the phantom BOLD series, the one the tSNR container runs on."""
    name = os.path.basename(series_dir)
    return name.startswith("ep2d_bold_p2_s2_5min")


def session_of(series_dir):
    """The session folder a series belongs to: two folders up from the series."""
    return os.path.dirname(os.path.dirname(series_dir))


def check_shim(dcm_path):
    """Read the Z shim from one DICOM file and log whether it passes."""
    result = shim.check(dcm_path)
    if result["threshold"] is None:
        logging.warning("shim: unknown scanner %s, z=%.2f", result["station"], result["z"])
        return result
    if result["ok"]:
        word = "PASS"
    else:
        word = "FAIL"
    logging.info("shim %s: %s z=%.2f threshold=%.2f",
            word, result["scanner"], result["z"], result["threshold"])
    return result


def shim_message(result, session):
    """The subject and body of the email for one shim result."""
    scanner = result["scanner"]
    z = result["z"]
    threshold = result["threshold"]
    where = os.path.relpath(session, poller.WATCHDIR)
    if result["ok"]:
        subject = f"✅ {scanner} z ShimQA okay"
        body = f"{scanner} ✅: z={z:.2f} ≥ {threshold:.2f} – value okay.\nSession: {where}"
    else:
        subject = f"⛔ {scanner} z ShimQA BAD"
        body = f"{scanner} ⛔: z={z:.2f} < {threshold:.2f} – BAD SHIM\nSession: {where}"
    return subject, body


def send_email(subject, body):
    """Send one emial through mailer_func.mailer()."""
    config = settings.load_toml(EMAIL_TOML)

    # build the email, encoded so the emojis travel as plain text
    email = EmailMessage()
    email["Subject"] = subject
    email["From"] = config["from"]
    if isinstance(config["to"], str):
        email["To"] = config["to"]
    else:
        email["To"] = ", ".join(config["to"])
    email.set_content(body, charset="utf-8", cte="base64")

    config["msg"] = email.as_string()
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "email.toml")
        with open(path, "w") as f:
            for key in config:
                f.write(key + " = " + json.dumps(config[key]) + "\n")
        mailer_func.mailer(path)


def handle_series(series_dir, dcm_path, state, now):
    """Do the right thing for the new series."""
    if not is_phantom(series_dir):
        return

    if is_bold(series_dir):
        if RUN_TSNR:
            outdir = tsnr.run(dcm_path)
            logging.info("tsnr done: %s", outdir)
        else:
            logging.info("would run tsnr on: %s", series_dir)
        return

    session = session_of(series_dir)
    if session in state["done"]:
        return


    try:
        result = check_shim(dcm_path)
    except ValueError as error:
        logging.info("no shim value (%s), will try the next series: %s", error, series_dir)
        return

    if result["threshold"] is not None:
        subject, body = shim_message(result, session)
        if SEND_EMAIL:
            send_email(subject, body)
            logging.info("email: %s", subject)
        else:
            logging.info("would email: %s", subject)
            logging.info("would email: %s", body)
    state["done"][session] = now


def main():
    lock = poller.acquire_lock()
    state = poller.load_state()
    now = time.time()

    found, counts, new_cutoff = poller.find_new(state, now)
    
    # series that faield on an earlier run get another try
    old_retry = state["retry"]
    state["retry"] = {}
    todo = dict(found)
    for series_dir in old_retry:
        if series_dir not in todo:
            todo[series_dir] = poller.first_dicom(series_dir)

    for series_dir in sorted(todo):
        dcm_path = todo[series_dir]
        if dcm_path is None:
            logging.warning("retry series is gone or empty, dropping: %s", series_dir)
            continue
        try:
            handle_series(series_dir, dcm_path, state, now)
        except Exception:
            attempts = old_retry.get(series_dir, 0) + 1
            if attempts < MAX_ATTEMPTS:
                logging.exception("failed (attempt %d), will retry next run: %s", attempts, series_dir)
                state["retry"][series_dir] = attempts
            else:
                logging.exception("failed %d times, giving up: %s", attempts, series_dir)

    # forget sessions that were checked more than 3 days ago
    for session in list(state["done"]):
        if state["done"][session] < now - DONE_KEEP:
            del state["done"][session]

    state["cutoff"] = new_cutoff
    poller.save_state(state)
    logging.info("done: %d new series, %d to retry", len(found), len(state["retry"]))

if __name__ == "__main__":
    main()
