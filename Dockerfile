ARG CMAKE_VERSION=4.3.4
ARG PYTHON_MAJOR_VERSION=3
ARG PYTHON_MINOR_VERSION=14
ARG PYTHON_PATCH=6
ARG PYTHON_VERSION=${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION}.${PYTHON_PATCH}

FROM ubuntu:26.04 AS cmake-build

ARG CMAKE_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
RUN tar -xvzf cmake-${CMAKE_VERSION}.tar.gz
RUN cd cmake-${CMAKE_VERSION} && ./bootstrap --prefix=/opt/cmake-${CMAKE_VERSION} && make -j $(nproc) && make install

FROM ubuntu:26.04 AS deploy

ARG CMAKE_VERSION
ARG PYTHON_MAJOR_VERSION
ARG PYTHON_MINOR_VERSION
ARG PYTHON_PATCH
ARG PYTHON_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PATH="/usr/local/lib":${PATH}
ENV LD_LIBRARY_PATH="/usr/lib/dotnet/host/fxr/10.0.9":${LD_LIBRARY_PATH}

ENV CC=/usr/bin/gcc-15
ENV CXX=/usr/bin/g++-15
ENV POWERSHELL_VERSION=7.6.3
ENV BOOST_VERSION=1.91.0-1
ENV BOOST_TAG=boost-${BOOST_VERSION}
CMD ["/bin/bash"]

RUN apt update
RUN apt install -y gcc g++ git zip unzip wget dotnet-sdk-10.0 make ninja-build uuid-dev netcat-openbsd redis-server sudo valgrind python3 python3-dev python3-pip python3-venv
RUN apt upgrade -y

RUN wget https://github.com/PowerShell/PowerShell/releases/latest/download/powershell_${POWERSHELL_VERSION}-1.deb_amd64.deb -O powershell.deb
RUN apt install ./powershell.deb
RUN rm -rf powershell.deb

RUN git clone https://github.com/boostorg/boost.git -b ${BOOST_TAG} --recursive

COPY --from=cmake-build /opt/cmake-${CMAKE_VERSION} /opt/cmake-${CMAKE_VERSION}

RUN ln -s /opt/cmake-${CMAKE_VERSION}/bin/cmake /usr/bin/cmake

RUN cd boost && mkdir build && cd build && cmake -DBOOST_STACKTRACE_ENABLE_BACKTRACE=ON -G "Ninja" .. && cmake --build . -j && cmake --install .
RUN rm -rf boost

RUN dotnet publish || true
