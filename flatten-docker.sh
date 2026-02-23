#!/usr/bin/env bash
set -xeuo pipefail
cd $(dirname "$0")

image_in=$(jq -r '.custom."gear-builder".image' manifest.json) # npac/mrrcqa-ml:1.5.2.20260222
image_out=fw.mrrc.upmc.edu/$(jq -r '.name + ":" + .version' manifest.json)

# record metadata not in filesystem: entrypoing and LD PATH needed for matlab
#mapfile -t change_args < <( docker inspect $image_in | jq -r '.[0].Config.Env[] | "--change=ENV \(.)"')
change_args=(
	"--change=ENV $(docker inspect $image_in |
		jq -r '.[0].Config.Env[]|select(match("LD"))')"
	"--change=ENTRYPOINT $(docker inspect $image_in |
		jq -r '.[0].Config.Entrypoint|tojson')")

docker create --name tmp-exporter $image_in
docker export tmp-exporter | \
  docker import "${change_args[@]}" - $image_out
docker rm tmp-exporter

save_as=${image_out/*\//}; save_as=${save_as//:/.}.tar.bz2
docker save $image_out | bzip2 > $save_as

# # send to docker VM on same host as flywheel registry
# # NB- scp much faster? just time-of-day network?
rsync --progress -avhi $save_as mrrc-zeus:/raidzeus/flywheel/

cat <<HERE
# ssh -t z virsh console docker-test
#   docker load -i /raidzeus/flywheel/$save_as
#   docker push $image_out
#   docker image tag $image_out $image_in
#   cd ~/src/fw-mrrcqa
#   ~/.fw/fw-beta gear upload
HERE
