# want to keep the same base layer to avoid redownload octave every update
# podman pull  docker://python:3.13-slim-trixie # pulled 20250822
#   docker inspect --format='{{index .RepoDigests 0}} {{.Created}}' python:3.13-slim-trixie
#   ... 2025-08-14 21:49:23 +0000 UTC
FROM docker.io/library/python@sha256:27f90d79cc85e9b7b2560063ef44fa0e9eaae7a7c3f5a9f74563065c5477cc24


RUN apt update -y \
  && apt-get -y install\
               unzip dcm2niix datamash libexpat1 \
  && pip install nibabel flywheel-sdk --break-system-packages \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && apt-get autoclean -y \
  && rm -rf /var/lib/apt/lists/
  
ENV FLYWHEEL=/flywheel/v0
RUN mkdir -p ${FLYWHEEL}
ENV ANTSPATH=/usr/bin

# ANTs and AFNI binaries, just the minimal needed
# COPY --from= afni/afni_make_build:AFNI_25.2.08 /opt/afni/install/{3dROIstats,3dmaskave,3dTstat,libf2c.so,libmri.so /usr/bin/
COPY local_bin/* /usr/bin/

# have but dont need ref/bullet_phantom_ref.nii.gz
# it's not centered a la ../Program/dostat.m:220
COPY ref ${FLYWHEEL}/ref

COPY QA_ants.bash hist_peaks.py hist_mode ${FLYWHEEL}/

ENTRYPOINT ${FLYWHEEL}/QA_ants.bash
