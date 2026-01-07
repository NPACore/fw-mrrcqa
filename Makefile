.PHONY: all test example
DOCKER_NAME := $(shell jq -r '.custom."gear-builder".image' manifest.json)

# MCC only used by old rule for manually compiled 'mlbin/qastats'
MCC ?= /opt/ni_tools/MATLAB/R2021a/bin/mcc

all: .gear-run.txt
.docker-octave: Dockerfile $(wildcard Program/*)
	docker build -t $(DOCKER_NAME)-octave -f Dockerfile ./
	date > $@

.docker-mlbase: Program/dostat.m 
	matlab -r "try, run('mlbin/00_build_mcr.m'), catch e, e, end; quit"
	docker image ls --format=json fwmrrcqa-mlbase > $@

## Flywheel
.docker-mlpy: Dockerfile.matlab-python Program/run.py .docker-mlbase
	docker build -t $(DOCKER_NAME) -f Dockerfile.matlab-python ./
	docker image ls --format=json $(DOCKER_NAME) > $@

.gear: manifest.json .docker-mlpy
	# source /home/foranw/src/fw-beta-cli/.venv/bin/activate
	fw-beta gear build . -- -f Dockerfile.matlab-python
	date > $@

config.json: .gear input/phantom_dicom/trunc.zip
	fw-beta gear config --new
	fw-beta gear config --input phantom_dicom=$(PWD)/input/phantom_dicom/trunc.zip


.gear-run.txt: config.json input/phantom_dicom/trunc.zip
	fw-beta gear run | tee $@

install: .gear-run.txt
	fw-beta gear upload

## DATA
input/QA_PRISMA3QA_20240809_180204_160000/: | input/
	curl -L "https://github.com/NPACore/fw-mrrcqa/releases/download/1.0.20240822_pre-alpa/QA_PRISMA3QA_20240809_180204_160000.zip" > input/QA_PRISMA3QA_20240809_180204_160000.zip
	cd input && unzip QA_PRISMA3QA_20240809_180204_160000.zip

example: outputs/stats.json outputs/ants/snr.tsv
outputs/stats.json: $(wildcard Program/*m) input/trunc/
	QA_SAVE_IMAGES=1 Program/QC.m input/trunc
outputs/ants/snr.tsv: input/trunc/ QA_ants.bash hist_mode
	make -C snr

# copy only 4 over for quick testing
input/trunc/: input/QA_PRISMA3QA_20240809_180204_160000/
	mkdir -p $@
	find input/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003/ -type f -iname '*IMA' |head -n 5|xargs cp -t $@ 

input/phantom_dicom/trunc.zip: input/trunc/
	mkdir -p $(dir $@)
	cd input/trunc/ && zip $(PWD)/$@ -r ./

test: Program/readshimvalues.m Program/find_all_dicoms.m input/trunc/
	cd Program/ && octave --eval "test readshimvalues; test find_all_dicoms;" #|& tee ../$@

test-docker: .docker
	docker run -v $(PWD)/input:/flywheel/input:ro --rm --entrypoint "octave" $(DOCKER_NAME) --eval "cd /flywheel/v0/; test readshimvalues"

local_bin/:
	mkdir -p $@
	docker run  afni/afni_make_build:AFNI_25.2.08 bash -c "cd /opt/afni/install/; tar -cf- 3dinfo 3dROIstats 3dmaskave 3dTstat 3dcalc libf2c.so libmri.so" |sed 1d | tar -C local_bin/ -xvf-

	# static binaries
	cp `which antsRegistrationSyN.sh` `which antsApplyTransforms` `which ANTS` `which antsRegistration` `which PrintHeader` `which ConvertTransformFile` $@
	# using docker would be nicer,reproducable. but it uses linked binaries.
	# would need ants*.so and many ITK, libitkgdcm, etc libs
	# docker run docker.io/antsx/ants:v2.6.2 bash -c "cd /opt/ants/bin/; tar -cf- antsRegistrationSyN.sh antsApplyTransforms ANTS antsRegistration PrintHeader ConvertTransformFile" | tar -C local_bin/ -xvf-

%/:
	mkdir -p $@


## DOCS
docs/snr_plot:
	helpers/snr_from_db.py --png docs/snr_plot.png
.venv:
	python3 -m virtualenv .venv
	source .venv/bin/activate && pip install -r requirements_docs.txt

Program/mask_structuring_elements.mat: Program/mask_structuring_elements.m
	cd $(dir $@) && matlab -nodisplay -r 'try, run mask_structuring_elements; end; quit'

## not needed with newer matlab.
# see mlbin/00_build_mcr.m
mlbin/qastats: Program/dostat.m 
	mkdir -p $(dir $@)
	cd $(dir $@) && $(MCC) -m ../$? -o $(notdir $@)

mlbin/installer_input.txt: mlbin/qastats
	cd $(dir $@) && matlab -r "try, run('buildcontainer'); catch e,e,end; quit"

.docker-ml.large-hand-built: Dockerfile.matlab mlbin/qastats
	docker build -t $(DOCKER_NAME) -f Dockerfile.matlab ./
	date > $@
