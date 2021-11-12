# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE=nvidia/cuda:11.4.2-base-ubuntu20.04
ARG CUDA_DEVEL=nvidia/cuda:11.4.2-devel-ubuntu20.04

FROM ${BASE_IMAGE} as base
FROM ${CUDA_DEVEL} as devel

FROM base as base-amd64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz fixuid.tar.gz
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz  sccache.tar.gz

FROM base as base-arm64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-arm64.tar.gz fixuid.tar.gz
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-aarch64-unknown-linux-musl.tar.gz sccache.tar.gz

#########################################
# builder
#########################################
FROM base-${TARGETARCH}

WORKDIR /

# https://github.com/moby/buildkit/blob/b8462c3b7c15b14a8c30a79fad298a1de4ca9f74/frontend/dockerfile/docs/syntax.md#example-cache-apt-packages
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

ARG TARGETARCH
ARG GCC_VERSION=9
ARG UXC_VERSION=1.11

SHELL ["/bin/bash", "-c"]

COPY --chown=root:root build/* /opt/bin/

RUN --mount=type=cache,target=/var/lib/apt \
    --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/usr/local/src/ucx \
    --mount=type=bind,from=devel,source=/usr/local/cuda/,target=/usr/local/cuda/ \
    export DEBIAN_FRONTEND=noninteractive \
 && PATH="$PATH:/opt/bin" \
 && install-dependencies  \
 && install-non-root-user \
 && clean-up-dependencies \
 # Clean up layer
 && rm -rf /tmp/* /opt/bin /usr/local/src/*.tar.gz /var/tmp/*

ENV LANG=en_US.UTF-8
# Needed for CMake's legacy FindPackage(CUDA) when we're using colornvcc
ENV CUDA_BIN_PATH=${CUDA_HOME}
# Some libs use this envvar to know the path to nvcc
ENV NVCC=/usr/local/nvidia/bin/nvcc
# Colorized compiler output
ENV GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"

# Add build scripts
COPY --chown=root:root usr/bin/* /usr/bin/
# Add colornvcc configuration
COPY --chown=root:root etc/colornvccrc /etc/colornvccrc
# Add the colornvcc compiler wrapper
COPY --chown=root:root usr/local/nvidia/bin/colornvcc /usr/local/nvidia/bin/nvcc

WORKDIR /opt/rapids

USER rapids:rapids

ENTRYPOINT ["fixuid", "-q"]

CMD ["/bin/bash", "-l"]
