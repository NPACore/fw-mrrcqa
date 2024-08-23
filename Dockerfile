FROM debian:bookworm-slim
RUN apt update -y \
  && apt-get -y install octave \
               octave-dicom \
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
