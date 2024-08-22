#!/usr/bin/env python3

import nibabel as nib
import flywheel
import numpy as np
import os
import sys

if len(sys.argv) > 1:
    input_path = sys.argv[1]
    # mock
    context = lambda _: None
    context.config = {'phantom_nifti': input_path}
else:
    context = flywheel.GearContext()
    config = context.config
    input_path = context.get_input('phantom_nifti')['location']['path']


#print(f"env: nii {os.environ.get('phantom_nifti')}") # None
#print(f"config: {context.config.get('phantom_nifti')}") # None

print(f"input path: '{input_path}'")
img = nib.load(input_path)
mean = np.mean(img.get_fdata())
print(f"{mean}")

# TODO: write metrics into db
