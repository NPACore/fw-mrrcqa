import fcntl
import json
import logging
import os
import re
import sys
import time

WATCHDIR = os.environ.get("WATCHDIR", "/disk/mace2/scan_data/")

SETTLE_SECONDS = 5 * 60
FIRST_RUN_LOOKBACK = 2 * 3600
MAX_LOOKBACK = 24 * 3600
STUDY_SLACK = 72 * 3600
SESSION_SLACK = 48 * 3600
SERIES_SLACK = 6 * 3600
ALWAYS_WALK = {"homeless"}

FILEDIR = os.path.dirname(os.path.abspath(__file__))

STATE_FILE = os.environ.get("STATE_FILE", os.path.join(FILEDIR, "var", "poll_state.json"))
LOCK_FILE = os.environ.get("LOCK_FILE", "/tmp/listener_poll.lock")

DICOM_RE = re.compile(r"^MR\.|\.dcm$|\.IMA$")


def load_state():
    """{"cuttof": float|None, "retry": {series_dir: attempts}, "done": {key: time}}.
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
    os.makedirs(os.path.dirname(STATE_FILE) or ".", exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1, sort_keys=True)
    os.replace(tmp, STATE_FILE)


def acquire_lock():
    """Exit quietly if the previous run is still going."""
    handle = open(LOCK_FILE, "w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        logging.warning("previous run still in progress, exiting")
        sys.exit(0)
    return handle # keep a reference, the lock lives as long as this is open


def safe_scandir(path):
    """Subdirectories of path as DirEntry objects, [] if unreadable"""
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
    """Pth of the first DICOM-named file in series_dir, or None."""
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


def find_new(state, now, since=None):
    """Work out this run's window and list the series that settled in it.
    since = seconds to look back, overriding the saved cutoff (trials).
    Returns (found, counts, new_cutoff): found = {series_dir: first_dicom}.
    Changes nothing; the caller saves new_cutoff once it has dealt with found."""
    counts = {"studies": 0, "sessions": 0, "new": 0, "settling": 0}

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
    return found, counts, new_cutoff
