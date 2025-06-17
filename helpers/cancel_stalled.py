#!/usr/bin/env python3
"""
Cancel stalled jobs. likely b/c HPC is busted.
20250617: 'srun' not installed on some nodes (fixed with warewulf image update)
"""
import flywheel
from datetime import datetime
def older_than_day(rundate: datetime) -> bool:
    """
    :param rundate: time to compare to now
    :return: True if time is older than one day
    """
    return (datetime.now(tz=rundate.tzinfo) - rundate).seconds > 24*60*60

if __name__ == "__main__":
    fw = flywheel.Client()
    running = fw.jobs.find(f'state=running,gear_info.name=~mrrcqa')
    #[x.update(state='cancelled') for x in running if older_than_day(x.transitions['running'].tzinfo)]
    
    for job in running:
        #rundate = job.transitions['running']
        rundate = job.modified
        if not older_than_day(rundate):
            stat = "[continue]"
        elif os.environ.get("DRYRUN",False):
            stat="[DRYRUN skip cancelling]"
        else:
            stat="[CANCEL]"
            x.update(state='cancelled')
        print(f"{stat} {job.id} modified last on {rundate}")
