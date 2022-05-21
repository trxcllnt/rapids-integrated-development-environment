# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE

FROM ${BASE_IMAGE} as base

FROM base as base-amd64

FROM base as base-arm64

##########
# python #
##########
FROM base-${TARGETARCH}

USER root
WORKDIR /

ARG TARGETARCH
ARG PYTHON_VERSION=3.9
ENV PYTHON_VERSION="$PYTHON_VERSION"

RUN --mount=type=secret,id=creds \
    --mount=type=bind,source=build,target=/opt/bin \
    if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

# Add utility scripts
COPY --chown=root:root usr/local/bin /usr/local/bin

ENV PYTHONDONTWRITEBYTECODE=1

USER user:user
WORKDIR /home/user
