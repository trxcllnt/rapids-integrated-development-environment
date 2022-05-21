# syntax=docker/dockerfile:1.3

ARG CUDA_VERSION_MAJOR
ARG CUDA_VERSION_MINOR
ARG CUDA_VERSION_PATCH
ARG LINUX_DISTRO

FROM scratch as srcs-amd64
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz /usr/src/fixuid.tar.gz

FROM scratch as srcs-arm64
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-arm64.tar.gz /usr/src/fixuid.tar.gz

FROM srcs-${TARGETARCH} as srcs

########
# base #
########
FROM nvidia/cuda:${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}.${CUDA_VERSION_PATCH}-base-${LINUX_DISTRO}

ARG TARGETARCH
ARG CUDA_VERSION_MAJOR
ARG CUDA_VERSION_MINOR
ARG CUDA_VERSION_PATCH
ENV CUDA_VERSION_MAJOR=${CUDA_VERSION_MAJOR}
ENV CUDA_VERSION_MINOR=${CUDA_VERSION_MINOR}
ENV CUDA_VERSION_PATCH=${CUDA_VERSION_PATCH}

SHELL ["/bin/bash", "-c"]

USER root
WORKDIR /

RUN --mount=type=secret,id=creds \
    --mount=type=bind,source=build,target=/opt/bin \
    # Mount in the downloaded files
    --mount=type=bind,from=srcs,source=/usr/src,target=/usr/src \
    if [ -f /run/secrets/creds ]; then set -a; . /run/secrets/creds; set +a; fi; \
    /opt/bin/install-dependencies  \
 && /opt/bin/create-non-root-user  \
 && /opt/bin/clean-up-dependencies

ENV LANG=en_US.UTF-8

# Add utility scripts
COPY --chown=root:root usr/local/bin/* /usr/local/bin/

ENV USER=user
# This way, if someone sets $USER, docker-exec will still work as the
# uid will remain the same. note: only relevant if -u isn't passed to
# docker-run.
USER user:user
WORKDIR /home/user

ENV CUDA_HOME=/usr/local/cuda
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CUDA_HOME/lib:$CUDA_HOME/lib64:/usr/local/lib"

ENTRYPOINT ["fixuid-and-set-home", "install-plugins"]

CMD ["/bin/bash", "-l"]
