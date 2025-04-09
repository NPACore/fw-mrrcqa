# want to keep the same base layer to avoid redownload octave every bookwarm-slim update
# docker inspect --format='{{index .RepoDigests 0}} {{.Created}}' debian:bookworm-slim
#  debian@sha256:12c396bd585df7ec21d5679bb6a83d4878bc4415ce926c9e5ea6426d23c60bdc 2025-02-24T00:00:00Z
FROM debian@sha256:12c396bd585df7ec21d5679bb6a83d4878bc4415ce926c9e5ea6426d23c60bdc

RUN apt update -y \
  && apt-get -y install octave \
               octave-dicom \
               octave-image \
               python3 python3-pip \
               unzip \
  && pip install nibabel flywheel-sdk --break-system-packages \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/
  
ENV FLYWHEEL=/flywheel/v0
RUN mkdir -p ${FLYWHEEL}
COPY Program/ ${FLYWHEEL}/

ENTRYPOINT ["${FLYWHEEL}/QC.m"]
