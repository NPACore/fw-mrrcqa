.PHONY: all test
all: .gear-run.txt
.docker: Dockerfile run.py
	docker build -t npac/$(shell jq -r .name manifest.json):$(shell jq -r .version manifest.json)  ./ 
	date > $@

.gear: .docker
	# source /home/foranw/src/fw-beta-cli/.venv/bin/activate
	fw-beta gear build .
	date > $@

config.json: .gear
	fw-beta gear config --new
	fw-beta gear config --input phantom_nifti=/home/foranw/mybrain.nii

input/phantom_nifti:
	mkdir input/phantom_nifti -p
	cp ~/mybrain.nii input/phantom_nifti

.gear-run.txt: config.json input/phantom_nifti
	fw-beta gear run | tee $@

install: .gear-run.txt
	fw-beta gear upload

example/QA_PRISMA3QA_20240809_180204_160000:
	cd example && unzip QA_PRISMA3QA_20240809_180204_160000.zip

test: example/QA_PRISMA3QA_20240809_180204_160000 
	cd Program/ && octave --eval "test readshimvalues"
