ARG CMAKE_VERSION=4.3.4

FROM ubuntu:26.04 AS cmake-build

ENV DEBIAN_FRONTEND=noninteractive

ARG CMAKE_VERSION

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

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV LD_LIBRARY_PATH="/usr/lib/dotnet/host/fxr/10.0.9":${LD_LIBRARY_PATH}

ARG CMAKE_VERSION
ENV ANDROID_VERSION=android-35
ENV SDK_INSTALL_NAME=platforms;android-35
ENV BUILD_TOOLS_NAME=build-tools;35.0.0
ENV NDK_VERSION=29.0.14206865
ENV NDK_INSTALL_NAME=ndk;${NDK_VERSION}
ENV NDK_PATH=/Android/Sdk/ndk/${NDK_VERSION}
ENV ANDROID_NDK_ROOT=${NDK_PATH}

ENV FLUTTER_VERSION=3.44.4
ENV FLUTTER_PATH=/opt/flutter
ENV FLUTTER_BIN_PATH=${FLUTTER_PATH}/bin

ENV CC=/usr/bin/clang
ENV CXX=/usr/bin/clang++

ENV ANDROID_CMAKE_BUILD_ARGUMENTS="-DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=${ANDROID_VERSION} -DCMAKE_TOOLCHAIN_FILE=${NDK_PATH}/build/cmake/android.toolchain.cmake"

CMD ["/bin/bash"]

RUN apt update
RUN apt install -y python3 python3-pip python3-venv git zip unzip wget sudo dotnet-sdk-10.0 openjdk-21-jdk clang ninja-build pkg-config libgtk-3-dev ninja-build netcat-openbsd redis-server
RUN apt upgrade -y
RUN apt autoremove

RUN python3 -m pip install build

RUN wget -q "https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt update
RUN apt install -y powershell
RUN rm -rf packages-microsoft-prod.deb

COPY --from=cmake-build /opt/cmake-${CMAKE_VERSION} /opt/cmake-${CMAKE_VERSION}

RUN ln -s /opt/cmake-${CMAKE_VERSION}/bin/cmake /usr/bin/cmake

RUN wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O tools.zip
RUN unzip tools.zip
RUN rm -rf tools.zip
RUN mkdir latest && cd cmdline-tools && mv * ../latest/ && mv ../latest . && cd .. && mkdir -p Android/Sdk && mv cmdline-tools Android/Sdk && cd Android/Sdk/cmdline-tools/latest/bin && yes | ./sdkmanager --licenses && ./sdkmanager "${NDK_INSTALL_NAME}" && ./sdkmanager --install "${NDK_INSTALL_NAME}" && ./sdkmanager --list | grep ndk

RUN wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
RUN tar -xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -C /opt/
RUN rm -rf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz

ENV ANDROID_HOME=/Android/Sdk
ENV PATH=${FLUTTER_BIN_PATH}:${ANDROID_HOME}:${ANDROID_HOME}/cmdline-tools:${ANDROID_HOME}/platforms:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platforms/${ANDROID_VERSION}:${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}

RUN sdkmanager "platform-tools" "${SDK_INSTALL_NAME}" "${BUILD_TOOLS_NAME}"

RUN git config --system --add safe.directory /opt/flutter
RUN flutter config --android-sdk ${ANDROID_HOME}
RUN flutter --version
RUN flutter doctor -v

RUN ln -s $(which python3) /usr/bin/python
