#! /usr/bin/env python3
"""Run mrrcqa on all "ep2d_bold_p2_s2_5min" acquisition's that have not been run

20241227WF - used flywheel-tutorials' copy-job.py to build initial gear.run call
"""

import os
import argparse
from datetime import datetime


import flywheel
DRYRUN = os.environ.get("DRYRUN")
fw = flywheel.Client()
mrrcqa_gear = fw.lookup("gears/mrrcqa")

def run_mrrcqa(f: flywheel.models.file_output.FileOutput):
    """Configure and run MRRCQA gear"""
    config = {"write_db": True}
    tags = ["mrrcqa", "hpc"]
    inputs = {'phantom_dicom': f}
    job_id = mrrcqa_gear.run(tags=tags, config=config, inputs=inputs, destination=f)
    return job_id


# Prisma1QC to Prisma3QC all have ep2d_bold dicom zips used to populate ses.info.snr
files = fw.files.find('project.label=~Prisma,type=dicom,acquisition.label=~ep2d_bold_.*5min,name=~zip')
for f in files:
    acq = fw.get(f.parents['acquisition'])
    ses = fw.get(f.parents['session'])

    # can skip if a sufficnetly new gear has been run
    try:
        stats_idx = [x.name for x in acq.files].index('stats.json')
        version = acq.files[stats_idx].gear_info.version
        if version.split('.')[2] >= '20250301':
            print(f"# SKIP! {fw.get(ses.parents.project).label}/{ses.label} acq='{acq.label}' has version {version}")
            continue
        print(f"# version too old: {fw.get(ses.parents.project).label}/{ses.label} acq='{acq.label}' {version}")
    except ValueError:
        pass

    #if 'stats.json' in [x.name for x in acq.files]:
    #    print(f"# {ses.label} {acq.label} has stats.json")
    #    continue
    #if ses.info.get('snr'):
    #    print(f"# {ses.label} has stats.json")
    #    continue

    print(f"running for {ses.subject.code} {ses.label} {f.name}")
    if not DRYRUN:
        print(run_mrrcqa(f))
