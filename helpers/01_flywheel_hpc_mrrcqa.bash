#!/usr/bin/env bash
# As of 20260316: this file run by cron at 8am on zeus
# catches any missing tsnr and runs all FWHM (qa_fid and svs_se_30_wat)

export GUIX_PROFILE=/home/foranw/.guix-profile
source $GUIX_PROFILE/etc/profile
export PATH="$HOME/.config/guix/current/bin:$PATH"

cd -P "$(dirname "$0")" || exit $?

source ../.venv/bin/activate # python3 -m venv ../.venv
./run_all_mrrcqa.py # catchup any missing of this gear (launched into cerebro2 HPC via slurm/singularity)
../FID/fw_run.py # create session info 'fwhm' on qa_fid
ACQ_LABEL='svs_se_30' ../FID/fw_run.py # create session info 'fwhm_svs'
