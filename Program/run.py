#!/usr/bin/env python3

import nibabel as nib
import flywheel
import numpy as np
import os
import sys
import subprocess

if len(sys.argv) > 1:
    input_path = sys.argv[1]
    # mock
    context = lambda _: None
    context.config = {'phantom_dicom': input_path}
else:
    context = flywheel.GearContext()
    config = context.config
    input_path = context.get_input('phantom_dicom')['location']['path']

#print(f"env: nii {os.environ.get('phantom_nifti')}") # None
#print(f"config: {context.config.get('phantom_nifti')}") # None

subprocess.check_output('unzip -d dicoms "{input_path}"')
subprocess.check_output('QC.m dicoms/ outputs/')


print(f"input path: '{input_path}'")

# TODO: write metrics into db
