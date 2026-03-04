#!/usr/bin/env python3
"""
Download and run Program/dostat.m on a flywheel session id (copied from webUI?)
Leaves matlab open with populated workspace for debugging.

Can take a dicom folder or zip instead of a session id for testing/comparing
"""

import os
import re
import subprocess
import sys
import tempfile

if len(sys.argv) <= 1:
    raise Exception(f"USAGE: {sys.argv[0]} dcm-session-id-or-directory")

if os.path.exists(sys.argv[1]):
    dcm_zip_or_folder = os.path.abspath(sys.argv[1])
else:
    import flywheel

    fw = flywheel.Client()
    container_id = sys.argv[1]
    # container_id='69a577cefd6a94887ba20535'
    ses_or_acq = fw.get(container_id)
    # assume if sessions not in parents, this is a session not a acq
    # add that the first file matchign ep2d in the containe we were given is the right one
    if not "session" in ses_or_acq.parents.keys():
        dcm_zips = [x for x in ses_or_acq.acquisitions() if re.search("ep2d", x.label)]
        dcm_zip = dcm_zips[0].files[0]
    else:
        dcm_zip = ses_or_acq
    dcm_zip_or_folder = dcm_zip

# tmp = tempfile.TemporaryDirectory()
with tempfile.TemporaryDirectory() as tmp:
    print(f"# temporary working directory: {tmp}")
    dcm_dir = tmp + "/dcm"
    if type(dcm_zip_or_folder) is str and os.path.isdir(dcm_zip_or_folder):
        subprocess.run(["ln", "-s", dcm_zip_or_folder, dcm_dir])  # link in dicom folder
    else:
        # download from flywheel
        if type(dcm_zip_or_folder) is not str:
            zip_path = os.path.join(tmp, "x.zip")
            dcm_zip_or_folder.download(zip_path)
        # input given was a zip file. TODO: check re.search(r'zip$', dcm_zip_or_folder)
        else:
            zip_path = dcm_zip_or_folder

        # get out of zip, junk paths to avoid nested dirs
        subprocess.run(["unzip", "-j", "-d", dcm_dir, zip_path])

    # make nii for easy afni/fsl view
    subprocess.run(["dcm2niix", "-o", tmp, "-f", "epi", "-z", "y", dcm_dir])

    ## run dostats and populate workspace
    os.environ["QA_SAVE_IMAGES"] = "1"
    os.makedirs(os.path.join(tmp, "out"), exist_ok=True)
    # run matlab -- will hang python. loads saves and loads all matlab vars
    subprocess.run(
        [
            "matlab",  # "-nodesktop",
            "-nosplash",
            "-r",
            f"cd Program; res = dostat('{tmp}/dcm',1,'{tmp}/out'); load('{tmp}/out/sigstat.mat');",
        ]
    )
    # will remove tmp when closed
