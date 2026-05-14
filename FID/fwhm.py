#!/usr/bin/env python3
"""
Check scanner B0.
Use FWHM on FFT of free induction decay QA sequence

Can also be used as a file-curator flywheel gear.

20260316 - default db name is 'fwhm'
           But want to run for single voxel spec sequence too ('fwhm_svs')
"""

import numpy as np
import pydicom
import re
import logging
import sys
from zipfile import ZipFile
from typing import Any, Dict

# Import coil module - try from current directory first, then from additional input
try:
    import coil
except ImportError:
    coil = None

# Dont require flywheel. Mock if MIA
# will only be used by file-curator gear
try:
    import flywheel
    from flywheel_gear_toolkit.utils.curator import FileCurator
except ImportError:
    flywheel = None

    class FileCurator:
        def __init__(self, **kwargs):
            pass


def fid_fwhm(dcm, plot=True):
    """Full Width Half Max of Free Inducation decay"""
    csa = coil.csareader.read(dcm[(0x0029, 0x1110)].value)
    dt = (
        coil.read_item(csa, "RealDwellTime") or 0
    ) * 1e-9  # sec; scanner ADC sampling time
    bw = 1 / dt  # Hz
    # t = rng*dt
    fftfid = coil.fft_signal(dcm)
    absfft = np.abs(fftfid)

    nt = absfft.shape[0]  # coil.read_item(csa, 'DataPointRows') or 0
    rng = np.arange(0, nt)
    df = bw / nt
    f = (rng - nt / 2) * df  # frequency

    half_max = np.max(absfft) / 2
    above_hm = f[absfft - half_max > 0]
    fwhm = np.max(above_hm) - np.min(above_hm)

    if plot:
        dcm_file = (
            f"{dcm.AcquisitionDate} {dcm.AcquisitionTime} {dcm.SeriesDescription}"
        )
        import matplotlib.pyplot as plt

        plt.title(f"dt={dt:.6} bw={bw:.2} nt={nt} hm={half_max:3.2};\n{dcm_file}")
        plt.suptitle(f"fwhm={fwhm}")
        plt.plot(f, absfft)
        plt.hlines(y=half_max, xmin=f[0], xmax=f[nt - 1], color="r")
        plt.show()

    return fwhm


def load_coil_module(coil_path):
    """Load coil module from additional input when running as gear"""
    import importlib.util

    global coil
    # Load coil.py from additional-input-one
    spec = importlib.util.spec_from_file_location("coil", coil_path)
    coil = importlib.util.module_from_spec(spec)
    sys.modules["coil"] = coil
    spec.loader.exec_module(coil)
    logging.info(f"Loaded coil module from {coil_path}")


def first_dicom_from_zip(zfname: str) -> pydicom.Dataset:
    """Dicom header for first file in zip
    Read inplace via stream, without extracting zip."""

    # HACK: expect zip, but special case if input is dicom
    if not re.search(r".zip$", str(zfname)):
        print(f"Not given a .zip, assuming file from single dicom acquisition")
        return pydicom.dcmread(zfname)

    with ZipFile(zfname) as zf:
        for entry in zf.filelist:
            if entry.file_size > 0:
                with zf.open(entry.filename) as fh:
                    return pydicom.dcmread(fh)
    raise ValueError("No valid DICOM found in zip.")


def update_fwhm_stat(acq_id: str, fwhm: float, client=None) -> bool:
    """Add FWHM to FW DB as 'fwhm' in session.
    :param acq_id: Flywheel acquisition ID
    :param fwhm: FWHM value to store
    :param client: Flywheel client (optional)
    :return: True if updated, False if skipped or failed
    """
    if not flywheel or not client:
        logging.warning("Flywheel not available or no client, skipping DB update")
        return False

    try:
        acq = client.get(acq_id)
        ses = client.get(acq.session)

        # 20260316: fa_qa values goes into fwhm. new measure for svs too
        db_field = "fwhm"
        if re.search("svs", acq.label):
            db_field = "fwhm_svs"

        # Check if FWHM already exists
        if ses.info.get(db_field):
            logging.info(
                "skipping %s (%s), already have fwhm: %s",
                acq.label,
                ses.label,
                ses.info.get(db_field),
            )
            return False

        # Update session info with FWHM
        new_info = {db_field: fwhm}
        ses.update_info(new_info)
        logging.info("Updated session %s with %s: %f", ses.label, db_field, fwhm)
        return True

    except Exception as e:
        logging.error("Failed to update DB for acquisition %s: %s", acq_id, e)
        return False


class Curator(FileCurator):
    """
    Extend flywheels class to integrate with the file-curate gear.
    py:func:`Curator.curate_file` is launch point for file-curator when run as a gear.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.reporter = None

    def curate_file(self, file_: Dict[str, Any]):
        """
        This is "main" analog when used with file-curate gear.

        @param file_ is **dict** holding file curator (gear rule) info.
                     ["location"]["path"] is the dicom zip input file

        "additional-input-one" in get_input_path is
        whatever the user specifies AFTER specifying this python file (fwhm.py).

        _file looks like
        .. code:

           {'hierarchy': {'id': '6899c986fbeb05f0ba422e90', 'type': 'acquisition'},
            'object': {'type': 'dicom', 'mimetype': 'application/zip', 'modality': 'MR', 'classification':.... },
            'location': {'path': '/flywheel/v0/input/file-input/1.3.12.2.1107.5.2.43.167046.2025081106355462484301088.0.0.0.dicom.zip', 'name': '1.3.12.2.1107.5.2.43.167046.2025081106355462484301088.0.0.0.dicom.zip'},
           'base': 'file'}
        """
        # need to upload both coil.py and this file fwhm.py
        load_coil_module(self.context.get_input_path("additional-input-one"))

        # Handle both zip files and direct DICOM files
        file_path = file_["location"]["path"]
        dcm = first_dicom_from_zip(file_path)
        fwhm = fid_fwhm(dcm, plot=False)
        print(f"FID FWHM\t{fwhm:2.3f}\t{file_path}")

        # Update flywheel database with FWHM value
        acq_id = file_["hierarchy"]["id"]
        update_fwhm_stat(acq_id, fwhm, self.client)

        return fwhm


if __name__ == "__main__":
    import sys

    for dcm_file in sys.argv[1:]:
        dcm = pydicom.dcmread(dcm_file)
        fwhm = fid_fwhm(dcm)
        print(f"FID FWHM\t{fwhm:2.3f}\t{dcm_file}\n")
