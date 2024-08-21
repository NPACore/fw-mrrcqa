FROM alpine:latest
RUN apk add --update \
    python3 \
    py-pip \
  && pip install nibabel flywheel-sdk --break-system-packages \
  && rm -rf /var/cache/apk/*
  
ENV FLYWHEEL=/flywheel/v0
RUN mkdir -p ${FLYWHEEL}
COPY run.py ${FLYWHEEL}/run.py

ENTRYPOINT ["python3 run.py"]
