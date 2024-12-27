#!/usr/bin/env python3

import sys
import os
import subprocess
import flywheel
import json # for reading matlab output
#import nibabel as nib
#import numpy as np

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
subprocess.run(["ls", "-R", "/flywheel/v0/output"])

# 20241226 - write snr peak value to flywheel database
# requires write permission
# help from https://pennlinc.github.io/docs/flywheel/Gear_development/
if context.config.get('write_db'):
    with open('/flywheel/v0/outputs/stats.json', 'r') as f:
        stats = json.load(f)
    #fw = flywheel.Client(context.config.get('key')) # key auto set?
    fw = context.client
    container = fw.get(context.destination['id']) # analysis container
    sess = fw.get(container.parent['id'])
    info = {'snr': stats.get('snrpk')}
    sess.update_info(info)
    print(f"updated sess db: {info}")
