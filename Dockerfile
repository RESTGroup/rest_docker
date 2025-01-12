# Define the build argument
ARG CHINA=False

# 1. Define the base image
FROM ubuntu:22.04 AS base

# Define the build argument for conditional logic
ARG CHINA

# Use shell logic to set the ENV variable based on the build argument
RUN if [ "$CHINA" = "True" ]; then \
        echo "Setting IS_CHINA_ENV=True"; \
        echo "\
export IS_CHINA_ENV=True \n\
export RootUrle=https://gitee.com/restgroup \n\
export RootUrl=\${RootUrle} \n" \
>> /tmp/bashrc; \
    else \
        echo "Setting IS_CHINA_ENV=False"; \
        echo "\
export IS_CHINA_ENV=False \n\
export RootUrle=https://gitee.com/restgroup \n\
export RootUrl=https://github.com/RESTGroup \n" \
>> /tmp/bashrc; \
    fi

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Set compilers for C, C++, and Fortran
ENV CC=gcc
ENV CXX=g++
ENV FC=gfortran

# Set the working directory for subsequent commands
WORKDIR /opt

# Configure system package sources for faster access if inside China
RUN . /tmp/bashrc \
    && if [ "$IS_CHINA_ENV" = "True" ]; then \
        sed -i -e 's|http://archive.ubuntu.com/ubuntu/|http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' \
               -e 's|http://security.ubuntu.com/ubuntu/|http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' /etc/apt/sources.list; \
    fi

# Install essential system packages and tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
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
    openmpi-bin \
    openmpi-common \
    libopenmpi-dev \    
    libclang-dev \
    clang \
    && apt-get autoremove --purge -y && \
    apt-get autoclean -y && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

RUN git config --global http.postBuffer 524288000 \
    && git config --global http.lowSpeedLimit 0 \
    && git config --global http.lowSpeedTime 999999

# Configure pip index URL for China mirrors if applicable
RUN . /tmp/bashrc \
    && if [ "$IS_CHINA_ENV" = "True" ]; then \
        export PIP_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple; \
    fi

# Configure Rust environment variables
ENV CARGO_HOME=/opt/.cargo
ENV RUSTUP_HOME=/opt/.rustup
ENV PATH="/opt/.cargo/bin:$PATH"

# Install Rust programming language
COPY src/rustup_20250112.sh /opt/rustup.sh
RUN . /tmp/bashrc \
    && if [ "$IS_CHINA_ENV" = "True" ]; then \
        export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static; \
        export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup; \
    fi && \
    sh /opt/rustup.sh -y

# Configure Cargo to use China mirrors
RUN . /tmp/bashrc \
    && if [ "$IS_CHINA_ENV" = "True" ]; then \
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
RUN . /tmp/bashrc \
    && git clone --depth=1 ${RootUrl}/rest_workspace.git \
    && cd rest_workspace \
    && git fetch --depth=1 origin 633e4151499fdfa6b301fe8741204d5dc2892494 \
    && git checkout 633e4151499fdfa6b301fe8741204d5dc2892494 \
    && mkdir -p lib include

ENV REST_EXT_DIR="/opt/rest_workspace/lib" 
ENV REST_EXT_INC="/opt/rest_workspace/include"
ENV REST_BLAS_DIR="/opt/rest_workspace/lib" 

# =======================================================================
# Prepare prerequisites in a separate layer
FROM base AS dependencies

# set repository url enviroment
RUN echo "\
export OMP_NUM_THREADS=4 \n\
export url_blas=\${RootUrl}/OpenBLAS.git \n\
export url_libcint=\${RootUrl}/libcint.git \n\
export url_libcint=\${RootUrl}/libcint.git \n\
export url_hdf5=\${RootUrl}/hdf5.git \n\
export url_ninja=\${RootUrl}/ninja.git \n\
export url_dftd3=\${RootUrl}/simple-dftd3.git \n\
export url_dftd4=\${RootUrl}/dftd4.git \n\
" >> /tmp/bashrc

RUN . /tmp/bashrc \
    && if [ "$IS_CHINA_ENV" = "True" ]; then \
        echo "\
export url_libxc=\${RootUrle}/libxc.git \n \
export url_MOKIT=\${RootUrle}/MOKIT.git \n" \
        >> /tmp/bashrc; \
    else \
        echo "\
export url_libxc=https://gitlab.com/libxc/libxc.git \n\
export url_MOKIT=https://gitlab.com/jeanwsr/MOKIT.git \n" \
        >> /tmp/bashrc; \
    fi

# Build and install OpenBLAS library
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_blas} -b v0.3.28 OpenBLAS \
    && cd OpenBLAS \
    && make DYNAMIC_ARCH=1 TARGET=HASWELL USE_OPENMP=1 \
    && cp libopenblas.so* $REST_EXT_DIR/

# Build and install libcint library
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_libcint} -b v6.1.2 libcint \
    && cd libcint \
    && mkdir build && cd build \
    && cmake -DWITH_RANGE_COULOMB=1 .. \
    && make -j32 \
    && cp libcint.so* $REST_EXT_DIR/

# Build and install libxc library
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_libxc} -b 7.0.0 libxc \
    && cd libxc \
    && autoreconf -i \
    && ./configure --prefix=$(pwd) --enable-shared \
    && make -j32 && make install \
    && cp lib/libxc.so* $REST_EXT_DIR/ \
    && cp lib/libxc.a  $REST_EXT_DIR/


