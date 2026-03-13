# gem5 build environment for Mac (Apple Silicon / Intel).
# Use with OrbStack or Docker Desktop. Build: docker build -t gem5-dev .
# Run: docker run -it --rm -v "$(pwd)/../gem5:/workspace/gem5-scripts" gem5-dev bash

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    g++ \
    scons \
    python3 \
    python3-dev \
    python3-pip \
    pkg-config \
    libgoogle-perftools-dev \
    zlib1g-dev \
    libhdf5-dev \
    libpng-dev \
    libelf-dev \
    libboost-all-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Optional: pre-clone gem5 (large; uncomment if you want image to include repo)
# RUN git clone https://github.com/gem5/gem5 /gem5 && cd /gem5 && \
#     scons build/X86/gem5.opt -j$(nproc) || true
# Recommend instead: bind-mount your clone and build inside container.

WORKDIR /gem5
VOLUME ["/workspace/gem5-scripts"]

# Default command: shell so you can run scons manually
CMD ["/bin/bash"]
