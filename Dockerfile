# 1. Define the base image
FROM ubuntu:22.04 AS base

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Define whether the environment is inside China and GitHub URL
ENV IS_CHINA_ENV=False
ENV GITHUB=github.com

# Set compilers for C, C++, and Fortran
ENV CC=gcc
ENV CXX=g++
ENV FC=gfortran

# Define repository URL for dependencies
ENV resturl=https://${GITHUB}/igor-1982

# Set the working directory for subsequent commands
WORKDIR /opt

# Configure system package sources for faster access if inside China
RUN if [ "$IS_CHINA_ENV" = "True" ]; then \
        sed -i -e 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' \
               -e 's|http://security.ubuntu.com/ubuntu/|http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' /etc/apt/sources.list; \
    fi

# Install essential system packages and tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    gcc \
    g++ \
    gfortran \
    libblas-dev \
    liblapack-dev \
    iputils-ping \
    openssl \
    libssl-dev \
    openssh-client \
    wget \
    curl \
    git \
    unzip \
    vim \
    cmake \
    autoconf \
    automake \
    libtool \
    python3 \
    pkg-config \
    && apt-get autoremove --purge -y && \
    apt-get autoclean -y && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

RUN git config --global http.postBuffer 524288000 \
    && git config --global http.lowSpeedLimit 0 \
    && git config --global http.lowSpeedTime 999999

# Configure pip index URL for China mirrors if applicable
RUN if [ "$IS_CHINA_ENV" = "True" ]; then \
        export PIP_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple; \
    fi

# Configure Rust environment variables
ENV CARGO_HOME=/opt/.cargo
ENV RUSTUP_HOME=/opt/.rustup
ENV PATH="/opt/.cargo/bin:$PATH"

# Install Rust programming language
RUN if [ "$IS_CHINA_ENV" = "True" ]; then \
        export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static; \
        export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup; \
    fi && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y

# Configure Cargo to use China mirrors
RUN if [ "$IS_CHINA_ENV" = "True" ]; then \
    mkdir -p /opt/.cargo && \
    echo "\
[source.crates-io] \n\
replace-with = 'ustc' \n\
[source.ustc] \n\
registry = 'https://mirrors.ustc.edu.cn/crates.io-index' \n\
[source.tuna] \n\
registry = 'https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git' \n\
" > /opt/.cargo/config.toml; \
    fi

# Verify Rust and Cargo installation
RUN rustc --version && cargo --version

# Clone the workspace repository and configure environment paths
RUN git clone --depth=1 ${resturl}/rest_workspace.git \
    && cd rest_workspace \
    && git fetch --depth=1 origin 633e4151499fdfa6b301fe8741204d5dc2892494 \
    && git checkout 633e4151499fdfa6b301fe8741204d5dc2892494 \
    && mkdir -p lib include

ENV REST_EXT_DIR="/opt/rest_workspace/lib" 
ENV REST_EXT_INC="/opt/rest_workspace/include"
ENV REST_BLAS_DIR="/opt/rest_workspace/lib" 

# Prepare prerequisites in a separate layer
FROM base AS dependencies

# Build and install OpenBLAS library
# RUN git clone https://${GITHUB}/OpenMathLib/OpenBLAS.git -b v0.3.28 OpenBLAS \
RUN wget https://${GITHUB}/OpenMathLib/OpenBLAS/archive/refs/tags/v0.3.28.tar.gz \
    && tar xf v0.3.28.tar.gz && rm v0.3.28.tar.gz && mv OpenBLAS-0.3.28 OpenBLAS \
    && cd OpenBLAS \
    && make DYNAMIC_ARCH=1 TARGET=HASWELL \
    && cp libopenblas.so* $REST_EXT_DIR/

# Build and install libcint library
# RUN git clone https://${GITHUB}/sunqm/libcint.git -b v6.1.2 libcint \
RUN wget https://${GITHUB}/sunqm/libcint/archive/refs/tags/v6.1.2.tar.gz \
    && tar xf v6.1.2.tar.gz && rm v6.1.2.tar.gz && mv libcint-6.1.2 libcint \
    && cd libcint \
    && mkdir build && cd build \
    && cmake -DWITH_RANGE_COULOMB=1 .. \
    && make -j32 \
    && cp libcint.so* $REST_EXT_DIR/

# Build and install libxc library
RUN wget https://gitlab.com/libxc/libxc/-/archive/7.0.0/libxc-7.0.0.tar.gz \
    && tar xf libxc-* && rm libxc-*.tar.gz \
    && cd libxc-* \
    && autoreconf -i \
    && ./configure --prefix=$(pwd) --enable-shared \
    && make -j32 && make install \
    && cp lib/libxc.so* $REST_EXT_DIR/ \
    && cp lib/libxc.a  $REST_EXT_DIR/

