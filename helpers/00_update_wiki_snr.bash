#!/usr/bin/env bash

# update tsnr plot on wiki
#  https://wiki.mrrc.pitt.edu/doku.php?id=scan
# expect to be run by cron
# after flywheel has run ../Program/run.py on newest phantomQA
#
# 20250407WF - working on Zeus with guix

cd "$(dirname "$0")"
source .creds # set WIKIUSER and WIKIPASS

# if env not set, use 'pass' with hard codd ponts. to set
# gpg2 --gen-key; gpg2 --list-secret-keys --keyid-format LONG; pass init ABCDEF1234567890
# pass create wiki/npac

# # python setup
# python3 -m pip install -r ./requirements.txt
# DRYRUN=1 ./run_all_mrrcqa.py
#./snr_from_db.py -u > snr_wiki.log 2>&1

make tempurature_log.xlsx
case "$(uname -a)" in
 *Zeus*|*cerebro2*)
   # 20250407 - use guix
   # likely in /raidzeus/src/fw-mrrcqa/helpers
   export GUIX_PROFILE=${HOME:=/home/foranw}/.guix-profile
   source $GUIX_PROFILE/etc/profile
   export PATH="$GUIX_PROFILE/bin:$PATH"
   export R_LIBS_USER=$HOME/R

   # 20250229 - switch to wiki.mrrc.pitt.edu. wiki allowed by firefox, but not curl/requests
   #            lazy fix in wiki_upload.py: ssl._create_unverified_context
   #export SSL_CERT_DIR="$HOME/etc/ssl/certs"
   #export SSL_CERT_FILE="$SSL_CERT_DIR/ca-certificates.crt"
   #export GIT_SSL_CAINFO="$SSL_CERT_FILE" CURL_CA_BUNDLE="$SSL_CERT_FILE"
   # guix shell ...  nss-certs

   guix shell \
     glibc@2.39 r r-ggrepel r-pacman r-reticulate r-dplyr r-tidyr r-ggplot2 r-lubridate r-lubridate r-cowplot r-readxl -- \
     ./plots.R;;
 *) # *crc*
   [[ $(uname -a) =~ crc ]] && module load python/ondemand-jupyter-python3.11 r
   source ../.venv/bin/activate # python3 -m venv ../.venv
   ./plots.R;;
esac
