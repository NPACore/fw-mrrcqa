#!/usr/bin/env python3
"""
Check scanner B0.
Use FWHM on FFT of free induction decay QA sequence

Can also be used as a file-curator flywheel gear
"""

import numpy as np
import coil
import pydicom


def fid_fwhm(dcm, plot=True):
    """Full Width Half Max of Free Inducation decay"""
    csa = coil.csareader.read(dcm[(0x0029, 0x1110)].value)
    dt = (coil.read_item(csa, 'RealDwellTime') or 0) * 1e-9  # sec; scanner ADC sampling time
    bw = 1/dt  # Hz
    # t = rng*dt 
    fftfid = coil.fft_signal(dcm)
    absfft = np.abs(fftfid)

    nt = absfft.shape[0] #coil.read_item(csa, 'DataPointRows') or 0
    rng = np.arange(0, nt)
    df = bw/nt
    f = (rng - nt/2)*df  # frequency

    half_max = np.max(absfft)/2
    above_hm = f[absfft-half_max > 0]
    fwhm = np.max(above_hm) - np.min(above_hm)
    
    if plot:
        import matplotlib.pyplot as plt
        plt.title(f"dt={dt:.6} bw={bw:.2} nt={nt} hm={half_max:3.2};\n{dcm_file}")
        plt.suptitle(f"fwhm={fwhm}")
        plt.plot(f, absfft)
        plt.hlines(y=half_max, xmin=f[0], xmax=f[nt-1], color='r')
        plt.show()

    return fwhm


if __name__ == "__main__":
    import sys
    for dcm_file in sys.argv[1:]:
        dcm = pydicom.dcmread(dcm_file)
        fwhm = fid_fwhm(dcm)
        print(f"FID FWHM\t{fwhm:2.3f}\t{dcm_file}\n")
