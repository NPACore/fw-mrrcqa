cd "$(dirname "$0")"
source ../.venv/bin/activate
source .creds
# python3 -m pip install -r ./requirements.txt
# DRYRUN=1 ./run_all_mrrcqa.py
./snr_from_db.py -u > snr_wiki.log 2>&1
