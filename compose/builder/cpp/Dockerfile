# syntax=docker/dockerfile:1.3

ARG BASE_IMAGE=nvidia/cuda:11.6.2-devel-ubuntu20.04
ARG GDAL_IMAGE=osgeo/gdal:ubuntu-full-3.3.1

FROM ${BASE_IMAGE} as base
FROM ${GDAL_IMAGE} as gdal

FROM base as base-amd64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz fixuid.tar.gz
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-x86_64-unknown-linux-musl.tar.gz  sccache.tar.gz

FROM base as base-arm64

ONBUILD WORKDIR /usr/local/src
ONBUILD ADD https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-arm64.tar.gz fixuid.tar.gz
ONBUILD ADD https://github.com/mozilla/sccache/releases/download/v0.2.15/sccache-v0.2.15-aarch64-unknown-linux-musl.tar.gz sccache.tar.gz

#########################################
# cpp-builder
#########################################
FROM base-${TARGETARCH}

# Install gdal for cuspatial
COPY --from=gdal /usr/lib/*gdal* /usr/lib/
COPY --from=gdal /usr/lib/pkgconfig/*gdal* /usr/lib/pkgconfig/
COPY --from=gdal /usr/include/*cpl*.h /usr/include/
COPY --from=gdal /usr/include/*gnm*.h /usr/include/
COPY --from=gdal /usr/include/*ogr*.h /usr/include/
COPY --from=gdal /usr/include/*gdal*.h /usr/include/
COPY --from=gdal /usr/include/*dataset*.h /usr/include/
COPY --from=gdal /usr/include/tiledb /usr/include/tiledb
COPY --from=gdal /usr/include/libkea /usr/include/libkea
COPY --from=gdal /usr/include/bsoncxx /usr/include/bsoncxx
COPY --from=gdal /usr/include/mongocxx /usr/include/mongocxx
COPY --from=gdal /usr/include/libbson-1.0 /usr/include/libbson-1.0
COPY --from=gdal /usr/include/libmongoc-1.0 /usr/include/libmongoc-1.0
COPY --from=gdal /usr/local/include/geodesic.h /usr/local/include/geodesic.h

WORKDIR /

ARG TARGETARCH
ARG GCC_VERSION=9
ARG UXC_VERSION=1.11

SHELL ["/bin/bash", "-c"]

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=cache,target=/usr/local/src/ucx \
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

ENV CC="gcc"
ENV CXX="g++"
ENV CUDA_HOME="/usr/local/cuda"
ENV PATH="$PATH:/opt/rapids/.bin"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$CUDA_HOME/lib64:/usr/local/lib"

ENTRYPOINT ["fixuid", "-q", "cpp-builder-entrypoint"]

CMD ["/bin/bash", "-l"]
