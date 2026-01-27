.SUFFIXES:
.PHONY: all .ALWAYS
all: PhantomQC.csv

tempurature_log.xlsx: .ALWAYS
	./00_get_temp.bash

PhantomQC.csv: tempurature_log.xlsx
	NOUPLOAD=1 ./00_update_wiki_snr.bash

# 20260127, run on recontwix@recontwix
#           also see ../FID/fw_run.py; ./00_update_wiki_snr.bash
DailyQA.png: # PhantomQC.csv
	matlab -nodisplay -r 'try, run ./plot_qa_from_csv.m;catch e,disp(e);end, quit'
	command -v pass && pass wiki/npac >/dev/null && ./wiki_upload.py DailyQA.png DailyQA.png
