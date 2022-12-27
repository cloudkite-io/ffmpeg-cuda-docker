FROM nvidia/cuda:11.8.0-base-ubuntu22.04 as base

ENV DEBIAN_FRONTEND noninteractive
ENV TZ Etc/UTC
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib64
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig/
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES video,compute,utility

# Update base and install build tools
RUN apt update && apt -y upgrade
# Install ffmpeg libraries
RUN apt install -y \
      libass-dev \
      libfdk-aac-dev \
      librtmp-dev \
      libssl-dev \
      libvdpau1 \
      libvorbis-dev \
      libvpx-dev \
      libx264-dev \
      libx265-dev 

FROM base as builder
# Install build tools
RUN apt -y install build-essential cmake gcc git libc6 libc6-dev libtool nasm nvidia-cuda-toolkit yasm
# Ffmpeg
WORKDIR /src
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
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libnpp \
        --enable-librtmp \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-nonfree \
        --enable-nvenc \
        --enable-opencl \
        --enable-openssl \
        --enable-pic \
        --enable-static \
        --extra-cflags="-I/usr/local/nvidia/include/" \
        --extra-ldflags="-L/usr/local/nvidia/lib64/" && \
    make -j$(nproc) && make install

FROM base as ffmpeg-cuda 
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /lib/x86_64-linux-gnu/libnppc.so.11 /lib/x86_64-linux-gnu/libnppc.so.11
COPY --from=builder /lib/x86_64-linux-gnu/libnppicc.so.11 /lib/x86_64-linux-gnu/libnppicc.so.11
COPY --from=builder /lib/x86_64-linux-gnu/libnppidei.so.11 /lib/x86_64-linux-gnu/libnppidei.so.11
COPY --from=builder /lib/x86_64-linux-gnu/libnppif.so.11 /lib/x86_64-linux-gnu/libnppif.so.11
COPY --from=builder /lib/x86_64-linux-gnu/libnppig.so.11 /lib/x86_64-linux-gnu/libnppig.so.11