# Build and install HDF5 library
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_hdf5} -b hdf5_1.14.5 hdf5_src \
    && cd hdf5_src \
    && ./configure --prefix=/opt/hdf5 \
    && make -j32 && make -j32 install \
    && cd /opt/hdf5 \
    && cp lib/libhdf5.so* $REST_EXT_DIR/ \
    && cp include/* $REST_EXT_INC/

# Build REST-specific dependencies like librest2fch and DFT libraries
# Install librest2fch for converting quantum chemistry formats
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_MOKIT} -b for-rest MOKIT \
    && cd MOKIT/src \
    && git fetch --depth=1 origin 225f55756784a0539f7ef34f97221927df84136d \
    && git checkout 225f55756784a0539f7ef34f97221927df84136d \
    && make rest2fch -f Makefile.gnu_openblas \
    && cp ../mokit/lib/librest2fch.so $REST_EXT_DIR/

# Install ninja
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_ninja} -b v1.12.1 ninja \
    && cd ninja \
    && cmake -Bbuild-cmake \
    && cmake --build build-cmake \
    && mv build-cmake/ninja /usr/local/bin/ 

# Install dftd3 (Dispersion Correction)
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_dftd3} -b v1.2.1 \
    && cd simple-dftd3 \
    && cmake -B build -G Ninja -DBUILD_SHARED_LIBS=1 \
    && cmake --build build \
    && cp build/libs-dftd3.so.* $REST_EXT_DIR/ \
    && mkdir -p $REST_EXT_INC/dftd3 \
    && find build -name *.mod | xargs -I {} cp {} $REST_EXT_INC/dftd3 \
    && cd $REST_EXT_DIR && ln -s libs-dftd3.so.1 libs-dftd3.so

# Build dftd4 for advanced dispersion correction
RUN . /tmp/bashrc \
    && git clone --depth=1 ${url_dftd4} -b v3.7.0 \
    && cd dftd4 \
    && cmake -B build -G Ninja -DBUILD_SHARED_LIBS=1 \
    && cmake --build build \
    && mkdir -p $REST_EXT_INC/dftd4 \
    && cp build/libdftd4.so.* $REST_EXT_DIR/ \
    && cp build/_deps/multicharge-build/libmulticharge.so.* $REST_EXT_DIR/ \
    && cp build/_deps/mctc-lib-build/libmctc-lib.so.* $REST_EXT_DIR/ \
    && find build -name *.mod | xargs -I {} cp {} $REST_EXT_INC/dftd4 \
    && cd $REST_EXT_DIR && ln -s libdftd4.so.3 libdftd4.so

# =======================================================================
# 3. Finalize the REST installation in a new stage
FROM base AS rest
# Copy built dependencies from the previous stage
COPY --from=dependencies $REST_EXT_DIR/ $REST_EXT_DIR/
COPY --from=dependencies $REST_EXT_INC/ $REST_EXT_INC/

# Clone and build REST software components
RUN . /tmp/bashrc \
    && cd rest_workspace\
    && git clone --depth=1 ${RootUrl}/rest.git rest \
    && cd rest \
    && git fetch --depth=1 origin 783158e5d6dc24edb0d7b6cbf7a4a8816c568403 \
    && git checkout 783158e5d6dc24edb0d7b6cbf7a4a8816c568403

RUN . /tmp/bashrc \
    && cd rest_workspace\
    && git clone --depth=1 ${RootUrl}/rest_tensors.git rest_tensors \
    && cd rest_tensors \
    && git fetch --depth=1 origin 69862164277843a3c3faccb596f62840e60ad6ae \
    && git checkout 69862164277843a3c3faccb596f62840e60ad6ae
RUN . /tmp/bashrc \
    && cd rest_workspace\
    && git clone --depth=1 ${RootUrl}/rest_libcint.git rest_libcint \
    && cd rest_libcint \
    && git fetch --depth=1 origin 017c38b248077eb6d24413166a126e0fcfdbec9d \
    && git checkout 017c38b248077eb6d24413166a126e0fcfdbec9d
RUN . /tmp/bashrc \
    && cd rest_workspace\
    && git clone --depth=1 ${RootUrl}/rest_regression.git rest_regression \
    && cd rest_regression \
    && git fetch --depth=1 origin c45e5d8c3d2d8ff6c76977e45425aaf5c07012bd \
    && git checkout c45e5d8c3d2d8ff6c76977e45425aaf5c07012bd

# Build and verify REST
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

# set envs for root's development, if run `sudo su -`
RUN echo "\
\n\
# RUST Enviroments  \n\
export CC=gcc \n\
export CXX=g++ \n\
export FC=gfortran \n\
export CARGO_HOME=/opt/.cargo \n\
export RUSTUP_HOME=/opt/.rustup \n\
export REST_EXT_DIR=/opt/rest_workspace/lib \n\
export REST_EXT_INC=/opt/rest_workspace/include \n\
export REST_BLAS_DIR=/opt/rest_workspace/lib \n\
export REST_FORTRAN_COMPILER=gfortran \n\
export REST_HOME=/opt/rest_workspace \n\
export REST_CINT_DIR=\$REST_HOME/lib \n\
export HDF5_DIR=\$REST_HOME \n\
export REST_HDF5_DIR=\$REST_HOME \n\
export REST_XC_DIR=\$REST_HOME \n\
export PATH=\$REST_HOME/target/release:/opt/.cargo/bin:\$PATH \n\
export LD_LIBRARY_PATH=\$REST_EXT_DIR:\$LD_LIBRARY_PATH \n\
" >> $HOME/.bashrc

# add a sudo user to let mpirun work without warning
RUN useradd -m -s /bin/bash admin && echo "admin:password" | chpasswd
RUN usermod -aG sudo admin
RUN echo "admin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER admin