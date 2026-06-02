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
    raise Exception(f"USAGE: {sys.argv[0]} [dcm-directory|session-id|search-string|study id]")

tmpsuffix='_'
if os.path.exists(sys.argv[1]):
    dcm_zip_or_folder = os.path.abspath(sys.argv[1])
else:
    import flywheel
    fw = flywheel.Client()

    # kludge. any equal sign in first argument means use a flyhweel search string
    is_search = re.search(r'=', sys.argv[1])

    if len(sys.argv)==2 and not is_search: # single argument is container
        container_id = sys.argv[1]
    # find container id study + date
    else:
        # how do we search?
        if is_search:
            search_str = sys.argv[1]
        else:
            if len(sys.argv) != 3: raise Exception("Error: inputs not dir or search string. expect study and date")
            search_str=f"project.label=~{sys.argv[1]},subject.label=~{sys.argv[2]}"

        # what do we fine?
        search = fw.sessions.find(search_str)
        if not search:
            print(f"No luck searching sessions for: {search_str}")
            sys.exit()
        if len(search) > 1:
            print(f"WARNING: taking first mulitple {search_str} matches: {','.join([x.subject.label for x in search])}")
        tmpsuffix = tmpsuffix + search[0].subject.label + '_'
        container_id = search[0].id

    # will have subject as prefix if found via search.
    # otherwise just id
    tmpsuffix = tmpsuffix + 'id-' + container_id

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
with tempfile.TemporaryDirectory(tmpsuffix) as tmp:
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
    # matlab prompt intentionally left open. must manually quit
    # will remove tmp when closed
