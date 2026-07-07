FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        binutils \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        g++-aarch64-linux-gnu \
        gcc-aarch64-linux-gnu \
        git \
        libtool \
        ninja-build \
        patchelf \
        pkg-config \
        python3 \
        rsync \
        wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
