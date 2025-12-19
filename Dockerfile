# Check for latest version here: https://hub.docker.com/_/buildpack-deps?tab=tags&page=1&name=buster&ordering=last_updated
# This is just a snapshot of buildpack-deps:buster that was last updated on 2019-12-28.
FROM buildpack-deps:bookworm

LABEL maintainer="Herman Zvonimir Došilović <hermanz.dosilovic@gmail.com>"
LABEL description="Judge0 compilers with modern language versions"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# ------------------------------------------------------------
# System essentials
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    clang \
    wget \
    gnupg \
    software-properties-common \
    unzip \
    xz-utils \
    pkg-config \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# C / C++ — GCC 14 (source build)
# ============================================================

RUN apt-get update && apt-get install -y \
    flex \
    bison \
    libgmp-dev \
    libmpc-dev \
    libmpfr-dev \
    texinfo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN wget https://ftp.gnu.org/gnu/gcc/gcc-14.1.0/gcc-14.1.0.tar.xz && \
    tar -xf gcc-14.1.0.tar.xz && \
    cd gcc-14.1.0 && \
    ./contrib/download_prerequisites && \
    mkdir build && cd build && \
    ../configure \
      --disable-multilib \
      --enable-languages=c,c++ \
      --prefix=/opt/gcc-14 && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/gcc-14.1.0*

RUN update-alternatives --install /usr/bin/gcc gcc /opt/gcc-14/bin/gcc 100 && \
    update-alternatives --install /usr/bin/g++ g++ /opt/gcc-14/bin/g++ 100

ENV LD_LIBRARY_PATH="/opt/gcc-14/lib64"

# ============================================================
# Java — OpenJDK 25 (Adoptium)
# ============================================================

RUN wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
    > /etc/apt/sources.list.d/adoptium.list

RUN apt-get update && apt-get install -y \
    temurin-25-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# ============================================================
# Python
#   - Python 2.7.18 (legacy)
#   - Python 3.11
# ============================================================

# Python 2.7.18 (build from source)
RUN wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz && \
    tar -xzf Python-2.7.18.tgz && \
    cd Python-2.7.18 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf Python-2.7.18*

# ============================================================
# Python 3.11 (with venv for user execution)
# ============================================================

RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment for Judge0 Python execution
RUN python3.11 -m venv /opt/python3.11

# Install common libraries inside venv
RUN /opt/python3.11/bin/pip install --no-cache-dir \
    numpy \
    scipy \
    pandas

# ============================================================
# C# — .NET 9 SDK (C# 13)
# ============================================================

ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${DOTNET_ROOT}:${DOTNET_ROOT}/tools:/root/.dotnet/tools:${PATH}"

RUN mkdir -p /opt/dotnet && \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh \
        --channel 9.0 \
        --install-dir /opt/dotnet \
        --no-path && \
    rm /tmp/dotnet-install.sh && \
    dotnet --version && \
    dotnet tool install -g dotnet-script

# ============================================================
# JavaScript / TypeScript — Node.js 22.21.0
# ============================================================

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

RUN apt-get update && apt-get install -y \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    typescript@5.7.3

# ============================================================
# Ruby — 3.2.x (source build)
# ============================================================

RUN apt-get update && apt-get install -y \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    libgdbm-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libdb-dev \
    uuid-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

ARG RUBY_VERSION=3.2.4

RUN wget https://cache.ruby-lang.org/pub/ruby/3.2/ruby-${RUBY_VERSION}.tar.gz && \
    tar -xzf ruby-${RUBY_VERSION}.tar.gz && \
    cd ruby-${RUBY_VERSION} && \
    ./configure --disable-install-doc && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/ruby-${RUBY_VERSION}*

# Ruby gems
RUN gem update --system && \
    gem install algorithms


# ============================================================
# Swift — 6.0
# ============================================================

WORKDIR /tmp

ENV SWIFT_VERSION=6.0
ENV SWIFTROOT=/usr/local/swift
ENV SWIFTPATH=/opt/swift
ENV PATH="$SWIFTROOT/bin:$SWIFTPATH/bin:$PATH"

RUN wget https://download.swift.org/swift-${SWIFT_VERSION}-release/debian12/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-debian12.tar.gz && \
    tar -C /usr/local -xzf swift-${SWIFT_VERSION}-RELEASE-debian12.tar.gz && \
    mv /usr/local/swift-${SWIFT_VERSION}-RELEASE-debian12/usr /usr/local/swift && \
    rm -rf /usr/local/swift-${SWIFT_VERSION}-RELEASE-debian12 && \
    rm swift-${SWIFT_VERSION}-RELEASE-debian12.tar.gz

# ============================================================
# Go — Latest Stable (>=1.22)
# ============================================================

ENV GOROOT=/usr/local/go
ENV GOPATH=/opt/go
ENV PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

WORKDIR /tmp

RUN curl -fsSL https://go.dev/dl/?mode=json | \
    grep -Eo 'go[0-9]+\.[0-9]+\.[0-9]+\.linux-amd64\.tar\.gz' | \
    head -n 1 | \
    xargs -I {} wget https://dl.google.com/go/{} && \
    tar -C /usr/local -xzf go*.linux-amd64.tar.gz && \
    rm go*.linux-amd64.tar.gz

# ============================================================
# Kotlin — 2.1.10
# ============================================================

WORKDIR /opt

RUN wget https://github.com/JetBrains/kotlin/releases/download/v2.1.10/kotlin-compiler-2.1.10.zip && \
    unzip kotlin-compiler-2.1.10.zip && \
    rm kotlin-compiler-2.1.10.zip

ENV PATH="/opt/kotlinc/bin:$PATH"

# ============================================================
# Rust — 1.88.0 (Edition 2024)
# ============================================================

ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH="/opt/cargo/bin:$PATH"

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    rustup toolchain install 1.88.0 && \
    rustup default 1.88.0

# ============================================================
# PHP — 8.2 (with bcmath)
# ============================================================

RUN apt-get update && apt-get install -y \
    php8.2 \
    php8.2-bcmath \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Final cleanup
# ============================================================

WORKDIR /

RUN apt-get clean && rm -rf /tmp/* /var/tmp/*
