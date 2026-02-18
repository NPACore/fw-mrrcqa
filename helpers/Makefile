.SUFFIXES:
.PHONY: all .ALWAYS
all: PhantomQC.csv

tempurature_log.xlsx: .ALWAYS
	./00_get_temp.bash

PhantomQC.csv: tempurature_log.xlsx
	NOUPLOAD=1 ./00_update_wiki_snr.bash

# 20260127, run on recontwix@recontwix
#           also see ../FID/fw_run.py; ./00_update_wiki_snr.bash (zeus cron)
DailyQA.png: # PhantomQC.csv # csv not needed, pull from wiki via system('curl') in matlab
	matlab -nodisplay -r 'try, run ./plot_qa_from_csv.m;catch e,disp(e);end, quit'
	bash -c "source .creds && ./wiki_upload.py DailyQA.png DailyQA.png"

# in cron like
# 0 12 * * 3 make -C /home/recontwix/src/fw-mrrcqa/helpers -Bs DailyQA.png WeekStats-FWHM.txt
WeekStats-FWHM.txt:
	echo "# generated $(shell whoami) @ $(shell hostname) on $(shell date) [by cron? $(RUN_BY_CRON)]" > $@
	MEASURES=fwhm SCANNERS=Prisma1,Prisma2,Prisma3 ./p2_coil_updates.R >> $@
	mountpoint -q /mnt/conference && mkdir -p /mnt/conference/$(shell date +%Y%m%d)/
	cp $@ DailyQA.png /mnt/conference/$(shell date +%Y%m%d)/
