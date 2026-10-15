#/usr/bin/env python3

import asyncio
import aionotify
import os
import logging
import re
import subprocess
import importlib.util

logging.basicConfig(level=logging.DEBUG)

FOLLOW_FLAGS = (
        aionotify.Flags.CLOSE_WRITE
        | aionotify.Flags.CREATE
        | aionotify.Flags.MOVED_TO
        | aionotify.Flags.MOVED_FROM
)

OBSERVE_ONLY = True # change after knowing the pattern

FILEDIR = os.path.dirname(os.path.abspath(__file__))

RUN_FWID = os.path.join(FILEDIR, "run-fwid.py")
RUN_FWID_CWD = "/raidzeus/src/fw-mrrcqa"

_shimcheck_spec = importlib.util.spec_from_file_location(
        "shimcheck", os.path.join(FILEDIR, "shimcheck", "run.py")
)
shimcheck = importlib.util.module_from_spec(_shimcheck_spec)
_shimcheck_spec.loader.exec_module(shimcheck)

TRIGGERED_SESSIONS = set()

async def monitor_dirs(watcher):
    await watcher.setup()
    logging.debug("watching for new files")

    while True:
        # TODO: incomming event is project/yyyy.mm.dd session directory?
        #       need to watch those for changes (and maybe remove after it's done)
        # to tigger on new dcms, need to watch project/yyy.mm.../scan_folder/MR*
        # 2 deeper than currrent.
        # keep list of what's tracked? watcher.watch() stores this somewhere?
        # knock out whats in the list when too old
        event = await watcher.get_event()
        logging.debug("got event %s", event)
        file = os.path.join(event.alias, event.name)

        if os.path.isdir(file):
            # a new session folder appeared
            if safe_watch(watcher,file):
                logging.info("%s is a new session dir, watching", file)
            continue

        if event.flags == aionotify.Flags.CREATE:
            logging.debug("file created but waiting for WRITE finish")
            continue

        session_dir = event.alias

        if session_dir in TRIGGERED_SESSIONS:
            logging.debug("already fired for %s, skipping %s", session_dir, event.name)
            continue

        if not re.search(r"^MR\.|\.dcm$|\.IMA$", event.name):
            logging.warning("non dicom file %s, ignoring", event.name)
            continue

        TRIGGERED_SESSIONS.add(session_dir)
        logging.info("first dicom for new session %s -> firing run-fwid on %s", session_dir, event.name)
        
        if not OBSERVE_ONLY:
            subprocess.Popen(["python3", RUN_FWID, session_dir], cwd=RUN_FWID_CWD)
        
        if not OBSERVE_ONLY:
            try:
                dcm = shimcheck.first_dicom_from(file)
                z = shimcheck.read_z(dcm)
                verdict = "PASS" if z >= shimcheck.LOW_THRESHOLD else "FAIL"
                logging.info(
                        "shim check %s: station=%s z=%s (threshold=%s) session=%s",
                        verdict, dcm.StationName, z, shimcheck.LOW_THRESHOLD, session_dir,
                )
            except Exception:
                logging.exception("shim check failed for %s, skipping", file)

def safe_watch(watcher, path):
    try:
        watcher.watch(path=path, flags=FOLLOW_FLAGS)
        return True
    except OSError as e:
        logging.warning("can't watch %s (%s), skipping", path, e)
        return False

async def main():
    watcher = aionotify.Watcher()
    watchdir = "/disk/mace2/scan_data/" # TODO: make ENV for testing
    safe_watch(watcher, watchdir)

    for entry in os.scandir(watchdir):
        if entry.is_dir():
            safe_watch(watcher, entry.path)
    
    logging.info("watching %d top-level dirs under %s", sum(1 for e in os.scandir(watchdir) if e.is_dir()), watchdir)

    await monitor_dirs(watcher)

if __name__ == "__main__":
    asyncio.run(main())
