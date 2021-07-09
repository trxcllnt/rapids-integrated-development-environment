ARG CUDA_VERSION=11.2.2
ARG LINUX_VERSION=ubuntu20.04
ARG BASE_IMAGE=nvidia/cuda:${CUDA_VERSION:-11.2.2}-devel-${LINUX_VERSION:-ubuntu20.04}

FROM ${BASE_IMAGE}

ARG GCC_VERSION=9
ARG SCCACHE_VERSION=0.2.15

RUN export DEBIAN_FRONTEND=noninteractive \
 && apt update -y \
 && apt install --no-install-recommends -y gpg wget software-properties-common \
 && add-apt-repository --no-update -y ppa:git-core/ppa \
 && add-apt-repository --no-update -y ppa:ubuntu-toolchain-r/test \
 # Install kitware CMake apt sources
 && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
  | gpg --dearmor - \
  | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null \
 && bash -c 'echo -e "\
deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main\n\
" | tee /etc/apt/sources.list.d/kitware.list >/dev/null' \
 && apt update -y \
 && apt install --no-install-recommends -y \
    gcc-${GCC_VERSION} g++-${GCC_VERSION} \
    git ninja-build \
    # CMake
    cmake curl libssl-dev libcurl4-openssl-dev zlib1g-dev \
    # FAISS (cuML/cuGraph) dependencies
    libblas-dev liblapack-dev \
    # cuSpatial dependencies
    libgdal-dev \
 # Remove any existing gcc and g++ alternatives
 && update-alternatives --remove-all cc  >/dev/null 2>&1 || true \
 && update-alternatives --remove-all c++ >/dev/null 2>&1 || true \
 && update-alternatives --remove-all gcc >/dev/null 2>&1 || true \
 && update-alternatives --remove-all g++ >/dev/null 2>&1 || true \
 && update-alternatives --remove-all gcov >/dev/null 2>&1 || true \
 && update-alternatives \
    --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 100 \
    --slave /usr/bin/cc cc /usr/bin/gcc-${GCC_VERSION} \
    --slave /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} \
    --slave /usr/bin/c++ c++ /usr/bin/g++-${GCC_VERSION} \
    --slave /usr/bin/gcov gcov /usr/bin/gcov-${GCC_VERSION} \
 # Set gcc-${GCC_VERSION} as the default gcc
 && update-alternatives --set gcc /usr/bin/gcc-${GCC_VERSION} \
 # Install sccache
 && curl -o /tmp/sccache.tar.gz \
         -L "https://github.com/mozilla/sccache/releases/download/v$SCCACHE_VERSION/sccache-v$SCCACHE_VERSION-$(uname -m)-unknown-linux-musl.tar.gz" \
 && tar -C /tmp -xvf /tmp/sccache.tar.gz \
 && mv "/tmp/sccache-v$SCCACHE_VERSION-$(uname -m)-unknown-linux-musl/sccache" /bin/sccache \
 && chmod +x /bin/sccache \
 && cd / \
 # Clean up
 && apt autoremove -y \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV CUDA_HOME="/usr/local/cuda"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib:/usr/local/lib:/usr/local/cuda/lib:/usr/local/cuda/lib64"

ARG SCCACHE_REGION
ARG SCCACHE_BUCKET
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG SCCACHE_CACHE_SIZE=100G
ARG SCCACHE_IDLE_TIMEOUT=32768

ARG PARALLEL_LEVEL=4
ARG CMAKE_CUDA_ARCHITECTURES=ALL
ARG RAPIDS_CMAKE_COMMON_ARGS="\
-D BUILD_TESTS=ON \
-D BUILD_BENCHMARKS=ON \
-D CMAKE_BUILD_TYPE=Release \
-D CMAKE_INSTALL_PREFIX=/usr/local \
-D CMAKE_C_COMPILER_LAUNCHER=/usr/bin/sccache \
-D CMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/sccache \
-D CMAKE_CUDA_COMPILER_LAUNCHER=/usr/bin/sccache \
-D CMAKE_CUDA_ARCHITECTURES=$CMAKE_CUDA_ARCHITECTURES"

ARG RAPIDS_VERSION=21.08

ARG RMM_BRANCH=branch-21.08
ARG RMM_GIT_REPO="https://github.com/rapidsai/rmm.git"

ARG RAFT_BRANCH=branch-21.08
ARG RAFT_GIT_REPO="https://github.com/rapidsai/raft.git"

ARG CUDF_BRANCH=branch-21.08
ARG CUDF_GIT_REPO="https://github.com/rapidsai/cudf.git"

