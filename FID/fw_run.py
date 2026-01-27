#! /usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "flywheel-sdk",
# ]
# ///
##
# uv run --script ./fw_run.py
# needs ~/.config/flywheel/user.json  (via 'fw login')
# 20260127: run on recontwix@recontwix

"""Run file-curate for FWHM
across Prisma QA projects on flywheel

20260109WF - adapted from ../helpers/run_all_mrrcqa.py
"""

import os
import re
import argparse
from datetime import datetime


import flywheel
DRYRUN = os.environ.get("DRYRUN")
fw = flywheel.Client()
gear = fw.lookup("gears/file-curator")
gear_name = "file-curator"             # used to check if running

gear_inputs= {}
for p in ["Prisma1QA", "Prisma2QA", "Prisma3QA"]:
    gear_inputs[p] = {
    "curator":  fw.files.find_one(f"project.label=~{p},name=~fwhm.py"),
    "additional-input-one":  fw.files.find_one(f"project.label=~{p},name=~coil.py")}


print(f"# starting {datetime.now()} (DRYRUN={DRYRUN})")
def run_gear(inputs, tags=[]):
    """Configure and run MRRCQA gear"""
    config = {"debug": False}
    job_id = gear.run(tags=tags, config=config, inputs=inputs, destination=f)
    return job_id



# Prisma1QC to Prisma3QC all have ep2d_bold dicom zips used to populate ses.info.snr
files = fw.files.find('project.label=~Prisma,type=dicom,acquisition.label=~qa_fid,name=~dcm', limit=1e10)
print(f"# {datetime.now()} found {len(files)} acq.label ep2d_bold zip files")
i = 0
for f in reversed(files):
    i += 1

    acq = fw.get(f.parents['acquisition'])
    ses = fw.get(f.parents['session'])

    if re.search('_uc_upw', acq.label):
        print(f"SKIP: {f.acquisition.label} is un-combined")

    project = fw.get(ses.parents.project).label

    print(f"# {i}/{len(files)} running for {ses.subject.code} {project} {ses.label} {f.name}")
    if val := ses.info.get('fwhm'):
        print(f"# Already have fwhm: {val}")
        continue
    # can skip if a sufficnetly new gear has been run
    # TODO: use ses objec to find db fwhm
    # try:
    #     stats_idx = [x.name for x in acq.files].index('stats.json')
    #     version = acq.files[stats_idx].gear_info.version
    #     if version.split('.')[2] >= '20250408':
    #         print(f"# SKIP! {fw.get(ses.parents.project).label}/{ses.label} acq='{acq.label}' has version {version}")
    #         continue
    #     print(f"# version too old: {fw.get(ses.parents.project).label}/{ses.label} acq='{acq.label}' {version}")
    # except ValueError:
    #     # didn't run yet?
    #     if ses.info.get('shim'):
    #         print(f"# {ses.label} has shim tag")
    #         continue

    ## is this acquistions already running?
    #  TODO: get all jobs first and then 'acq.id in [x.parents.acquisition in jobs]' instead of search each time?
    running = fw.jobs.find(f'state=running,gear_info.name=~{gear_name},parents.acquisition={acq.id}')
    if len(running) > 0:
        print(f"# SKIP! {project}/{ses.label} acq='{acq.label}' running as {running[0].id}")
        continue

    #if 'stats.json' in [x.name for x in acq.files]:
    #    print(f"# {ses.label} {acq.label} has stats.json")
    #    continue
    #if ses.info.get('snr'):
    #    print(f"# {ses.label} has stats.json")
    #    continue

    if not DRYRUN:

        inputs = {"file-input": f,
                 **gear_inputs[project]}
        print(run_gear(inputs))
