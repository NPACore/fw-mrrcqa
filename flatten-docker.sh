#!/usr/bin/env bash
set -xeuo pipefail
image_in=npac/mrrcqa-ml:1.5.2.20260221
image_out=fw.mrrc.upmc.edu/mrrcqa:1.5.2.20260221
# dryrun docker create --name tmp-exporter $image_in
# docker export tmp-exporter | docker import - $image_out
# docker rm tmp-exporter

save_as=${image_out/*\//}; save_as=${save_as//:/.}
docker save $image_out | bzip2 > $save_as.tar.bz2

# # send to docker VM on same host as flywheel registry
# # NB- scp much faster? just time-of-day network?
# rsync --progress -avhi mrrcqa.1.5.2.20260221.tar.bz2 mrrc-zeus:/raidzeus/flywheel/
# ssh -t z virsh console docker-test
#   docker load -i /raidzeus/flywheel/mrrcqa.1.5.2.20260221.tar.bz2
#   docker push fw.mrrc.upmc.edu/mrrcqa:1.5.2.20260221
#   docker image tag fw.mrrc.upmc.edu/mrrcqa:1.5.2.20260221 npac/mrrcqa-ml:1.5.2.20260221
#   cd ~/src/fw-mrrcqa
#   ~/.fw/fw-beta gear upload
