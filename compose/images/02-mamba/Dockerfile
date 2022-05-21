# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE
ARG MAMBA_VERSION=4.12.0-0

FROM condaforge/mambaforge:${MAMBA_VERSION} as mambaforge

FROM scratch as srcs-amd64
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz  /usr/src/sccache.tar.gz

FROM scratch as srcs-arm64
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-aarch64-unknown-linux-musl.tar.gz /usr/src/sccache.tar.gz

FROM srcs-${TARGETARCH} as srcs

#########
# mamba #
#########
FROM ${BASE_IMAGE}

USER root
WORKDIR /

ARG TARGETARCH
ARG PYTHON_VERSION=3.9
ENV PYTHON_VERSION="$PYTHON_VERSION"

COPY --from=mambaforge /opt/conda /opt/conda

ENV PATH="/opt/conda/bin:$PATH"

RUN --mount=type=secret,id=creds \
    --mount=type=bind,source=build,target=/opt/bin \
    # Mount in the downloaded files
    --mount=type=bind,from=srcs,source=/usr/src,target=/usr/src \
    if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

# Add utility scripts
COPY --chown=root:root usr/local/bin/* /usr/local/bin/

ENV CC="gcc"
ENV CXX="g++"
ENV CONDA_OVERRIDE_CUDA=${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}

USER user:user
WORKDIR /home/user
