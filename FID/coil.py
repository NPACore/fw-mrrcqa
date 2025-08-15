#!/usr/bin/env python3

import pydicom
from glob import glob
import numpy as np
from nibabel.nicom import csareader

def read_item(csa: dict, el: str):
    """extract CSA item from csareader dict
    :param csa: header from csareader
    :param el: element key
    :return: value of element in CSA header

    >>> read_item({'tags': {'Rows': {'items': [1]}}}, 'Rows')
    1
    """
    if not (valdict := csa['tags'].get(el)):
        return None
    return valdict['items'][0]

def fft_signal(f: str) -> np.ndarray:
    """
    extract FFT from FID acquisition in dicom's private CSA header
    :param f: input dicom file
    :return: np.complex128 (2048,)
    """
    dcm = pydicom.dcmread(f)
    csa_fft = dcm.get_item((0x7fe1,0x1010))
    # was bytes. uint8 len=16384. should be single w/len 4096
    raw = np.frombuffer(csa_fft.value, dtype='<f4')
    assert raw.shape[0] == 4096
    cplx = raw[0::2] + 1j*raw[1::2]

    ## Siemens CSA (Common Syngo Architecture)
    # if output wasn't a single vector, shape from CSA header would be needed
    # all 1 for QA FID acquisition
    # acronym definition from ChatGPT
    # confirmed in https://pmc.ncbi.nlm.nih.gov/articles/PMC5609763/ (2017)
    csa = csareader.read(dcm[(0x0029,0x1110)].value)
    shape = [read_item(csa, el) for el in ['DataPointRows', 'Rows', 'Columns', 'NumberOfFrames']]
    assert shape == [1,1,1,1]
    # if not single dim, would want to reshape. from matlab:
    # reshape([tmp(1:2:end)+1i*tmp(2:2:end)],ipolDataPointColumns,ipolPhaseColumns,ipolPhaseRows,ipolNumberOfFrames);


    fsignal = np.fft.fftshift(np.fft.fft(cplx))
    return fsignal

def fft_acqdir(dpath: str, patt="*.dcm") -> np.ndarray:
    """
    extract FID for all channels -- one channel per dicom file in acquisition directory
    :param dpath: path to acquisition directory with 64 dicoms
    :param patt: dicom file name patter. examples: 'MR.*', '*.dcm', etc
    :return: fft_signal() on each dicom: np.complex128 (64, 2048)
    """
    files = glob(f'{dpath}/{patt}')
    assert len(files) == 64

    res = np.stack([fft_signal(f) for f in files])
    # 64 channels worth of data
    assert res.shape == (64, 2048)
    return res

if __name__ == "__main__":
    res = fft_acqdir('./2QA20250804_PM/1.3.12.2.1107.5.2.43.167046.2025080414155450338638503.0.0.0.dicom/')
    res_abs = np.abs(res)
    avg = np.mean(res_abs)
    maxs = np.stack([np.argmax(res_abs,1)-1024,
                     np.max(res_abs,1)/avg],1)

    from matplotlib import pyplot as plt
    mag_i = np.argsort(maxs[:,1]).tolist()
    arg_i = np.argsort(maxs[:,0]).tolist()

    low = 1024 - 50 # + int(np.min(maxs[:,0]))
    hig = 1024 + 50 # + int(np.max(maxs[:,0]))

    x=np.arange(-50,50)+1024

    plt.suptitle('FID FFT @ mid -/+ 50')
    plt.subplot(2,2,1)
    plt.title('ch as read in')
    plt.imshow(res_abs[:,low:hig])

    plt.subplot(2,2,2)
    plt.title('ch order by max mag')
    plt.imshow(res_abs[mag_i,low:hig])


    plt.subplot(2,2,3)
    plt.title('ch normlaized')
    plt.imshow(res_abs[:,low:hig] / np.max(res_abs,1).reshape(64,1))

    plt.subplot(2,2,4)
    plt.title('normalized and ordered by pos')
    plt.imshow(res_abs[arg_i,low:hig] / np.max(res_abs[arg_i,:],1).reshape(64,1))
    #plt.show()
    plt.savefig('fft_example.png')
