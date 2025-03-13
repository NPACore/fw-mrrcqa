#!/usr/bin/env python3
"""
Flywheel wrapper for octave stats generating routine.

1. unzip dicom specified as 'phantom_dicom'
2. run octave
3. writes 'snr' to session flywheel data container

The software container described by 'Dockerfile' can work independently of flywheel.
And will run the matlab (octave) QC.m

    ENTRYPOINT ["${FLYWHEEL}/QC.m"]

For Flywheel specific execution, manifest.json specifies this file

    "command": "/flywheel/v0/run.py"

In either, the base directory is `/flywheel/v0` (``$FLYWHEEL``)


This runs as a "SDK gear" and needs to be given read-write access to add 'info.snr' to the session's data container.

The python code to write to FW's database was modernized from the very helpful write on https://pennlinc.github.io/docs/flywheel/Gear_development/
"""

import sys
import os
import subprocess
import flywheel
import json # for reading matlab output
#import nibabel as nib
#import numpy as np

def update_db(context: flywheel.GearContext):
    """
    Flywheel SDK gear style DB update: write snr peak value to sess.info.snr
    Requires write permission when used as a gear rule.

    Implemented with help from
    https://pennlinc.github.io/docs/flywheel/Gear_development/

    :param context: implicit context when running as a gear
    """
    with open('/flywheel/v0/outputs/stats.json', 'r') as f:
        stats = json.load(f)
    #fw = flywheel.Client(context.config.get('key')) # key auto set?
    fw = context.client
    cid = context.destination['id']
    container = fw.get(cid) # analysis container
    #print(f"fw context {cid} container: {container}")
    sess = fw.get(container.parents.session)
    info = {'snr': stats.get('snrpk'),
            'tsnr': stats.get('tsnrpk'),
            'shim': stats.get('shim'),
            'alias': stats.get('aliaspk'),
            'bkoff':stats.get('bkoffpk')}
    sess.update_info(info)
    print(f"updated sess db: {info}")


if len(sys.argv) > 1:
    input_path = sys.argv[1]
    # mock
    context = lambda _: None
    context.client = flywheel.Client()
    context.config = {"phantom_dicom": input_path,
              "write_db": False,
              "key": None}
else:
    context = flywheel.GearContext()
    config = context.config
    input_path = context.get_input("phantom_dicom")["location"]["path"]

# print(f"env: nii {os.environ.get('phantom_nifti')}") # None
# print(f"config: {context.config.get('phantom_nifti')}") # None

print(f"input path: '{input_path}'")

os.makedirs("/flywheel/v0/work/",exist_ok=True)
subprocess.run(["unzip", "-j", "-d", "/flywheel/v0/work/dicoms/", input_path], check=True)
subprocess.run(["/flywheel/v0/QC.m", "/flywheel/v0/work/dicoms/", "/flywheel/v0/outputs/"])
# 20250312: no outputs?!
subprocess.run(["ls", "-R", "/flywheel/v0/output"])

if context.config.get('write_db'):
    update_db(context)
