# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE

########
# cudf #
########
FROM ${BASE_IMAGE}

USER root
WORKDIR /

RUN --mount=type=secret,id=creds \
    --mount=type=bind,source=build,target=/opt/bin \
    if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

USER user:user
WORKDIR /home/user
