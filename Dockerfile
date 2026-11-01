ARG CMAKE_VERSION=4.4.5
ARG PYTHON_MAJOR_VERSION=3
ARG PYTHON_MINOR_VERSION=15
ARG PYTHON_PATCH=2
ARG PYTHON_VERSION=${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION}.${PYTHON_PATCH}

FROM ubuntu:26.04 AS cmake-builder

ARG CMAKE_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt install -y build-essential libssl-dev curl tar
     
WORKDIR /tmp

RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
RUN tar -xvzf cmake-${CMAKE_VERSION}.tar.gz
RUN cd cmake-${CMAKE_VERSION} && ./bootstrap --prefix=/opt/cmake && make -j $(nproc) && make install

FROM ubuntu:26.04 AS python-builder

ARG PYTHON_MAJOR_VERSION
ARG PYTHON_MINOR_VERSION
ARG PYTHON_PATCH
ARG PYTHON_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN apt install -y build-essential ca-certificates curl libbz2-dev libffi-dev libgdbm-dev liblzma-dev libncurses-dev libreadline-dev libsqlite3-dev libssl-dev tk-dev uuid-dev zlib1g-dev xz-utils wget unzip

WORKDIR /tmp

RUN wget https://github.com/python/cpython/archive/refs/tags/v${PYTHON_VERSION}.zip
RUN unzip v${PYTHON_VERSION}.zip -d python_source
RUN cd python_source/cpython-${PYTHON_VERSION} && ./configure --enable-shared --enable-optimizations --with-lto --with-computed-gotos --with-ensurepip=install --prefix=/opt/python && make -j $(nproc) && make install

FROM ubuntu:26.04 AS deploy

ARG PYTHON_MAJOR_VERSION
ARG PYTHON_MINOR_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PATH="/usr/local/lib":${PATH}
ENV LD_LIBRARY_PATH="/usr/lib/dotnet/host/fxr/10.0.14":"/opt/python/lib"

ENV CC=/usr/bin/gcc-15
ENV CXX=/usr/bin/g++-15
ENV POWERSHELL_VERSION=7.6.9
ENV BOOST_VERSION=1.92.0
ENV BOOST_TAG=boost-${BOOST_VERSION}
CMD ["/bin/bash"]

RUN apt update
RUN apt install -y gcc g++ git zip unzip wget dotnet-sdk-10.0 make ninja-build uuid-dev netcat-openbsd redis-server sudo valgrind curl
RUN apt install ca-certificates libbz2-1.0 libffi8 libgdbm6 liblzma5 libncursesw6 libreadline8 libsqlite3-0 libssl3t64 zlib1g
RUN apt upgrade -y

RUN wget https://github.com/PowerShell/PowerShell/releases/latest/download/powershell_${POWERSHELL_VERSION}-1.deb_amd64.deb -O powershell.deb
RUN apt install ./powershell.deb
RUN rm -rf powershell.deb

RUN git clone https://github.com/boostorg/boost.git -b ${BOOST_TAG} --recursive

RUN dotnet publish || true

COPY --from=cmake-builder /opt/cmake /opt/cmake
COPY --from=python-builder /opt/python /opt/python

RUN ln -s /opt/cmake/bin/cmake /usr/bin/cmake
RUN update-alternatives --install /usr/bin/python3 python3 $(readlink -f $(which python3)) 0
RUN update-alternatives --install /usr/bin/python3 python3 /opt/python/bin/python${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION} 1
RUN update-alternatives --install /usr/bin/pip3 pip3 /opt/python/bin/pip${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION} 1
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install build
RUN ln -s $(which python3) /usr/bin/python

RUN cd boost && mkdir build && cd build && cmake -DBOOST_STACKTRACE_ENABLE_BACKTRACE=ON -G "Ninja" .. && cmake --build . -j && cmake --install .
RUN rm -rf boost