# Build and install HDF5 library
RUN wget https://${GITHUB}/HDFGroup/hdf5/archive/refs/tags/hdf5-1_8_23.tar.gz \
    && tar xf hdf5-*.tar.gz && rm hdf5-*.tar.gz \
    && cd hdf5-* \
    && ./configure --prefix=/opt/hdf5 \
    && make -j32 && make -j32 install \
    && cd /opt/hdf5 \
    && cp lib/libhdf5.so* $REST_EXT_DIR/ \
    && cp include/* $REST_EXT_INC/

# Build REST-specific dependencies like librest2fch and DFT libraries
# Install librest2fch for converting quantum chemistry formats
RUN git clone --depth=1 https://gitlab.com/jeanwsr/MOKIT -b for-rest \
    && cd MOKIT/src \
    && git fetch --depth=1 origin 225f55756784a0539f7ef34f97221927df84136d \
    && git checkout 225f55756784a0539f7ef34f97221927df84136d \
    && make rest2fch -f Makefile.gnu_openblas \
    && cp ../mokit/lib/librest2fch.so $REST_EXT_DIR/

# Install ninja
RUN wget https://${GITHUB}/ninja-build/ninja/releases/download/v1.12.1/ninja-linux.zip \
    && unzip ninja-linux.zip \
    && mv ninja /usr/local/bin/ \
    && rm ninja-linux.zip 

# Install dftd3 (Dispersion Correction)
RUN git clone --depth=1 https://${GITHUB}/dftd3/simple-dftd3.git -b v1.2.1 \
    && cd simple-dftd3 \
    && cmake -B build -G Ninja -DBUILD_SHARED_LIBS=1 \
    && cmake --build build \
    && cp build/libs-dftd3.so.* $REST_EXT_DIR/ \
    && mkdir -p $REST_EXT_INC/dftd3 \
    && find build -name *.mod | xargs -I {} cp {} $REST_EXT_INC/dftd3 \
    && cd $REST_EXT_DIR && ln -s libs-dftd3.so.1 libs-dftd3.so

# Build dftd4 for advanced dispersion correction
RUN git clone --depth=1 https://${GITHUB}/dftd4/dftd4.git -b v3.7.0 \
    && cd dftd4 \
    && cmake -B build -G Ninja -DBUILD_SHARED_LIBS=1 \
    && cmake --build build \
    && mkdir -p $REST_EXT_INC/dftd4 \
    && cp build/libdftd4.so.* $REST_EXT_DIR/ \
    && cp build/_deps/multicharge-build/libmulticharge.so.* $REST_EXT_DIR/ \
    && cp build/_deps/mctc-lib-build/libmctc-lib.so.* $REST_EXT_DIR/ \
    && find build -name *.mod | xargs -I {} cp {} $REST_EXT_INC/dftd4 \
    && cd $REST_EXT_DIR && ln -s libdftd4.so.3 libdftd4.so

# 3. Finalize the REST installation in a new stage
FROM base AS rest
# Copy built dependencies from the previous stage
COPY --from=dependencies $REST_EXT_DIR/ $REST_EXT_DIR/
COPY --from=dependencies $REST_EXT_INC/ $REST_EXT_INC/

# Clone and build REST software components
RUN cd rest_workspace\
    && git clone --depth=1 ${resturl}/rest.git rest \
    && cd rest \
    && git fetch --depth=1 origin a486f59bbd8b32af007d6e2bf33cd0d7b04f15c3 \
    && git checkout a486f59bbd8b32af007d6e2bf33cd0d7b04f15c3
# This is a bug in rest for processing 0 occupied electron in spin channel
RUN echo "\
2067,2068c2067,2072\n\
<                     .map(|(i,occ)| i).max().unwrap();\n\
<                 let mut occ_s = occ.get(i_spin).unwrap()[0..homo_s+1].iter().map(|occ| occ.sqrt()).collect::<Vec<f64>>();\n\
---\n\
>                     .map(|(i,occ)| i).max();\n\
>                 let mut occ_s = if let Some(homo_s) = homo_s {\n\
>                     occ.get(i_spin).unwrap()[0..homo_s+1].iter().map(|occ| occ.sqrt()).collect::<Vec<f64>>()\n\
>                 } else {\n\
>                     vec![]\n\
>                 };\n\
" > correction.patch \
&& patch rest_workspace/rest/src/dft/mod.rs < correction.patch \
&& rm correction.patch

RUN cd rest_workspace\
    && git clone --depth=1 ${resturl}/rest_tensors.git rest_tensors \
    && cd rest_tensors \
    && git fetch --depth=1 origin 69862164277843a3c3faccb596f62840e60ad6ae \
    && git checkout 69862164277843a3c3faccb596f62840e60ad6ae
RUN cd rest_workspace\
    && git clone --depth=1 ${resturl}/rest_libcint.git rest_libcint \
    && cd rest_libcint \
    && git fetch --depth=1 origin 017c38b248077eb6d24413166a126e0fcfdbec9d \
    && git checkout 017c38b248077eb6d24413166a126e0fcfdbec9d
RUN cd rest_workspace\
    && git clone --depth=1 ${resturl}/rest_regression.git rest_regression \
    && cd rest_regression \
    && git fetch --depth=1 origin 9fc755ca0e243ec523ac6a1c3aa78d05572010bf \
    && git checkout 9fc755ca0e243ec523ac6a1c3aa78d05572010bf

# # Build and verify REST
RUN cd rest_workspace \
    && ./Config -r github -f $FC -e

ENV REST_FORTRAN_COMPILER="gfortran"                
ENV REST_HOME="/opt/rest_workspace"                   
ENV REST_CINT_DIR="$REST_HOME/lib"        
ENV LD_LIBRARY_PATH="$REST_EXT_DIR:$LD_LIBRARY_PATH"
ENV HDF5_DIR="$REST_HOME"
ENV REST_HDF5_DIR="$REST_HOME"
ENV REST_XC_DIR="$REST_HOME"

RUN cd rest_workspace \
    && cargo fetch  

RUN cd rest_workspace \
    && cargo build --release 

RUN cd rest_workspace \
    && test -f $REST_HOME/target/release/rest \
    && test -f $REST_HOME/target/release/rest_regression

ENV PATH="${REST_HOME}/target/release:${PATH}" 

RUN cd rest_workspace \
    && $REST_HOME/target/release/rest_regression -p $REST_HOME/target/release/rest | tee $REST_HOME/target/rest_regression.log
RUN cd rest_workspace \
    && if grep -q "All regression tasks passed" "$REST_HOME/target/rest_regression.log"; then \
            echo "Regression check passed"; \
       else \
            (echo "Regression check failed" && exit 1); \
       fi

