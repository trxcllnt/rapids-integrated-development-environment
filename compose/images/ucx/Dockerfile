# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE
ARG IMAGE_TYPE
ARG CUDA_DEVEL_IMAGE

FROM scratch as srcs-cpp
ONBUILD ARG UCX_VERSION=1.12.1
ONBUILD ADD https://github.com/openucx/ucx/archive/refs/tags/v${UCX_VERSION}.zip /usr/src/ucx.zip

FROM srcs-cpp as srcs-python
ONBUILD ARG UCX_PY_BRANCH=branch-0.26
ONBUILD ADD https://github.com/rapidsai/ucx-py/archive/refs/heads/${UCX_PY_BRANCH}.zip /usr/src/ucx-py.zip

FROM srcs-${IMAGE_TYPE} as srcs

FROM ${CUDA_DEVEL_IMAGE} as cuda-devel

#######
# ucx #
#######
FROM ${BASE_IMAGE}

USER root
WORKDIR /

ARG TARGETARCH
ARG UCX_VERSION
ARG UCX_PY_BRANCH

RUN --mount=type=secret,id=creds \
    # Mount in the downloaded files
    --mount=type=bind,from=srcs,source=/usr/src,target=/usr/src \
    # Mount in the CUDA Toolkit
    --mount=type=bind,from=cuda-devel,source=/usr/local/cuda/,target=/usr/local/cuda/ \
    # Mount in build scripts
    --mount=type=bind,source=build/install-dependencies,target=/opt/bin/install-dependencies \
    --mount=type=bind,source=build/clean-up-dependencies,target=/opt/bin/clean-up-dependencies \
    if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

RUN --mount=type=secret,id=creds \
    # Mount in the downloaded files
    --mount=type=bind,from=srcs,source=/usr/src,target=/usr/src \
    # Mount in the CUDA Toolkit
    --mount=type=bind,from=cuda-devel,source=/usr/local/cuda/,target=/usr/local/cuda/ \
    # Mount in build scripts
    --mount=type=bind,source=build/install-ucx,target=/opt/bin/install-ucx \
    --mount=type=bind,source=build/clean-up-dependencies,target=/opt/bin/clean-up-dependencies \
    if [[ -f /usr/src/ucx.zip ]]; then \
        if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
        /opt/bin/install-ucx \
     && /opt/bin/clean-up-dependencies; \
    fi;

RUN --mount=type=secret,id=creds \
    # Mount in the downloaded files
    --mount=type=bind,from=srcs,source=/usr/src,target=/usr/src \
    # Mount in the CUDA Toolkit
    --mount=type=bind,from=cuda-devel,source=/usr/local/cuda/,target=/usr/local/cuda/ \
    # Mount in build scripts
    --mount=type=bind,source=build/install-ucx-py,target=/opt/bin/install-ucx-py \
    --mount=type=bind,source=build/clean-up-dependencies,target=/opt/bin/clean-up-dependencies \
    if [[ -f /usr/src/ucx-py.zip ]]; then \
        if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
        /opt/bin/install-ucx-py \
     && /opt/bin/clean-up-dependencies; \
    fi;

USER user:user
WORKDIR /home/user
