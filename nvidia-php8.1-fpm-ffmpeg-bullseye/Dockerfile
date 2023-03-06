# Add nvidia CUDA packages to php base image
FROM php:8.1-fpm-bullseye as nvidia
ENV NVDISTRO debian11
ENV NVARCH x86_64
ENV NVIDIA_REQUIRE_CUDA "cuda>=11.8 brand=tesla,driver>=450,driver<451 brand=tesla,driver>=470,driver<471 brand=unknown,driver>=470,driver<471 brand=nvidia,driver>=470,driver<471 brand=nvidiartx,driver>=470,driver<471 brand=geforce,driver>=470,driver<471 brand=geforcertx,driver>=470,driver<471 brand=quadro,driver>=470,driver<471 brand=quadrortx,driver>=470,driver<471 brand=titan,driver>=470,driver<471 brand=titanrtx,driver>=470,driver<471 brand=tesla,driver>=510,driver<511 brand=unknown,driver>=510,driver<511 brand=nvidia,driver>=510,driver<511 brand=nvidiartx,driver>=510,driver<511 brand=geforce,driver>=510,driver<511 brand=geforcertx,driver>=510,driver<511 brand=quadro,driver>=510,driver<511 brand=quadrortx,driver>=510,driver<511 brand=titan,driver>=510,driver<511 brand=titanrtx,driver>=510,driver<511 brand=tesla,driver>=515,driver<516 brand=unknown,driver>=515,driver<516 brand=nvidia,driver>=515,driver<516 brand=nvidiartx,driver>=515,driver<516 brand=geforce,driver>=515,driver<516 brand=geforcertx,driver>=515,driver<516 brand=quadro,driver>=515,driver<516 brand=quadrortx,driver>=515,driver<516 brand=titan,driver>=515,driver<516 brand=titanrtx,driver>=515,driver<516"
ENV NV_CUDA_CUDART_VERSION 11.8.89-1
ENV NV_CUDA_COMPAT_PACKAGE cuda-compat-11-8
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 curl ca-certificates && \
    curl -fsSLO https://developer.download.nvidia.com/compute/cuda/repos/${NVDISTRO}/${NVARCH}/cuda-keyring_1.0-1_all.deb && \
    dpkg -i cuda-keyring_1.0-1_all.deb && \
    apt-get purge --autoremove -y curl \
    && rm -rf /var/lib/apt/lists/*
# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-11-8=${NV_CUDA_CUDART_VERSION} \
    ${NV_CUDA_COMPAT_PACKAGE} \
    && rm -rf /var/lib/apt/lists/*
# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
    && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf
ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility


# Add enc/dec libraries to nvidia+php as base image
FROM nvidia as base
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Etc/UTC
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig/
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES video,compute,utility
# Update base and install build tools
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" >> /etc/apt/sources.list
RUN apt update && apt -y upgrade
# Install ffmpeg libraries
RUN apt install -y \
      libass-dev \
      libfdk-aac-dev \
      libnppicc11 \
      libnppidei11 \
      libnppif11 \
      libnppig11 \
      librtmp-dev \
      libssl-dev \
      libvdpau1 \
      libvorbis-dev \
      libvpx-dev \
      libx264-dev \
      libx265-dev 


# Use base image to build ffmpeg binary 
FROM base as ffmpeg-builder
# Install build tools
RUN apt -y install build-essential cmake gcc git libc6 libc6-dev libtool nasm nvidia-cuda-toolkit yasm
# Ffmpeg
WORKDIR /src
RUN apt-get update -y && apt-get install -y wget openssl cmake libevent-dev libjpeg-dev libgif-dev libpng-dev libwebp-dev libmagickwand-dev imagemagick libmemcached-dev
RUN wget http://www.imagemagick.org/download/ImageMagick-7.1.0-62.tar.gz && \
    tar zxvf ImageMagick-7.1.0-62.tar.gz && \
    cd ImageMagick-7.1.0-62 && \
    ./configure  --prefix=/usr/local  && \
    make && make install
ARG ZIMG_VERSION=2.7.0 
ARG ZIMG_URL="https://github.com/sekrit-twc/zimg/archive/release-$ZIMG_VERSION.tar.gz"
ARG ZIMG_SHA256=219d1bc6b7fde1355d72c9b406ebd730a4aed9c21da779660f0a4c851243e32f
RUN \
  wget $WGET_OPTS -O zimg.tar.gz "$ZIMG_URL" && \
  echo "$ZIMG_SHA256  zimg.tar.gz" | sha256sum --status -c - && \
  tar xf zimg.tar.gz && \
  cd zimg-* && ./autogen.sh && ./configure --disable-shared --enable-static && \
  make -j$(nproc) install
RUN git clone --depth=1 https://gitlab.com/AOMediaCodec/SVT-AV1 && cd SVT-AV1/Build && cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
    && make -j $(nproc) && make install
# Install libaom from source.
RUN git clone https://aomedia.googlesource.com/aom && cmake ./aom && \
  make && make install
RUN git clone https://github.com/FFmpeg/nv-codec-headers.git -b old/sdk/9.0 && cd nv-codec-headers && \
      make && make install
RUN git clone https://github.com/FFmpeg/FFmpeg -b release/5.1 && \ 
      cd /src/FFmpeg && \
        ./configure \
        --prefix="/usr/local" \
        --disable-debug \
        --enable-cuda \
        --enable-cuda-llvm \
        --enable-cuda-nvcc \
        --enable-cuvid \
        --enable-ffnvcodec \
        --enable-gpl \
        --enable-libaom \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libnpp \
        --enable-librtmp \
        --enable-libsvtav1 \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libzimg \
        --enable-nonfree \
        --enable-nvenc \
        --enable-opencl \
        --enable-openssl \
        --enable-pic \
        --enable-static \
        --extra-cflags="-I/usr/local/nvidia/include/" \
        --extra-ldflags="-L/usr/local/nvidia/lib64/" && \
    make -j$(nproc) && make install


# Copy ffmpeg binary back to base image without compilation layers
FROM base as nvidia-php-ffmpeg 
COPY --from=ffmpeg-builder /usr/local/bin /usr/local/bin
