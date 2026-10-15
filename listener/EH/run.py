#/usr/bin/env python3

import asyncio
import aionotify
import os
import logging
import re
import subprocess
import importlib.util

logging.basicConfig(level=logging.DEBUG)

FOLLOW_FLAGS = aionotify.Flags.CLOSE_WRITE | aionotify.Flags.CREATE

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
        event = await watcher.get_event()
        logging.debug("got event %s", event)
        file = os.path.join(event.alias, event.name)

        if os.path.isdir(file):
            # a new session folder appeared
            watcher.watch(path=file, flags=FOLLOW_FLAGS)
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
        subprocess.Popen(["python3", RUN_FWID, session_dir], cwd=RUN_FWID_CWD)
        
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

async def main():
    watcher = aionotify.Watcher()
    watchdir = "/raidzeus/src/fw-mrrcqa/listener/testing/"
    watcher.watch(path=watchdir, flags=FOLLOW_FLAGS)
    await monitor_dirs(watcher)

if __name__ == "__main__":
    asyncio.run(main())
