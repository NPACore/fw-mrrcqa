#!/usr/bin/env python3
"""
Flywheel wrapper for octave stats generating routine.

1. unzip dicom specified as 'phantom_dicom'
2. run octave
3. writes stats.json
4. puts 'tsnr' into session info (flywheel data container)

The software container described by 'Dockerfile' can work independently of flywheel.
And will run the matlab (octave) QC.m

    ENTRYPOINT ["${FLYWHEEL}/QC.m"]

For Flywheel specific execution, manifest.json specifies this file

    "command": "/flywheel/v0/run.py"

In either, the base directory is `/flywheel/v0` (``$FLYWHEEL``)

This runs as a "SDK gear" and needs to be given read-write access
  to add 'info.snr' to the session's data container.

The python code to write to FW's database was modernized from the very helpful
  writeup on https://pennlinc.github.io/docs/flywheel/Gear_development/


20250404WF - updated to use context.output_dir instead of hard coded '/flywheel/v0/outputs'
             and created the MockContext class to deal with increasing number of mocked things
20260105WF - add option to use compiled (no lic) matlab instead of octave
"""

import sys
import os
import subprocess
import json  # for reading matlab output
import warnings
import flywheel


def update_db(context: flywheel.GearContext):
    """
    Flywheel SDK gear style DB update: write snr peak value to sess.info.snr
    Requires write permission when used as a gear rule.

    Implemented with help from
    https://pennlinc.github.io/docs/flywheel/Gear_development/

    :param context: implicit context when running as a gear
    """
    stats_file = os.path.join(context.output_dir, 'stats.json')
    with open(stats_file, 'r') as f:
        stats = json.load(f)
    #fw = flywheel.Client(context.config.get('key')) # key auto set?
    fw = context.client
    cid = context.destination['id']
    container = fw.get(cid) # analysis container
    #print(f"fw context {cid} container: {container}")
    sess = fw.get(container.parents.session)
    info = {'snr': stats.get('snrpk'),
            'tsnr': stats.get('tsnrpk'),
            'shim': stats.get('shim'),
            'alias': stats.get('aliaspk'),
            'bkoff':stats.get('bkoffpk')}
    sess.update_info(info)
    print(f"updated sess db: {info}")


class MockContext():
    """Minimal mock of GearContext when testing.
    Also potentially useful for running outside of flywheels gear infrastucture
    """
    destination = {'id': None}
    config = {"phantom_dicom": None, "write_db": False, "key": None}

    def __init__(self, input_path):
        try:
            self.client = flywheel.Client()
        except:
            warnings.warn("Flywheel auth failed. Not connecting to external server. Just testing?")
            self.client = None

        # update gear config to be either the downloaded zip file
        # or original input file (zip)
        #input_path = self.maybe_download(input_path)

        self.config["phantom_dicom"] = input_path
        self.output_dir = os.environ.get("OUTDIR",'/flywheel/v0/outputs/')  # default output location

    def test_client(self):
        if not self.client:
            raise Exception("Trying to fetch file, but no flywheel account authenticated! Set FLYWHEEL env or ~/.config/flywheel/user.json")

    def maybe_download(self, input_path):
        """
        UNTESTED! UNFINISHED!
        input path should be a zip file
        but maybe it's a flywheel container id of a zip file
        :param input_path: path to dicom zip that might be a flywheel id instead
        :sideeffects: download from flyhweel
        """
        if os.path.isfile(input_path):
            return input_path

        # only continue if we have client
        self.test_client()

        file = self.client.get(input_path)
        # TODO confirm test id is a file ending with zip
        if file:
            self.destination = {'id': file.parent}
        else:
            raise Exception(f"'{input_path}' is not a vaid path nor id")
        # TODO: fix saveas
        save_as = "/flywheel/v0/work/input.zip"
        # TODO: check ths works
        file.download_file(save_as)
        input_path = save_as
        return input_path

    def upload(self):
        """
        UNFINISHED! don't use
        Attempt to work around unable to upload docker container
        """
        stats_file = os.path.join(self.output_dir, 'stats.json')
        if not self.destination.get('id'):
            raise Exception("trying to upload without destination id")
        if not os.path.isfile(stats_file):
            raise Exception("Failed to create {STATS_OUTPUT_FILE}")

        # only continue if we have client
        self.test_client()

        # TODO: find flywheel upload command
        acq_or_analysis = self.client.get(self.destination['id'])
        ses = acq.parent
        analysis = ses.add_analysis(label='')
        analysis.upload_output(stats_file)
        ses.upload(stats_file)


def main():
    """
    Run CH's Phantom QC Matlab code via octave.
    Optionally update the session info to include tsnr

    USAGE: run.py [/path/to/dcm.zip]
     Runs Program/dostat.m to create phantom, background, readout&phaseenc alias masks for peak and  SNR and tSNR stats.
     Results written to stats.json
     
        If args, first must be path to a zip file containing DICOMs
   
        No args, then uses Flywheel's GearContext to pull in phantom_dicom.location.path
        stats.json is uploaded to session. and session mongodb gets 'snr' 'tsnr' 'shim' 'alias' 'bkoff'

        OUTDIR, WORKDIR, ML_PROGRAM and/or OCTAVE_PROGRAM environment variables will be checked before using Docker defaults.
        These are useful to set for testing outside the container
    """
    if "-h" in sys.argv[1:]:
        print(help(main))
    if len(sys.argv) > 1:
        input_path = sys.argv[1]
        context = MockContext(input_path)

    else:
        context = flywheel.GearContext()
        input_path = context.get_input("phantom_dicom")["location"]["path"]

    # matlab's a lot faster than octave
    # use it (dostat) when it exists (mlbin/00_build_mcr.m)
    # dostat has extra argument
    ml_program =  os.environ.get("ML_PROGRAM", "/usr/bin/mlrtapp/dostat")
    octave_program = os.environ.get("OCTAVE_PROGRAM","/flywheel/v0/QC.m")
    work_dir = os.environ.get("WORKDIR", "/flywheel/v0/work/dicoms/")
    if os.path.isfile(ml_program):
        qc_program = ml_program 
        input_args = [work_dir, "0", context.output_dir]
    else:
        qc_program = octave_program
        input_args = [work_dir,   context.output_dir]


    # 20260221WF - added "-n" to skip existing ("never overwrite")
    #  in container, expect to always have new files.
    #  outside container, dont need to keep being prompted
    unzip_cmd = ["unzip", "-n", "-j", "-d", work_dir, input_path]

    print(f"input path: {input_path}")
    print(f"unzip:      {' '.join(unzip_cmd)}")
    print(f"qc program: {qc_program} {' '.join(input_args)}")

    os.makedirs(os.path.dirname(work_dir), exist_ok=True)
    subprocess.run(unzip_cmd, check=True) # check raises excpetion if failed
    subprocess.run([qc_program, *input_args])

    # 20250312: no outputs?! List all for debugging
    subprocess.run(["ls", "-R", context.output_dir])

    if context.config.get('write_db'):
        update_db(context)
    if len(sys.argv) > 1 and context.destination is not None:
        warnings.warn("TODO: no stats.json/db update yet when run outside gear.")


if __name__ == "__main__":
    main()
