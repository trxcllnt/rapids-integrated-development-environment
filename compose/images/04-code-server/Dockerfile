# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE
ARG MAMBA_IMAGE
ARG CODE_SERVER_VERSION
ARG CUDA_VERSION_MAJOR
ARG CUDA_VERSION_MINOR
ARG CUDA_VERSION_PATCH
ARG LINUX_DISTRO

FROM ${BASE_IMAGE} as base
FROM ${MAMBA_IMAGE} as mamba
FROM nvidia/cuda:${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}.${CUDA_VERSION_PATCH}-devel-${LINUX_DISTRO} as cuda-devel

FROM base as base-amd64

ONBUILD WORKDIR /usr/local/src
ONBUILD ARG CODE_SERVER_VERSION
ONBUILD ADD https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_amd64.deb code-server.deb

FROM base as base-arm64

ONBUILD WORKDIR /usr/local/src
ONBUILD ARG CODE_SERVER_VERSION
ONBUILD ADD https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_arm64.deb code-server.deb

#########################################
# code-server
#########################################
FROM base-${TARGETARCH}

USER root
WORKDIR /

ARG TARGETARCH
ARG CLANG_FORMAT_VERSION=11

COPY --from=mamba /opt/conda /opt/conda
COPY --from=cuda-devel /usr/local/cuda /usr/local/cuda

ENV PATH="/opt/conda/bin:/usr/local/cuda/bin:$PATH"

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=bind,source=build,target=/opt/bin \
    /opt/bin/install-dependencies  \
 && /opt/bin/clean-up-dependencies

# Set up docker-in-docker
ENV DOCKER_TLS_CERTDIR=/certs
RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client

COPY --from=docker:20-dind /usr/local/bin/* /usr/local/bin/

VOLUME /var/lib/docker

# Copy in VSCode extensions
COPY extensions/augustocdias.tasks-shell-input-1.7.0.vsix /usr/local/src/tasks-shell-input.vsix
COPY extensions/ms-vscode.cpptools-1.9.7@linux-x64.vsix /usr/local/src/ms-vscode.cpptools.vsix
COPY extensions/NVIDIA.nsight-vscode-edition-2021.1.30130113.vsix /usr/local/src/nsight-vscode.vsix

# Add utility scripts
COPY --chown=root:root usr/local/bin /usr/local/bin/
COPY --chown=root:root opt/builder /opt/builder/

# Add configuration
COPY --chown=root:root etc/docker /etc/docker/
COPY --chown=user:user home/user /home/user/

ARG LINUX_DISTRO
ARG GCC_VERSION
ARG MAMBA_VERSION
ARG PYTHON_VERSION
ARG CUDA_VERSION_MAJOR
ARG CUDA_VERSION_MINOR
ARG CUDA_VERSION_PATCH

ENV LINUX_DISTRO=$LINUX_DISTRO
ENV GCC_VERSION=$GCC_VERSION
ENV MAMBA_VERSION=$MAMBA_VERSION
ENV PYTHON_VERSION=$PYTHON_VERSION
ENV CUDA_VERSION_MAJOR=$CUDA_VERSION_MAJOR
ENV CUDA_VERSION_MINOR=$CUDA_VERSION_MINOR
ENV CUDA_VERSION_PATCH=$CUDA_VERSION_PATCH
ENV CONDA_OVERRIDE_CUDA=${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}

EXPOSE 8080

USER user:user
WORKDIR /home/user

ENTRYPOINT ["dockerd-entrypoint.sh", "fixuid-and-set-home", "install-plugins", "code-server-entrypoint"]
