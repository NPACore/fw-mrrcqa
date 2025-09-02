docker run --entrypoint /flywheel/v0/QA_ants.bash \
   -v $PWD/../input/:/input \
   -v $PWD/../outputs/ants_docker:/outputs/ \
   npac/mrrcqa-ants:1.0.0  \
   /input/trunc/ /ouputs /outputs
