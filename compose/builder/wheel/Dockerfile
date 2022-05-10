# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE=pauletaylor/rapids-ide:cpp-builder-cuda11.6.2-ubuntu20.04

FROM ${BASE_IMAGE} as base

FROM base as base-amd64

# ONBUILD WORKDIR /usr/local/src
# ONBUILD ADD https://github.com/coder/code-server/releases/download/v4.4.0/code-server_4.4.0_amd64.deb code-server.deb

FROM base as base-arm64

# ONBUILD WORKDIR /usr/local/src
# ONBUILD ADD https://github.com/coder/code-server/releases/download/v4.4.0/code-server_4.4.0_arm64.deb code-server.deb

#########################################
# wheel-builder
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
COPY --chown=root:root usr/local/bin /usr/local/bin
COPY --chown=root:root --from=base /usr/local/bin/cpp-builder-entrypoint /usr/local/bin/

USER coder:coder
WORKDIR /opt/rapids

# Add plugins
COPY --chown=coder:coder plugins /opt/rapids/.plugins
COPY --chown=coder:coder --from=base /opt/rapids/.plugins/util/* /opt/rapids/.plugins/util/

ENV PYTHONDONTWRITEBYTECODE=1
ENV PATH="$PATH:/opt/rapids/.local/bin"

ENTRYPOINT ["fixuid", "-q", "wheel-builder-entrypoint"]

CMD ["/bin/bash", "-l"]