ARG CUML_BRANCH=branch-21.08
ARG CUML_GIT_REPO="https://github.com/rapidsai/cuml.git"

ARG CUGRAPH_BRANCH=branch-21.08
ARG CUGRAPH_GIT_REPO="https://github.com/rapidsai/cugraph.git"

ARG CUSPATIAL_BRANCH=branch-21.08
ARG CUSPATIAL_GIT_REPO="https://github.com/rapidsai/cuspatial.git"

# Step 1. Build the RAPIDS C++ projects against each other (no install)

RUN export SCCACHE_REGION="${SCCACHE_REGION}" \
 && export SCCACHE_BUCKET="${SCCACHE_BUCKET}" \
 && export SCCACHE_CACHE_SIZE="${SCCACHE_CACHE_SIZE}" \
 && export SCCACHE_IDLE_TIMEOUT="${SCCACHE_IDLE_TIMEOUT}" \
 && export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
 && export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
 \
 # Build librmm from source
 && git clone --depth 1 --branch "${RMM_BRANCH}" "${RMM_GIT_REPO}" /opt/rapids/rmm \
 && cmake -GNinja \
          -S /opt/rapids/rmm \
          -B /opt/rapids/rmm/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D DISABLE_DEPRECATION_WARNING=ON \
 && cmake --build /opt/rapids/rmm/build -j${PARALLEL_LEVEL} -v \
 \
 # Build libraft from source
 && git clone --depth 1 --branch "${RAFT_BRANCH}" "${RAFT_GIT_REPO}" /opt/rapids/raft \
 && cmake -GNinja \
          -S /opt/rapids/raft/cpp \
          -B /opt/rapids/raft/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D BUILD_TESTS=OFF \
          -D BUILD_BENCHMARKS=OFF \
          -D DISABLE_DEPRECATION_WARNINGS=ON \
 && cmake --build /opt/rapids/raft/cpp/build -j${PARALLEL_LEVEL} -v \
 \
 # Build libcuml from source
 && git clone --depth 1 --branch "${CUML_BRANCH}" "${CUML_GIT_REPO}" /opt/rapids/cuml \
 && cmake -GNinja \
          -S /opt/rapids/cuml/cpp \
          -B /opt/rapids/cuml/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D rmm_ROOT=/opt/rapids/rmm/build \
          -D raft_ROOT=/opt/rapids/raft/cpp/build \
          -D BUILD_CUML_BENCH=ON \
          -D BUILD_CUML_EXAMPLES=OFF \
          -D BUILD_CUML_MG_TESTS=OFF \
          -D BUILD_CUML_MPI_COMMS=OFF \
          -D BUILD_CUML_PRIMS_BENCH=OFF \
          -D BUILD_CUML_STD_COMMS=OFF \
          -D BUILD_CUML_TESTS=ON \
          -D BUILD_PRIMS_TESTS=OFF \
          -D DETECT_CONDA_ENV=OFF \
          -D DISABLE_DEPRECATION_WARNINGS=ON \
          -D DISABLE_OPENMP=OFF \
          -D ENABLE_CUMLPRIMS_MG=OFF \
          -D SINGLEGPU=ON \
 && cmake --build /opt/rapids/cuml/cpp/build -j${PARALLEL_LEVEL} -v || true \
 \
 # Build libcugraph from source
 && git clone --depth 1 --branch "${CUGRAPH_BRANCH}" "${CUGRAPH_GIT_REPO}" /opt/rapids/cugraph \
 && cmake -GNinja \
          -S /opt/rapids/cugraph/cpp \
          -B /opt/rapids/cugraph/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D rmm_ROOT=/opt/rapids/rmm/build \
          -D raft_ROOT=/opt/rapids/raft/cpp/build \
 && cmake --build /opt/rapids/cugraph/cpp/build -j${PARALLEL_LEVEL} -v || true \
 \
 # Build libcudf from source
 && git clone --depth 1 --branch "${CUDF_BRANCH}" "${CUDF_GIT_REPO}" /opt/rapids/cudf \
 && cmake -GNinja \
          -S /opt/rapids/cudf/cpp \
          -B /opt/rapids/cudf/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D CUDF_ENABLE_ARROW_S3=OFF \
          -D DISABLE_DEPRECATION_WARNING=ON \
          -D rmm_ROOT=/opt/rapids/rmm/build \
 && cmake --build /opt/rapids/cudf/cpp/build -j${PARALLEL_LEVEL} -v \
 \
 # Build libcuspatial from source
 && git clone --depth 1 --branch "${CUSPATIAL_BRANCH}" "${CUSPATIAL_GIT_REPO}" /opt/rapids/cuspatial \
 && cmake -GNinja \
          -S /opt/rapids/cuspatial/cpp \
          -B /opt/rapids/cuspatial/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D DISABLE_DEPRECATION_WARNING=ON \
          -D rmm_ROOT=/opt/rapids/rmm/build \
          -D cudf_ROOT=/opt/rapids/cudf/cpp/build \
 && cmake --build /opt/rapids/cuspatial/cpp/build -j${PARALLEL_LEVEL} -v

