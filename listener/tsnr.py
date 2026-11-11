"""
tSNR phantom QA: run the MATLAB QA Singularity container on one DICOM series.

Same call as run-sbatch-raidzeus.bash:
    singularity run \
        --mount "type=bind,src=$dcmd,dst=$dcmd,ro" \
        -B "$outdir:$outdir:rw" \
        $IMAGE "$dcmd" ${SHOW_PLOT:-0} "$outdir"

The output folder is named like that script names it:
    OUT_ROOT/<session folder>-<scanner>-<series number>
e.g. /raidzeus/derivatives/projs/QC/out/2026.10.14-06.34.20-Prisma3-3 for a
series under .../2026.10.14-06.34.20/... on Prisma3. A series whose stats.json
is already there is not run again.
"""

import logging
import os
import re
import subprocess

import shim

IMAGE = "/raidzeus/singularity/images/mrrcqa-ml-1.6.1.20261011.sif"
OUT_ROOT = "/raidzeus/derivatives/projs/QC/out"
SINGULARITY = "singularity"
SHOW_PLOT = "0"
# The container is killed (and the series retried on a later run) after this long.
TIMEOUT = 30 * 60

SESSION_RE = re.compile(r"^\d{4}\.\d{2}\.\d{2}-\d{2}\.\d{2}\.\d{2}$")   # a session folder, e.g. 2026.10.14-06.34.20


def dicom_dir(path):
    """The series folder: `path` itself, or its folder if `path` is a file."""
    path = os.path.abspath(path)
    return os.path.dirname(path) if os.path.isfile(path) else path


def a_dicom(path):
    """One file to read the header from: `path` itself, or the first file in the folder."""
    if os.path.isfile(path):
        return path
    names = sorted(n for n in os.listdir(path) if os.path.isfile(os.path.join(path, n)))
    if not names:
        raise ValueError(f"no files in {path}")
    return os.path.join(path, names[0])


def out_name(path):
    """<session folder>-<scanner>-<series number>, e.g. 2026.10.14-06.34.20-Prisma3-3.
    The session folder name comes from the path; if the path has none, the
    series date and time from the DICOM header are used in the same format."""
    import pydicom
    dcm = pydicom.dcmread(a_dicom(path), stop_before_pixels=True)

    sessions = [p for p in dicom_dir(path).split(os.sep) if SESSION_RE.match(p)]
    if sessions:
        when = sessions[-1]
    else:
        for d, t in (("SeriesDate", "SeriesTime"), ("AcquisitionDate", "AcquisitionTime"), ("StudyDate", "StudyTime")):
            date, clock = str(getattr(dcm, d, "") or ""), str(getattr(dcm, t, "") or "")
            if re.match(r"\d{8}$", date) and re.match(r"\d{6}", clock):
                break
        else:
            raise ValueError("no session folder in the path and no usable date/time in the DICOM header")
        when = f"{date[:4]}.{date[4:6]}.{date[6:8]}-{clock[:2]}.{clock[2:4]}.{clock[4:6]}"

    station = (getattr(dcm, "StationName", "") or "").strip()
    short = shim.get_scanners().get(station, (station, None))[0]       # "P3", or the StationName if unknown
    scanner = re.sub(r"^P(\d)$", r"Prisma\1", short)
    scanner = re.sub(r"[^A-Za-z0-9]+", "_", scanner).strip("_") or "UNKNOWN"

    number = getattr(dcm, "SeriesNumber", None)
    if number is None:
        m = re.search(r"\.(\d+)$", dicom_dir(path))                    # the folder's .N suffix
        number = m.group(1) if m else 0
    return f"{when}-{scanner}-{int(number)}"


def command(path):
    """(dicom folder, output folder, singularity command) for one series. Runs nothing."""
    dcmd = dicom_dir(path)
    outdir = os.path.join(OUT_ROOT, out_name(path))
    cmd = [SINGULARITY, "run",
           "--mount", f"type=bind,src={dcmd},dst={dcmd},ro",
           "-B", f"{outdir}:{outdir}:rw",
           IMAGE, dcmd, SHOW_PLOT, outdir]
    return dcmd, outdir, cmd


def run(path):
    """Run the container on a DICOM folder (or a file in it) and wait for it.
    The container's output goes to <outdir>/singularity.log. Returns outdir.
    Does nothing if <outdir>/stats.json is already there (same as the bash
    script). Raises if the container fails, takes longer than TIMEOUT, or
    leaves no stats.json."""
    dcmd, outdir, cmd = command(path)
    stats = os.path.join(outdir, "stats.json")
    if os.path.exists(stats):
        logging.info("tsnr: already have %s, not running again", stats)
        return outdir
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "singularity.log"), "ab") as log:
        done = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=TIMEOUT)
    if done.returncode != 0:
        raise RuntimeError(f"container exited with code {done.returncode} for {dcmd} (see {outdir}/singularity.log)")
    if not os.path.exists(stats):
        raise RuntimeError(f"container finished but wrote no stats.json for {dcmd} (see {outdir}/singularity.log)")
    return outdir
