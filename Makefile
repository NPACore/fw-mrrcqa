.PHONY: all test example
DOCKER_NAME := npac/$(shell jq -r .name manifest.json):$(shell jq -r .version manifest.json)

all: .gear-run.txt
.docker: Dockerfile $(wildcard Program/*) manifest.json
	docker build -t $(DOCKER_NAME) ./ 
	date > $@

.gear: .docker
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

test: Program/readshimvalues.m input/trunc/
	cd Program/ && octave --eval "test readshimvalues" #|& tee ../$@

test-docker: .docker
	docker run -v $(PWD)/input:/flywheel/input:ro --rm --entrypoint "octave" $(DOCKER_NAME) --eval "cd /flywheel/v0/; test readshimvalues"

%/:
	mkdir -p $@
