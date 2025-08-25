#!/usr/bin/env python3
"""
histogram measure to more closely match matlab stats
 - matlab has mean&sd (tsnr) measure per slice per timepoint 46x200
 - we have tsnr per voxel 94x94x46
46x200
"""
import sys
from nibabel import load
import numpy as np
#(epi_file, tsnr_file, mask_file) = sys.argv[1:3]
(epi_file, tsnr_file, mask_file) = ('./input/bullet_phantom_epi.nii.gz', '/tmp/tsnr/tsnr.nii.gz','ref/qa_masks.nii')
epi = load(epi_file)
mask = load(mask_file)
tsnr = load(tsnr_file)

regions=('phan_erode','bg', 'noise', 'readout', 'phaseenc', 'alias')
nregion = mask.shape[3]
if len(regions) != nregion:
    raise Exception(f"Mask file {mask_file} does not match regions: {regions}")

def hist_peak_val(arr, roi_mask=None):
    """center value of histogram bin with most elements. median if normal distro"""
    (n_in_bin, val) = np.histogram(arr, bins=120, weights=roi_mask)
    biggest_bin = np.argmax(n_in_bin)
    return val[biggest_bin]

def tsv_dict(dt: dict):
    print("\n".join([f"{k}\t{v}" for (k,v) in dt.items()]))

tsnr_pk = {}
for roi_i,region in enumerate(regions):
    roi_mask = mask.dataobj[:,:,:, roi_i]
    tsnr_pk[region] = hist_peak_val(tsnr.dataobj, roi_mask)
tsv_dict(tsnr_pk)

snr_pk = {}
noise_mask = mask.dataobj[:,:,:, regions.index('noise')]==1
# move time dim to the front for easy broadcasting? Not sure this works as expected
epi_data = np.moveaxis(epi.dataobj,3,0)
epi_noise = np.ma.masked_array(epi_data, mask=np.broadcast_to(noise_mask!=1, epi_data.shape))


mean_ts = np.zeros((len(regions),epi_data.shape[0]))
noise_sd = epi_noise.std(axis=(1,2,3)) # 200 measures of sd -- one for each timestep
for region in ['phan_erode','alias', 'bg']:
    roi_i = regions.index(region)
    roi_mask = mask.dataobj[:,:,:, roi_i]
    epi_mask = np.ma.masked_array(epi_data, mask=np.broadcast_to(roi_mask != 1, epi_data.shape))
    ts = epi_mask.mean(axis=(1,2,3))
    snr_pk[region] = hist_peak_val(ts / noise_sd)
    mean_ts[roi_i,:] = ts # only used for visualizing
tsv_dict(snr_pk)

def vis_inspect():
    import matplotlib.pyplot as plt
    plt.subplot(2,2,1); plt.imshow(epi.dataobj[:,:,20,0]);plt.title('z=20 t=0')
    plt.subplot(2,2,2); plt.imshow(epi_data[0,:,:,20]); plt.title('moveaxis')
    #test_maskk = np.ma.maked_array(np.ones(noise_mask.shape), noise_mask)
    plt.subplot(2,2,3); plt.imshow(epi_noise[0,:,:,20]); plt.title('epi masked')
    plt.subplot(2,2,4); plt.imshow(noise_mask[:,:,20]); plt.title('noise mask')

    plt.figure()
    plt.subplot(2,1,1); plt.title('roi snr per TR');
    plt.ylabel('roi vol mean / noise sd'); plt.xlabel('volume')
    plt.plot(mean_ts.T, label=regions); plt.legend()

    plt.subplot(2,1,2); plt.title('snr - min(snr)');
    plt.plot(mean_ts.T - np.expand_dims(mean_ts.min(axis=1), axis=0))
    plt.tight_layout()

    plt.show()
