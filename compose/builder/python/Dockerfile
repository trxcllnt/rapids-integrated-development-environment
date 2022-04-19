# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE=pauletaylor/rapids-ide:cpp-builder-cuda11.6.0-ubuntu20.04

FROM ${BASE_IMAGE} as base

FROM base as base-amd64

# ONBUILD WORKDIR /usr/local/src
# ONBUILD ADD https://github.com/coder/code-server/releases/download/v4.3.0/code-server_4.3.0_amd64.deb code-server.deb

FROM base as base-arm64

# ONBUILD WORKDIR /usr/local/src
# ONBUILD ADD https://github.com/coder/code-server/releases/download/v4.3.0/code-server_4.3.0_arm64.deb code-server.deb

#########################################
# python-builder
#########################################
FROM base-${TARGETARCH}

USER root

WORKDIR /

ARG TARGETARCH
ARG PYTHON_VERSION=3.9

SHELL ["/bin/bash", "-c"]

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=bind,source=build,target=/opt/bin \
    export DEBIAN_FRONTEND=noninteractive \
 && export PYTHON_VERSION=${PYTHON_VERSION} \
 && PATH="$PATH:/opt/bin" \
 && install-dependencies  \
 && clean-up-dependencies

# Add utility scripts
COPY --chown=root:root usr/local/bin/* /usr/local/bin/

USER coder:coder
WORKDIR /opt/rapids

# Add plugins
COPY --chown=coder:coder plugins /opt/rapids/.plugins

ENTRYPOINT ["fixuid", "-q", "python-builder-entrypoint"]

CMD ["/bin/bash", "-l"]
