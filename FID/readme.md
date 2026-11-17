After discontinuing flywheel, run on fileystem like:
```
FWHM_SAVEJSON=1 FWHM_PLOT=0 time  uv run --script ./fwhm.py\
  /disk/mace2/scan_data/homeless/Brain^Prisma*/20*/*/{qa_fid_0,svs_se_}*/UNKNOWN*\
  /raidzeus/flywheel-qc-backup/P*/Prisma3QA/SUBJECTS/P*/SESSIONS/Brain*/ACQUISITIONS/svs_se_30_wat/FILES/svs_se_30_wat.dcm
  /raidzeus/flywheel-qc-backup/P*/Prisma3QA/SUBJECTS/P*/SESSIONS/Brain*/ACQUISITIONS/qa_fid/FILES/qa_fid.dcm
```
makes files like `/raidzeus/derivatives/projs/QC/out/2026.11.17-06.19.14-Prisma3-svs_06/fwhm.json`

```
jq -r '[.fwhm,input_filename,.dcm]|@tsv' /raidzeus/derivatives/projs/QC/out/*/fwhm.jso
```

