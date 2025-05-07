#!/usr/bin/env bash

export GUIX_PROFILE=/home/foranw/.guix-profile
source $GUIX_PROFILE/etc/profile
export PATH="/home/foranw/.config/guix/current/bin:$PATH"
cd -P "$(dirname $0)"
source ../.venv/bin/activate # python3 -m venv ../.venv
./run_all_mrrcqa.py
