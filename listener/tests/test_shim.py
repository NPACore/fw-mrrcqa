import os
import struct
import tempfile

import pydicom
from pydicom.dataset import FileDataset, FileMetaDataset
from pydicom.uid import ExplicitVRLittleEndian, MRImageStorage, generate_uid

import settings
import shim


def csa(text):
    """A minimal CSA2 header holding one MrPhoenixProtocol text item (NUL-terminated)."""
    data = text.encode() + b"\0"
    out = b"SV10" + b"\x04\x03\x02\x01" + struct.pack("<II", 1, 77)
    out += b"MrPhoenixProtocol".ljust(64, b"\0") + struct.pack("<i", 1) + b"LO\0\0"
    out += struct.pack("<iii", 0, 1, 77) + struct.pack("<4i", 77, len(data), 77, 0) + data
    return out + b"\0" * ((4 - len(data) % 4) % 4)

def make_dicom(station, z=None, phoenix=None):
    """Write a DICOM from `station` whose protocol text has lOffsetZ = z (or `phoenix` as is)."""
    if phoenix is None:
        phoenix = ("sGRADSPEC.asGPAData[0].lOffsetX = 5\n"
                   f"sGRADSPEC.asGPAData[0].lOffsetZ = {z}\n"
                   "sGRADSPEC.asGPAData[0].lOffsetY = 7\n")
    path = os.path.join(tempfile.mkdtemp(), "MR.1")
    meta = FileMetaDataset()
    meta.MediaStorageSOPClassUID = MRImageStorage
    meta.MediaStorageSOPInstanceUID = generate_uid()
    meta.TransferSyntaxUID = ExplicitVRLittleEndian
    ds = FileDataset(path, {}, file_meta=meta, preamble=b"\0" * 128)
    ds.StationName = station
    ds.add_new((0x0029, 0x0010), "LO", "SIEMENS CSA HEADER")
    ds.add_new((0x0029, 0x1020), "OB", csa(phoenix))
    ds.save_as(path)
    return path
 
 
def test_load_config():
    """shipped shim.toml gives the three Prismas; get_scanners() is the same thing."""
    scanners = shim.load_config()
    assert scanners == {"MRC67078": ("P1", 9931.513661),
                        "AWP167046": ("P2", 4505.258657),
                        "MRC35073": ("P3", 11652.571269)}
    assert shim.get_scanners() == scanners
 
 
def test_read_z():
    """read_z returns the first lOffsetZ; a header without one raises ValueError."""
    assert shim.read_z(pydicom.dcmread(make_dicom("MRC67078", 9871.5))) == 9871.5
    try:
        shim.read_z(pydicom.dcmread(make_dicom("MRC67078", phoenix="nothing useful here\n")))
    except ValueError:
        pass
    else:
        raise AssertionError("expected ValueError")
 
 
def test_check():
    """P1 below its threshold fails, P2 above passes, exactly on it passes, unknown scanner has no verdict."""
    r = shim.check(make_dicom("MRC67078", 9871))
    assert (r["scanner"], r["z"], r["ok"]) == ("P1", 9871.0, False), r
    assert shim.check(make_dicom("AWP167046", 4600))["ok"] is True
    assert shim.check(make_dicom("AWP167046", 4505.258657))["ok"] is True
    r = shim.check(make_dicom("SOMETHING_NEW", 18))
    assert (r["scanner"], r["threshold"], r["ok"]) == ("SOMETHING_NEW", None, None), r
 
 
def test_check_without_config_raises():
    """No shim.toml in the config folder: check() raises instead of guessing."""
    real = settings.CONFIG_DIR, shim._scanners
    settings.CONFIG_DIR, shim._scanners = tempfile.mkdtemp(), None
    try:
        shim.check(make_dicom("MRC67078", 9871))
    except OSError:
        pass
    else:
        raise AssertionError("expected OSError")
    finally:
        settings.CONFIG_DIR, shim._scanners = real
