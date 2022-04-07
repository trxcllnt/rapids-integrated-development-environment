# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE=pauletaylor/rapids-ide:cpp-builder-cuda11.6.0-ubuntu20.04

FROM ${BASE_IMAGE} as base

FROM base as base-amd64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/coder/code-server/releases/download/v4.2.0/code-server_4.2.0_amd64.deb code-server.deb

FROM base as base-arm64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/coder/code-server/releases/download/v4.2.0/code-server_4.2.0_arm64.deb code-server.deb

#########################################
# code-server
#########################################
FROM base-${TARGETARCH}

USER root

WORKDIR /

ARG TARGETARCH
ARG LLVM_VERSION=11

SHELL ["/bin/bash", "-c"]

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=bind,source=build,target=/opt/bin \
    export DEBIAN_FRONTEND=noninteractive \
 && export LLVM_VERSION=${LLVM_VERSION} \
 && PATH="$PATH:/opt/bin" \
 && install-dependencies  \
 && clean-up-dependencies

# Set up docker-in-docker
ENV DOCKER_TLS_CERTDIR=/certs
RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client

COPY --from=docker:20-dind /usr/local/bin/ /usr/local/bin/

VOLUME /var/lib/docker

# Copy in VSCode extensions
COPY extensions/augustocdias.tasks-shell-input-1.7.0.vsix /usr/local/src/tasks-shell-input.vsix
COPY extensions/ms-vscode.cpptools-1.9.7@linux-x64.vsix /usr/local/src/ms-vscode.cpptools.vsix
COPY extensions/NVIDIA.nsight-vscode-edition-2021.1.30130113.vsix /usr/local/src/nsight-vscode.vsix

# Copy in code-server entrypoint
COPY --chown=root:root usr/local/bin/* /usr/local/bin/

EXPOSE 8080
# This way, if someone sets $DOCKER_USER, docker-exec will still work as
# the uid will remain the same. note: only relevant if -u isn't passed to
# docker-run.
USER rapids:rapids
ENV USER=rapids
WORKDIR /opt/rapids

# Add plugins
COPY --chown=rapids:rapids home/.plugins /opt/rapids/.plugins

ENTRYPOINT ["dockerd-entrypoint.sh", "code-server-entrypoint"]
