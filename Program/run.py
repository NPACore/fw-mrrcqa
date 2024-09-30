#!/usr/bin/env python3

import sys
import os
import subprocess
import flywheel
#import nibabel as nib
#import numpy as np

if len(sys.argv) > 1:
    input_path = sys.argv[1]
    # mock
    context = lambda _: None
    context.config = {"phantom_dicom": input_path}
else:
    context = flywheel.GearContext()
    config = context.config
    input_path = context.get_input("phantom_dicom")["location"]["path"]

# print(f"env: nii {os.environ.get('phantom_nifti')}") # None
# print(f"config: {context.config.get('phantom_nifti')}") # None

os.makedirs("/flywheel/v0/work/",exist_ok=True)
subprocess.run(["unzip", "-j", "-d", "/flywheel/v0/work/dicoms/", input_path], check=True)
subprocess.run(["/flywheel/v0/QC.m", "/flywheel/v0/work/dicoms/", "/flywheel/v0/outputs/"])
subprocess.run(["ls", "/flywheel/v0/outputs/"])

print(f"input path: '{input_path}'")

# TODO: write metrics into db
