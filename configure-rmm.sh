#! /usr/bin/env bash

set -Eeo pipefail

base_image="pauletaylor/rapids-ide:gcc${GCC_VERSION:-9}-cuda${CUDA_VERSION_MAJOR:-11}.${CUDA_VERSION_MINOR:-6}.${CUDA_VERSION_PATCH:-2}-${LINUX_DISTRO:-ubuntu20.04}"

run-in-docker-build --repo=rmm -- /opt/rapids/plugins/rmm/cpp/configure
