#!/usr/bin/env python3
"""
Check shim values for failure.
Notify good/bad shim regardless.
"""

import re
import sys
import os
import subprocess
from nibabel.nicom import csareader
import pydicom
from glob import glob
import zipfile
from zipfile import ZipFile

LOW_THRESHOLD = 10000

def notify_message(scanner: str, z: float):
    #: shim values higher than this are okay
    return f"{scanner}: {z} ({LOW_THRESHOLD})"

def notify(msg: str, faddr:str, taddr: str):
    """
    Send an email notificiation
    :param msg: message to send
    :param faddr: form address like xxx@yyyy.
                  will connect to server yyyy
    :param taddr: address to send to

    Note on infractucture
    on pitt's ewi, sending from and to the same pitt email works in php
    mail($to,$subject,$message,$headers);
    """
    from smtplib import SMTP
    with SMTP(re.sub('.*@','',faddr)) as srv:
        srv.sest_debuglevel(1)
        srv.sendmail(faddr, taddr, msg)

def read_phoenix(dcm, reg=None):
    """
    Pulled out of read_z to also read ShimMode (2025-11-11)
    Currently just used interactively, not in 'main'
    :param dcm: dicom object to extract MrPhoenixPprotocol text
    :param reg: seach with first capture group to report
    """
    csa = dcm.get((0x0029, 0x1020))
    csa_s = csareader.read(csa.value)
    asccov = csa_s["tags"]["MrPhoenixProtocol"]["items"][0]
    if not reg:
        return asccov
    else:
        return reg.search(asccov).group(1)

def read_z(dcm) -> float:
    """
    Read lOffsetZ from CSA header
    This assumes a lot about the dicoms header! likely to fail on new data
    :param dcm: dicom from pydicom
    :return: Z shim value as a float
    """
    csa = dcm.get((0x0029, 0x1020))
    csa_s = csareader.read(csa.value)
    asccov = csa_s["tags"]["MrPhoenixProtocol"]["items"][0]
    reg = re.compile(r"sGRADSPEC.asGPAData\[0\].lOffsetZ\s*=\s*([^\s]+)")
    return float(reg.search(asccov).group(1))


def update_db(context, z: float):
    """
    Flywheel SDK gear style DB update: write snr peak value to sess.info.snr
    Requires write permission when used as a gear rule.

    :param context: implicit context when running as a gear
    :param z: z shim parameter
    """
    fw = context.client
    cid = context.destination['id']
    container = fw.get(cid)  # analysis container
    if container is None:
        raise Exception(f"no containder '{cid}'")

    sess = fw.get(container.parents.session)
    info = {'z': z}
    # 20250422 - confirmed updateding info does not clear keys that are not specified
    # will only add z, will not remove eg. 'shims'
    sess.update_info(info)
    print(f"updated sess db: {info}")

def first_dicom_from_zip(zfname) -> pydicom.dataset.FileDataset:
    """read the first non-zero (hopefully dicom) file from a zip file
    :param zfname: zip file path
    :return: dicom object
    """
    with ZipFile(zfname) as zf:
        first = [x for x in zf.filelist if x.file_size>0][0]
        with zf.open(first) as dcm_fh:
            dcm = pydicom.dcmread(dcm_fh)
    return dcm

def first_dicom_from(path) -> pydicom.dataset.FileDataset:
    """
    Read a first dicom from ``path``, which can be:
    - a directory containing (loose) dicom files
    - a .zip 
    - a single dicom file (testing)
    :param path: directory, zip file, or single dicom
    :return: dicom object
    """
    if os.path.isdir(path):
        candidates = sorted(
                f for f in glob(os.path.join(path, "**", "*"), recursive=True)
                if os.path.isfile(f) and os.path.getsize(f) > 0
        )
        if not candidates:
            raise FileNotFoundError(f"no non-empty files found under {path}")
        return pydicom.dcmread(candidates[0])
    if zipfile.is_zipfile(path):
        return first_dicom_from_zip(path)
    # otherwise assum it's a single file
    return pydicom.dcmread(path)

def main():
    """
    Get only the z shim value. Optionally, email state
    """
    if len(sys.argv) > 1:
        from mock_context import Mockcontext
        input_path = sys.argv[1]
        context = MockContext()
        context.config = {"phantom_dicom": input_path, "write_db": False, "key": None, "email_from": "foran@pitt.edu"}

    else:
        import flywheel
        context = flywheel.GearContext()
        input_path = context.get_input("phantom_dicom")["location"]["path"]

    dcm = first_dicom_from(input_path)
    z = read_z(dcm)
    stations = {'MRC35073': 'P1',} # TODO: fill this out
    station = stations.get(dcm.StationName) or dcm.StationName


    if context.config.get('write_db'):
        update_db(context)
    if from_addr := context.config.get('email_from'):
        msg = notify_message(scanner, z)
        notify(msg, from_addr, context.config.get('email_to') or from_addr)


if __name__ == "__main__":
    main()
