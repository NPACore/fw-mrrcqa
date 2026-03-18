#!/usr/bin/env python3
"""
Cancel stalled jobs. likely b/c HPC is busted.
20250617: 'srun' not installed on some nodes (fixed with warewulf image update)
20260305: add environ variables; switch back to run instead of mod time (always within 8 seconds?!)
          here becuaes 84/~900 fw-mrrcqa rerun failed in slurm but didn't cancel job?
JOBAGE_SECONDS=3000 VERBOSE=1 DRYRUN=1 ./cancel_stalled.py
"""
import os
import flywheel
from datetime import datetime
VERBOSE = os.environ.get("VERBOSE")

def older_than_day(rundate: datetime) -> bool:
    """
    :param rundate: time to compare to now
    :return: True if time is older than one day
    """
    max_age = int(os.environ.get("JOBAGE_SECONDS", 24*60*60))  # 86400
    current_age = (datetime.now(tz=rundate.tzinfo) - rundate).total_seconds()
    if VERBOSE:
        print(f"current age: {current_age}")
    return current_age > max_age

if __name__ == "__main__":
    fw = flywheel.Client()
    running = fw.jobs.find(f'state=running,gear_info.name=~mrrcqa')
    #[x.update(state='cancelled') for x in running if older_than_day(x.transitions['running'].tzinfo)]
    
    for job in running:
        rundate = job.transitions['running']
        #rundate = job.modified
        if VERBOSE:
            print(job.transitions)
        if not older_than_day(rundate):
            stat = "[continue]"
        elif os.environ.get("DRYRUN",False):
            stat="[DRYRUN skip cancelling]"
        else:
            stat="[CANCEL]"
            job.update(state='cancelled')
        print(f"{stat} {job.id} modified last on {rundate}")
