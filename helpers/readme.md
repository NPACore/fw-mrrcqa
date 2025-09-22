# MRRC QA Helpers
This directory contains auxiliary scripts to facilitate cleanup and export of the QC gear and data. 
The scripts interface with Flywheel and the dokuwiki website.

`00_update_wiki_snr.bash` is the main entry point that calls `plots.R`, used in cron like:

```
0  8 *   *   *   /raidzeus/src/fw-mrrcqa/helpers/00_update_wiki_snr.bash
```

`plots.R` uses
  1.  `snr_from_db.py` to query the flywheel database for all snr measures 
     * values are written by `../Program/run.py` when run as a flywheel gear.
     * values are pulled using the [Flywheel Python SDK](https://flywheel-io.gitlab.io/product/backend/sdk/) and assume previous authentication with the [CLI](https://docs.flywheel.io/CLI/) (`fw login`)
  2. ggplot to create a visually summary and highlight outliers over time on the 3 Prisma scanenrs , especially `Z` shim and `tsnr` values
  3. `wiki_upload.py` to upload the plot to https://wiki.mrrc.pitt.edu/doku.php?id=scan
     * over [XML-RPC](https://www.dokuwiki.org/devel:xmlrpc)
     * credentials pulled from env (`WIKIUSER`/`WIKIPASS`) or [`pass`](https://www.passwordstore.org/)

| script | desc |
| --- | --- |
| `00_update_wiki_snr.bash` | setup env for cron run on Zeus nightly |
| `plots.R`                 | plot SNR, uses `reticulate` to import `snr_from_db.py` and `wiki_upload.py` |
| `run_all_mrrcqa.py`       | rerun gear on all outdated  |
| `snr_from_db.py`          | `SNR` class |
| `wiki_upload.py`          |  `DokuWiki` class, `upload_snr`. uses XML-RPC interface |
| | |
| `updatedb.py`             | used once -- write session info with gear output. this is now done by the gear |
| `wiki_http.py`            | wiki interaction via http POST. Deprecated in favor of `wiki_upload.py` |
