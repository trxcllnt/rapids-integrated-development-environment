# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE
ARG MAMBA_VERSION=4.12.0-0

FROM ${BASE_IMAGE} as base
FROM condaforge/mambaforge:${MAMBA_VERSION} as mambaforge

FROM base as base-amd64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz  sccache.tar.gz

FROM base as base-arm64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-aarch64-unknown-linux-musl.tar.gz sccache.tar.gz

#########
# mamba #
#########
FROM base-${TARGETARCH}

USER root
WORKDIR /

ARG TARGETARCH
ARG PYTHON_VERSION=3.9
ENV PYTHON_VERSION="$PYTHON_VERSION"

COPY --from=mambaforge /opt/conda /opt/conda

ENV PATH="/opt/conda/bin:$PATH"

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=bind,source=build,target=/opt/bin \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

# Add utility scripts
COPY --chown=root:root usr/local/bin/* /usr/local/bin/

ENV CC="gcc"
ENV CXX="g++"
ENV CONDA_OVERRIDE_CUDA=${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}

USER user:user
WORKDIR /home/user
