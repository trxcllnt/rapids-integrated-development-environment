# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE=nvidia/cuda:11.6.0-base-ubuntu20.04

FROM ${BASE_IMAGE} as base

FROM base as base-amd64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh miniconda.sh
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz fixuid.tar.gz
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz  sccache.tar.gz

FROM base as base-arm64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh miniconda.sh
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-arm64.tar.gz fixuid.tar.gz
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-aarch64-unknown-linux-musl.tar.gz sccache.tar.gz

#########################################
# conda-builder
#########################################
FROM base-${TARGETARCH}

WORKDIR /

ARG TARGETARCH

SHELL ["/bin/bash", "-c"]

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=bind,source=build,target=/opt/bin \
    export DEBIAN_FRONTEND=noninteractive \
 && PATH="$PATH:/opt/bin" \
 && install-dependencies  \
 && install-non-root-user \
 && clean-up-dependencies

ENV LANG=en_US.UTF-8
# Colorized compiler output
ENV GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
# Add utility scripts
COPY --chown=root:root usr/local/bin/* /usr/local/bin/

WORKDIR /opt/rapids

USER coder:coder

# Add plugins
COPY --chown=coder:coder plugins /opt/rapids/.plugins

ENV PATH="$PATH:/opt/rapids/.bin:/opt/conda/bin"

ENTRYPOINT ["fixuid", "-q", "conda-builder-entrypoint"]

CMD ["/bin/bash", "-l"]