# Step 2. Build and install the RAPIDS C++ projects

RUN rm -rf /opt/rapids/* \
 && export SCCACHE_REGION="${SCCACHE_REGION}" \
 && export SCCACHE_BUCKET="${SCCACHE_BUCKET}" \
 && export SCCACHE_IDLE_TIMEOUT="${SCCACHE_IDLE_TIMEOUT}" \
 && export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
 && export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
 \
 # Build and install librmm
 && git clone --depth 1 --branch "${RMM_BRANCH}" "${RMM_GIT_REPO}" /opt/rapids/rmm \
 && cmake -GNinja \
          -S /opt/rapids/rmm \
          -B /opt/rapids/rmm/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D DISABLE_DEPRECATION_WARNING=ON \
 && cmake --build /opt/rapids/rmm/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install libraft
 && git clone --depth 1 --branch "${RAFT_BRANCH}" "${RAFT_GIT_REPO}" /opt/rapids/raft \
 && cmake -GNinja \
          -S /opt/rapids/raft/cpp \
          -B /opt/rapids/raft/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D BUILD_TESTS=OFF \
          -D BUILD_BENCHMARKS=OFF \
          -D DISABLE_DEPRECATION_WARNINGS=ON \
 && cmake --build /opt/rapids/raft/cpp/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install libcuml
 && git clone --depth 1 --branch "${CUML_BRANCH}" "${CUML_GIT_REPO}" /opt/rapids/cuml \
 && cmake -GNinja \
          -S /opt/rapids/cuml/cpp \
          -B /opt/rapids/cuml/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D BUILD_CUML_BENCH=ON \
          -D BUILD_CUML_EXAMPLES=OFF \
          -D BUILD_CUML_MG_TESTS=OFF \
          -D BUILD_CUML_MPI_COMMS=OFF \
          -D BUILD_CUML_PRIMS_BENCH=OFF \
          -D BUILD_CUML_STD_COMMS=OFF \
          -D BUILD_CUML_TESTS=ON \
          -D BUILD_PRIMS_TESTS=OFF \
          -D DETECT_CONDA_ENV=OFF \
          -D DISABLE_OPENMP=OFF \
          -D DISABLE_DEPRECATION_WARNINGS=ON \
          -D ENABLE_CUMLPRIMS_MG=OFF \
          -D SINGLEGPU=ON \
 && cmake --build /opt/rapids/cuml/cpp/build -j${PARALLEL_LEVEL} -v --target install || true \
 \
 # Build and install libcugraph
 && git clone --depth 1 --branch "${CUGRAPH_BRANCH}" "${CUGRAPH_GIT_REPO}" /opt/rapids/cugraph \
 && cmake -GNinja \
          -S /opt/rapids/cugraph/cpp \
          -B /opt/rapids/cugraph/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
 && cmake --build /opt/rapids/cugraph/cpp/build -j${PARALLEL_LEVEL} -v --target install || true \
 \
 # Build and install libcudf
 && git clone --depth 1 --branch "${CUDF_BRANCH}" "${CUDF_GIT_REPO}" /opt/rapids/cudf \
 && cmake -GNinja \
          -S /opt/rapids/cudf/cpp \
          -B /opt/rapids/cudf/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D CUDF_ENABLE_ARROW_S3=OFF \
          -D DISABLE_DEPRECATION_WARNING=ON \
 && cmake --build /opt/rapids/cudf/cpp/build -j${PARALLEL_LEVEL} -v --target install \
 \
 # Build and install libcuspatial
 && git clone --depth 1 --branch "${CUSPATIAL_BRANCH}" "${CUSPATIAL_GIT_REPO}" /opt/rapids/cuspatial \
 && cmake -GNinja \
          -S /opt/rapids/cuspatial/cpp \
          -B /opt/rapids/cuspatial/cpp/build \
          ${RAPIDS_CMAKE_COMMON_ARGS} \
          -D DISABLE_DEPRECATION_WARNING=ON \
 && cmake --build /opt/rapids/cuspatial/cpp/build -j${PARALLEL_LEVEL} -v --target install || true
