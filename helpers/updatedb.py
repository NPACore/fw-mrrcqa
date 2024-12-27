#!/usr/bin/env python3
"""
Update FW DB. Add 'snr' to all QC sessions.
Rerunning should have no affect.
Future (after 20241226) QC gear should do this automaticaly (SDK gear)
"""

import flywheel # pip install flywheel-sdk
import json     # read matlab/gear output
import logging
from tempfile import NamedTemporaryFile
fw = flywheel.Client()

Acq = flywheel.models.acquisition_list_output.AcquisitionListOutput
logging.basicConfig(level=logging.INFO)

def get_stats(acq: Acq) -> dict:
    """Fetch json contents. Use a temporary file to download."""
    with NamedTemporaryFile(suffix='_stat.json') as x:
        acq.download_file('stats.json',x.name)
        stat = json.load(x)
    return stat

def update_stat(acq: Acq) -> bool:
    """Add snr peak to FW DB as 'snr' in session."""
    ses = fw.get(acq.session)
    if ses.info.get('snr'):
        logging.info("skipping %s, have %s", ses.label, ses.info)
        return False

    stats = get_stats(acq)
    snr = stats.get('snrpk')
    if not snr:
        logging.warning("%s has no snr peak in stats.json", ses.label)
        return False

    ses.update_info({'snr': snr})
    return True

if __name__ == "__main__":
    acqs = fw.acquisitions.find(filter=f"label=ep2d_bold_p2_s2_5min")
    # skip any missing the gear output stats json file
    acqs = list(filter(lambda x: x.get_file('stats.json'), acqs))
    assert len(acqs) > 1
    for acq in acqs:
        update_stat(acq)
