.SUFFIXES:
.SECONDARY:
.PHONY: all
DOCKER_ANTS_VER=1.0.0

all: .docker

../input/trunc/:
	make -C .. $@

../outputs/ants/snr.tsv: ../input/trunc/ QA_ants.bash hist_mode
	./QA_ants.bash ../input/trunc $(dir $@) $(dir $@)

hist_mode: hist_mode.c
	gcc ./hist_mode.c -o hist_mode

.docker: Dockerfile hist_mode QA_ants.bash local_bin/
	docker build -t npac/mrrcqa-ants:$(DOCKER_ANTS_VER) -f Dockerfile
	docker inspect --format='{{index .RepoDigests 0}} {{.Created}}' npac/mrrcqa-ants:$(DOCKER_ANTS_VER) > $@
