.PHONY: all test example
DOCKER_NAME := $(shell jq -r '.custom."gear-builder".image' manifest.json)

all: .gear-run.txt
.docker: Dockerfile $(wildcard Program/*)
	docker build -t $(DOCKER_NAME) ./
	date > $@

.gear: manifest.json .docker
	# source /home/foranw/src/fw-beta-cli/.venv/bin/activate
	fw-beta gear build .
	date > $@

config.json: .gear input/phantom_dicom/trunc.zip
	fw-beta gear config --new
	fw-beta gear config --input phantom_dicom=$(PWD)/input/phantom_dicom/trunc.zip


.gear-run.txt: config.json input/phantom_dicom/trunc.zip
	fw-beta gear run | tee $@

install: .gear-run.txt
	fw-beta gear upload

input/QA_PRISMA3QA_20240809_180204_160000/: | input/
	curl -L "https://github.com/NPACore/fw-mrrcqa/releases/download/1.0.20240822_pre-alpa/QA_PRISMA3QA_20240809_180204_160000.zip" > input/QA_PRISMA3QA_20240809_180204_160000.zip
	cd input && unzip QA_PRISMA3QA_20240809_180204_160000.zip

example: outputs/stats.json
outputs/stats.json: $(wildcard Program/*m) input/trunc/
	Program/QC.m input/trunc

# copy only 4 over for quick testing
input/trunc/: input/QA_PRISMA3QA_20240809_180204_160000/
	mkdir $@
	find input/QA_PRISMA3QA_20240809_180204_160000/EP2D_BOLD_P2_S2_5MIN_0003/ -type f -iname '*IMA' |head -n 5|xargs cp -t $@ 

input/phantom_dicom/trunc.zip: input/trunc/
	mkdir -p $(dir $@)
	cd input/trunc/ && zip $(PWD)/$@ -r ./

test: Program/readshimvalues.m Program/find_all_dicoms.m input/trunc/
	cd Program/ && octave --eval "test readshimvalues; test find_all_dicoms;" #|& tee ../$@

test-docker: .docker
	docker run -v $(PWD)/input:/flywheel/input:ro --rm --entrypoint "octave" $(DOCKER_NAME) --eval "cd /flywheel/v0/; test readshimvalues"

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
