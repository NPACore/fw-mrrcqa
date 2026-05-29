#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "matplotlib",
#     "numpy",
#     "pydicom",
# ]
# ///
"""
Plot and print raw timesourse of SVS or FID
"""

import numpy as np
import pydicom
import sys
import os
from coil import read_timeseries
import matplotlib.pyplot as plt

def main():

    if len(sys.argv) <= 1:
        print("ERROR: No input arguments. Proivde dicom file.")
        sys.exit(1)

    dcm_file = sys.argv[1]
    dcm = pydicom.dcmread(dcm_file)
    cplx = read_timeseries(dcm)
    print(cplx.shape)
    plt.title(f"{dcm_file}")
    plt.suptitle(f"raw magnitude")
    plt.plot(np.abs(cplx))
    plt.show()
    print(cplx.to_csv())

if __name__ == "__main__":
    main()
