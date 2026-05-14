import pydicom
from fwhm import fid_fwhm

def test_fid_fwhm():
    """Confirm fwhm works with example data"""
    input_file = 'test/data/qa_fid.dcm'
    expected_output = 31.63809

    dicom_dataset = pydicom.dcmread(input_file)
    result = fid_fwhm(dicom_dataset, plot=False)  # Disable plotting for the test
    assert abs(result - expected_output) < 1e-3, f"Expected {expected_output}, got {result}"

def test_fid_fwhm_small_nointerp():
    """Confirm fwhm works with example data"""
    input_file = 'test/data/svs_Se_30_wat.dcm'
    dicom_dataset = pydicom.dcmread(input_file)

    expected_output = 7.031
    result = fid_fwhm(dicom_dataset, plot=False, interp_fac=0) 
    assert abs(result - expected_output) < 1e-3, f"Expected {expected_output}, got {result}"

def test_fid_fwhm_small_interp():
    """Confirm fwhm works with example data"""
    input_file = 'test/data/svs_Se_30_wat.dcm'
    dicom_dataset = pydicom.dcmread(input_file)

    expected_output = 7.617
    result = fid_fwhm(dicom_dataset, plot=False) 
    assert abs(result - expected_output) < 1e-3, f"Expected {expected_output}, got {result}"
