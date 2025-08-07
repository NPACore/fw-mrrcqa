.SUFFIXES:
.PHONY: all .ALWAYS
all: PhantomQC.csv

tempurature_log.xlsx: .ALWAYS
	./00_get_temp.bash

PhantomQC.csv: tempurature_log.xlsx
	NOUPLOAD=1 ./00_update_wiki_snr.bash
