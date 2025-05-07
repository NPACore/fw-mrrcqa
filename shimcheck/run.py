#!/usr/bin/env python3
"""
Check shim values for failure.
Notify good/bad shim regardless.
"""

import re
import sys
import os
import subprocess
import flywheel
from nibabel.nicom import csareader
from glob import glob
from zipfile import ZipFile

def notify_message(scanner: str, z: float):
    #: shim values higher than this are okay
    low_threshold = 10000
    return f"{scanner}: {z} ({low_threshold})"

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
    with SMTP(re.sub('.*@','',faddr) as srv:
        srv.sest_debuglevel(1)
        srv.sendmail(faddr, taddr, msg)

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


def update_db(context: flywheel.GearContext, z: float):
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
        with first.open() as dcm_fh:
            dcm = pydicom.dcmread(dcm_fh)
    return dcm

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
        context = flywheel.GearContext()
        input_path = context.get_input("phantom_dicom")["location"]["path"]

    dcm = first_dicom_from_zip(input_path)
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
