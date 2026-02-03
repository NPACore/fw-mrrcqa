# MRRC QA Helpers
This directory contains auxiliary scripts to facilitate cleanup and export of the QC gear and data. 
The scripts interface with Flywheel, the dokuwiki website, and the conference room.


## Flywheel catch up
`01_flywheel_hpc_mrrcqa.bash` catches any missed flywheel gear triggers for both the FID file-curator ([`../FID`](../FID)) and the fw-mrrcqa gear.

## Stats
### phantomqc.csv and plot
`00_update_wiki_snr.bash` is the main entry point that calls `plots.R`, used in foranw@zeus cron like:

```
0  8 *   *   *   /raidzeus/src/fw-mrrcqa/helpers/00_update_wiki_snr.bash
```

`plots.R` uses
  1.  `snr_from_db.py` to query the flywheel database for all snr measures 
     * values are written by `../Program/run.py` when run as a flywheel gear.
     * values are pulled using the [Flywheel Python SDK](https://flywheel-io.gitlab.io/product/backend/sdk/) and assume previous authentication with the [CLI](https://docs.flywheel.io/CLI/) (`fw login`)
  1. `make tempurature_log.xlsx` to get Tech tempurature log form TWIX RAID (scp, `00_get_temp.bash`)
  2. ggplot to create a visually summary and highlight outliers over time on the 3 Prisma scanenrs , especially `Z` shim and `tsnr` values
  3. `wiki_upload.py` to upload the plot to https://wiki.mrrc.pitt.edu/doku.php?id=scan
     * over [XML-RPC](https://www.dokuwiki.org/devel:xmlrpc)
     * credentials pulled from env (`WIKIUSER`/`WIKIPASS`) or [`pass`](https://www.passwordstore.org/)

### recontwix
recontwix cron handles two additional jobs

  * `make DailyQA.png` runs `plot_qa_from_csv.m` and uploads next to plot.R image on wiki. recontwix has matlab R2019 (2026-02-03)
  * `make WeekStats-FWHM.txt` uploade this weeks FID FWHM to conference room (recontwix has smb mount).

## Scripts
| script | desc |
| --- | --- |
| `00_get_temp.bash` | sync manually recoreded scanner room tempurature |
| `00_update_wiki_snr.bash` | setup env for cron run on Zeus nightly |
| `01_flywheel_hpc_mrrcqa.bash` | find QA scans without processing, run them  |
| `Makefile` | recipes for building files. Namely `WeekStats-FWHM.txt` |
| | |
| `plots.R`                 | plot SNR, uses `reticulate` to import `snr_from_db.py` and `wiki_upload.py` |
| `run_all_mrrcqa.py`       | rerun gear on all outdated  |
| `snr_from_db.py`          | `SNR` class |
| `wiki_upload.py`          |  `DokuWiki` class, `upload_snr`. uses XML-RPC interface |
| `plot_qa_from_csv.m`      | like `plots.R` but with matlab |
| | |
| `updatedb.py`             | used once -- write session info with gear output. this is now done by the gear |
| `wiki_http.py`            | wiki interaction via http POST. Deprecated in favor of `wiki_upload.py` |
