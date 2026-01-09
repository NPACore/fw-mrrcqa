import pydicom
from fwhm import fid_fwhm

def test_fid_fwhm():
    """Confirm fwhm works with example data"""
    input_file = './FWHM/qa_fid.dcm'
    expected_output = 26.951

    dicom_dataset = pydicom.dcmread(input_file)
    result = fid_fwhm(dicom_dataset, plot=False)  # Disable plotting for the test
    assert abs(result - expected_output) < 1e-3, f"Expected {expected_output}, got {result}"
