#!/usr/bin/env python3
"""
Read coil spectrum from siemens Common Syngo Architecture private field in DICOM.

Acquistion is very short Free Induction Decay, creates a single dicom per channel. Flywheel exports all 64 dcms within a single zip file.
"""

import pydicom
import re
from glob import glob
import numpy as np
from nibabel.nicom import csareader
from zipfile import ZipFile


def read_item(csa: dict, el: str):
    """extract CSA item from csareader dict
    :param csa: header from csareader
    :param el: element key
    :return: value of element in CSA header

    >>> read_item({'tags': {'Rows': {'items': [1]}}}, 'Rows')
    1
    """
    if not (valdict := csa["tags"].get(el)):
        return None
    return valdict["items"][0]


def fft_signal(dcm) -> np.ndarray:
    """
    extract FFT from FID acquisition in dicom's private CSA header
    :param dcm: pydicom.pydicom object. [cannot type in signature b/c FW pydicom is old]
    :return: np.complex128 (2048,)
    """
    csa_fft = dcm.get_item((0x7FE1, 0x1010))
    # was bytes. uint8 len=16384. should be single w/len 4096
    raw = np.frombuffer(csa_fft.value, dtype="<f4")

    # assert raw.shape[0] == 4096
    # should be 2^x. 4096 for qa_fid; 2048 for SVS
    # assert is power of 2
    assert np.log2(raw.shape[0]) % 1 == 0

    cplx = raw[0::2] + 1j * raw[1::2]

    ## Siemens CSA (Common Syngo Architecture)
    # if output wasn't a single vector, shape from CSA header would be needed
    # all 1 for QA FID acquisition
    # acronym definition from ChatGPT
    # confirmed in https://pmc.ncbi.nlm.nih.gov/articles/PMC5609763/ (2017)
    csa = csareader.read(dcm[(0x0029, 0x1110)].value)
    shape = [
        read_item(csa, el)
        for el in ["DataPointRows", "Rows", "Columns", "NumberOfFrames"]
    ]
    assert shape == [1, 1, 1, 1]
    # if not single dim, would want to reshape. from matlab:
    # reshape([tmp(1:2:end)+1i*tmp(2:2:end)],ipolDataPointColumns,ipolPhaseColumns,ipolPhaseRows,ipolNumberOfFrames);

    fsignal = np.fft.fftshift(np.fft.fft(cplx))
    return fsignal


def fft_acqdir(dpath: str, patt="*.dcm", inshape=[64, 2048]) -> np.ndarray:
    """
    extract FID for all channels -- one channel per dicom file in acquisition directory
    :param dpath: path to acquisition directory with 64 dicoms
    :param patt: dicom file name patter. examples: 'MR.*', '*.dcm', etc
    :return: fft_signal() on each dicom: np.complex128 of 'inshape' [(64, 2048) for qa_fd_uc_upw]
    """
    if re.search(".zip$", dpath):
        res = np.zeros(inshape, dtype="complex64")
        with ZipFile(dpath) as zf:
            if not len(zf.filelist) == inshape[0]:  # 64 for qa_fid
                raise Exception(f"{len(zf.filelist)} dcm files instead of expected 64")
            for i, entry in enumerate(zf.filelist):
                with zf.open(entry.filename) as fh:
                    fft = fft_signal(pydicom.dcmread(fh))
                    assert (fft.shape[0]) == inshape[1]  # 2048 for qa_fid
                    res[i, :] = fft
    else:
        files = glob(f"{dpath}/{patt}")
        assert len(files) == 64
        res = np.stack([fft_signal(pydicom.dcmread(f)) for f in files])

    # 64 channels worth of data
    assert res.shape == inshape  # (64, 2048) for qa_fid
    return res


def norm_subset(coil_2d):
    res_abs = np.abs(coil_2d)
    low = 1024 - 50  # + int(np.min(maxs[:,0]))
    hig = 1024 + 50  # + int(np.max(maxs[:,0]))
    return res_abs[:, low:hig] / np.max(res_abs, 1).reshape(64, 1)


def plot_fft(res, save_as):
    from matplotlib import pyplot as plt

    res_abs = np.abs(res)
    avg = np.mean(res_abs)
    maxs = np.stack([np.argmax(res_abs, 1) - 1024, np.max(res_abs, 1) / avg], 1)

    mag_i = np.argsort(maxs[:, 1]).tolist()
    arg_i = np.argsort(maxs[:, 0]).tolist()

    low = 1024 - 50  # + int(np.min(maxs[:,0]))
    hig = 1024 + 50  # + int(np.max(maxs[:,0]))

    x = np.arange(-50, 50) + 1024

    plt.suptitle("FID FFT @ mid -/+ 50")
    plt.subplot(2, 2, 1)
    plt.title("ch as read in")
    plt.imshow(res_abs[:, low:hig])

    plt.subplot(2, 2, 2)
    plt.title("ch order by max mag")
    plt.imshow(res_abs[mag_i, low:hig])

    plt.subplot(2, 2, 3)
    plt.title("ch normlaized")
    plt.imshow(res_abs[:, low:hig] / np.max(res_abs, 1).reshape(64, 1))

    plt.subplot(2, 2, 4)
    plt.title("normalized and ordered by pos")
    plt.imshow(res_abs[arg_i, low:hig] / np.max(res_abs[arg_i, :], 1).reshape(64, 1))
    # plt.show()
    if save_as:
        plt.savefig(save_as)


if __name__ == "__main__":
    res = fft_acqdir(
        "./2QA20250804_PM/1.3.12.2.1107.5.2.43.167046.2025080414155450338638503.0.0.0.dicom/"
    )
    plot_fft(res, "fft_example.png")
