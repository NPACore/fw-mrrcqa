"""Tests for tsnr.py (the tSNR container launcher).  Run from listener/: python -m pytest

No container is run: subprocess.run is replaced with a fake.
"""
import os

import pytest
from pydicom.dataset import FileDataset, FileMetaDataset
from pydicom.uid import ExplicitVRLittleEndian, MRImageStorage, generate_uid

import driver
import tsnr


@pytest.fixture
def series(tmp_path, monkeypatch):
    """A phantom series in session folder 2026.10.14-06.34.20 with one DICOM: Prisma3, series 3.
    (The header's series time is two minutes later, like on the real scanner.)"""
    monkeypatch.setattr(tsnr, "OUT_ROOT", str(tmp_path / "out"))
    folder = tmp_path / "PRISMA3QC" / "2026.10.14-06.34.20" / "PRISMA3QA20261014" / "ep2d_bold_p2_s2_5min.3"
    folder.mkdir(parents=True)
    meta = FileMetaDataset()
    meta.MediaStorageSOPClassUID = MRImageStorage
    meta.MediaStorageSOPInstanceUID = generate_uid()
    meta.TransferSyntaxUID = ExplicitVRLittleEndian
    ds = FileDataset(str(folder / "MR.1"), {}, file_meta=meta, preamble=b"\0" * 128)
    ds.StationName = "MRC35073"
    ds.SeriesDate, ds.SeriesTime, ds.SeriesNumber = "20261014", "063646.123000", 3
    ds.save_as(str(folder / "MR.1"))
    return str(folder)


def test_out_name_is_session_folder_scanner_series_number(series, tmp_path):
    """Named like run-sbatch-raidzeus.bash names it; without a session folder, the header's series time is used."""
    assert tsnr.out_name(series) == "2026.10.14-06.34.20-Prisma3-3"
    loose = tmp_path / "loose.3"
    os.rename(series, loose)
    assert tsnr.out_name(str(loose)) == "2026.10.14-06.36.46-Prisma3-3"


def test_command_is_the_same_for_a_file_or_its_folder(series):
    """Given a file, the container gets the file's folder; the command matches run-sbatch-raidzeus.bash."""
    outdir = os.path.join(tsnr.OUT_ROOT, "2026.10.14-06.34.20-Prisma3-3")
    expected = ["singularity", "run",
                "--mount", f"type=bind,src={series},dst={series},ro",
                "-B", f"{outdir}:{outdir}:rw",
                tsnr.IMAGE, series, "0", outdir]
    assert tsnr.command(series) == (series, outdir, expected)
    assert tsnr.command(os.path.join(series, "MR.1")) == (series, outdir, expected)


@pytest.mark.parametrize("code, writes_stats, ok", [(0, True, True), (1, True, False), (0, False, False)])
def test_run_succeeds_only_with_exit_0_and_a_stats_json(series, monkeypatch, code, writes_stats, ok):
    calls = []

    def fake_run(cmd, **kw):
        calls.append(cmd)
        assert os.path.isdir(cmd[-1])            # outdir exists before the container starts
        if writes_stats:
            open(os.path.join(cmd[-1], "stats.json"), "w").close()
        return type("Done", (), {"returncode": code})()
    monkeypatch.setattr(tsnr.subprocess, "run", fake_run)

    if ok:
        assert tsnr.run(series).endswith("2026.10.14-06.34.20-Prisma3-3")
        tsnr.run(series)                         # stats.json is there now: not run a second time
    else:
        with pytest.raises(RuntimeError):
            tsnr.run(series)
    assert len(calls) == 1


@pytest.mark.parametrize("observe", [True, False])
def test_driver_runs_tsnr_on_phantoms_only_when_not_observing(series, monkeypatch, observe):
    """The phantom rules point at the tsnr pipeline, and OBSERVE_ONLY blocks it."""
    ran = []
    monkeypatch.setattr(driver, "OBSERVE_ONLY", observe)
    monkeypatch.setattr(driver.tsnr, "run", lambda path: ran.append(path) or "/out")
    phantom = driver.poller.WATCHDIR + "PRISMA3QC/s1/PRISMA3QA/ep2d_bold_p2_s2_5min.3"
    rule = driver.match_rule(phantom)
    assert rule["pipelines"] == ["tsnr"]
    driver.fire_trigger(phantom, os.path.join(series, "MR.1"), rule)
    assert len(ran) == (0 if observe else 1)
