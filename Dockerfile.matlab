# want to keep the same base layer to avoid redownload octave every bookwarm-slim update
# docker inspect --format='{{index .RepoDigests 0}} {{.Created}}' debian:bookworm-slim
#  debian@sha256:12c396bd585df7ec21d5679bb6a83d4878bc4415ce926c9e5ea6426d23c60bdc 2025-02-24T00:00:00Z
FROM debian@sha256:12c396bd585df7ec21d5679bb6a83d4878bc4415ce926c9e5ea6426d23c60bdc

### ML
# alt: docker pull containers.mathworks.com/matlab-runtime:2021a
# Nothing special about R2021a.
# It's just what we're running locally: '9.10.0.1710957 (R2021a) Update 4' (20251211)
RUN apt-get -q update && \
    apt-get install -q -y --no-install-recommends \
      unzip \
      curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
   mkdir /mcr-install && \
   cd /mcr-install && \
   curl -Lk https://ssd.mathworks.com/supportfiles/downloads/R2021a/Release/8/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2021a_Update_8_glnxa64.zip > MATLAB_Runtime.zip   && \
    unzip -q MATLAB_Runtime.zip && \
    rm -f MATLAB_Runtime.zip && \
    ./install -destinationFolder /opt/mcr -agreeToLicense yes -mode silent && \
    cd / && \
    rm -rf mcr-install

ENV LD_LIBRARY_PATH="/opt/mcr/v910/runtime/glnxa64:/opt/mcr/v910/bin/glnxa64:/opt/mcr/v910/sys/os/glnxa64:/opt/mcr/v910/extern/bin/glnxa64:."
RUN ln -s /usr/lib/x86_64-linux-gnu/libgsl.so.27.0.0  /usr/lib/x86_64-linux-gnu/libgsl.so.0

### FW
ENV FLYWHEEL=/flywheel/v0
RUN mkdir -p ${FLYWHEEL}
# rewrite what would be 'mlbin/run_qastats.sh'. hard code LD_LIBRARY_PATH above so need much less
# could get away without a run.sh at all but dont want to change dostats order 
# and want to inject second figure argument to be 0 (no plot)
RUN \
  echo "#!/usr/bin/env sh\nin=\$1;shift; ${FLYWHEEL}/qastats \$in 0 \$@;" > $FLYWHEEL/run.sh  && \
  chmod +x $FLYWHEEL/run.sh

ENTRYPOINT ["/flywheel/v0/run.sh"]

# actual code.
# last so we dont have to update everything else when this changes
# see 'make mlbin/qastats'
ADD mlbin/qastats ${FLYWHEEL}/
