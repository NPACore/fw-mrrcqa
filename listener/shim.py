"""
Z-shim check: read the Z offset from a DICOM's CSA header and compare it with
the scanner's threshold.

The CSA reading is the same as the old Flywheel-era shimcheck read_z(): the
scanner stores its protocol text in the Siemens private tag (0029,1020), and
the Z shim is the lOffsetZ value of the first gradient-spec entry in it.
"""

import os
import re

import settings

Z_RE = re.compile(r"sGRADSPEC.asGPAData\[0\].lOffsetZ\s*=\s*([^\s]+)")


_scanners = None


def load_config():
    """Read config/shim.toml: one [[scanner]] entry per scanner, with
        id         the DICOM StationName
        shortname  name used in the logs (P1, P2, ...)
        threshold  Z shim below this fails
    Returns {StationName: (shortname, threshold)}; threshold is None if the
    entry has none. Raises if the file is missing, malformed or empty."""
    global _scanners
    path = os.path.join(settings.CONFIG_DIR, "shim.toml")
    scanners = {}
    for sc in settings.load_toml(path).get("scanner", []):
        sid = str(sc.get("id", "")).strip()
        if not sid:
            continue
        try:
            threshold = float(sc["threshold"])
        except (KeyError, TypeError, ValueError):
            threshold = None
        scanners[sid] = (str(sc.get("shortname", sid)).strip(), threshold)
    if not scanners:
        raise ValueError(f"{path} has no [[scanner]] entries")
    _scanners = scanners
    return scanners


def get_scanners():
    return _scanners if _scanners is not None else load_config()


def read_dicom(path):
    # imported here so the rest of the driver runs without pydicom installed
    import pydicom
    return pydicom.dcmread(path)


def read_z(dcm):
    """Z shim (lOffsetZ) from the CSA header of an open DICOM, as a float.
    Raises ValueError if the header or the value isn't there (e.g. not a
    Siemens scan, or a derived series)."""
    from nibabel.nicom import csareader
    csa = dcm.get((0x0029, 0x1020))
    if csa is None:
        raise ValueError("no CSA header (0029,1020)")
    phoenix = csareader.read(csa.value)["tags"]["MrPhoenixProtocol"]["items"][0]
    if isinstance(phoenix, bytes):  # nibabel only decodes text that ends in a NUL
        phoenix = phoenix.decode("latin-1")
    found = Z_RE.search(phoenix)
    if found is None:
        raise ValueError("no lOffsetZ in MrPhoenixProtocol")
    return float(found.group(1))


def check(dcm_path):
    """Read the Z shim from one DICOM. Returns
        {"scanner": "P1", "station": "MRC67078", "z": 9871.0,
         "threshold": 9931.5, "ok": False}
    threshold and ok are None for a scanner that isn't in shim.toml.
    Raises if the DICOM or its header can't be read."""
    scanners = get_scanners()
    dcm = read_dicom(dcm_path)
    z = read_z(dcm)
    station = (getattr(dcm, "StationName", "") or "").strip() or "UNKNOWN"
    name, threshold = scanners.get(station, (station, None))
    ok = None if threshold is None else z >= threshold
    return {"scanner": name, "station": station, "z": z, "threshold": threshold, "ok": ok}

