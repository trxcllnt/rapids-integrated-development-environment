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

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=bind,source=build,target=/opt/bin \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

# Add utility scripts
COPY --chown=root:root usr/local/bin /usr/local/bin
COPY --chown=root:root --from=base /usr/local/bin/fixuid-and-set-home /usr/local/bin/

ENV PYTHONDONTWRITEBYTECODE=1

USER user:user
WORKDIR /home/user
