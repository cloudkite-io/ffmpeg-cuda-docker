# Ffmpeg with CUDA x264 hardware acceleration
This Dockerfile builds a custom ffmpeg library with `nv-codec-headers` that is able to run on any Kubernetes cluster with nvidia drivers >470 on the host.

* CUDA 11.8.0
* nv-codec-headers sdk/9.0
* ffmpeg 5.1

See the Dockerfile for specific ffmpeg build flags.

## Build
```bash
docker build --target=ffmpeg-cuda -t us.gcr.io/cloudkite-public/ffmpeg-cuda:latest .
```

The included Dockerfile is heavily optimized for image size - weighing in around 875mb with all of the required libraries to run ffmpeg.

## Deployment on GKE
For GKE 1.23 and greater with a COS nodepool with GPUs, you need to manually install Google's `nvidia-driver-installer` (or configure ArgoCD to deploy):
```bash
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded-latest.yaml
```

This will start a daemonset that'll look for GPU enabled nodes and will run the nvidia installer each time a node starts. At this point, any pod with the GPU resources set and the right nodeAffinities will schedule on the GPU nodes and have access to the GPUs.

Example:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ffmpeg-cuda
spec:
  containers:
  - name: ffmpeg-cuda
    image: us.gcr.io/cloudkite-public/ffmpeg-cuda:latest
    imagePullPolicy: Always
    command: ["/bin/bash", "-c", "--"]
    args: ["while true; do sleep 999999; done;"]
    resources:
      limits:
       nvidia.com/gpu: 1
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: cloud.google.com/gke-accelerator
            operator: Exists
```

*WARNING* Google's ubuntu `nvidia-driver-installer` currently does not install a sufficiently new Nvidia driver version to support `nv-codec-headers` for hardware acceleration.  You *must* use COS.


## Performance
On a Tesla P4 on a test video, we get around 470fps transcoding to h264:
```bash
root@ffmpeg-cuda:~# ffmpeg -hwaccel cuda -hwaccel_output_format cuda -i input.mp4 -c:v h264_nvenc output.mp4
ffmpeg version n5.1.2-9-g807afa59cc Copyright (c) 2000-2022 the FFmpeg developers
  built with gcc 11 (Ubuntu 11.3.0-1ubuntu1~22.04)
  configuration: --prefix=/usr/local --disable-debug --enable-cuda --enable-cuda-llvm --enable-cuda-nvcc --enable-cuvid --enable-ffnvcodec --enable-gpl --enable-libass --enable-libfdk-aac --enable-libnpp --enable-librtmp --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 --enable-nonfree --enable-nvenc --enable-opencl --enable-openssl --enable-pic --enable-static --extra-cflags=-I/usr/local/nvidia/include/ --extra-ldflags=-L/usr/local/nvidia/lib64/
  libavutil      57. 28.100 / 57. 28.100
  libavcodec     59. 37.100 / 59. 37.100
  libavformat    59. 27.100 / 59. 27.100
  libavdevice    59.  7.100 / 59.  7.100
  libavfilter     8. 44.100 /  8. 44.100
  libswscale      6.  7.100 /  6.  7.100
  libswresample   4.  7.100 /  4.  7.100
  libpostproc    56.  6.100 / 56.  6.100
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'input.mp4':
  Metadata:
    major_brand     : mp42
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    creation_time   : 2022-06-24T12:07:47.000000Z
    encoder         : HandBrake 1.1.1 2018061800
  Duration: 00:01:38.16, start: 0.000000, bitrate: 381 kb/s
  Stream #0:0[0x1](und): Video: h264 (Main) (avc1 / 0x31637661), yuv420p(tv, bt709, progressive), 1080x1072 [SAR 1:1 DAR 135:134], 244 kb/s, 30 fps, 30 tbr, 90k tbn (default)
    Metadata:
      creation_time   : 2022-06-24T12:07:47.000000Z
      handler_name    : VideoHandler
      vendor_id       : [0][0][0][0]
  Stream #0:1[0x2](und): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, stereo, fltp, 129 kb/s (default)
    Metadata:
      creation_time   : 2022-06-24T12:07:47.000000Z
      handler_name    : Stereo
      vendor_id       : [0][0][0][0]
Stream mapping:
  Stream #0:0 -> #0:0 (h264 (native) -> h264 (h264_nvenc))
  Stream #0:1 -> #0:1 (aac (native) -> aac (native))
Press [q] to stop, [?] for help
Output #0, mp4, to 'output.mp4':
  Metadata:
    major_brand     : mp42
    minor_version   : 512
    compatible_brands: isomiso2avc1mp41
    encoder         : Lavf59.27.100
  Stream #0:0(und): Video: h264 (Main) (avc1 / 0x31637661), cuda(tv, bt709, progressive), 1080x1072 [SAR 1:1 DAR 135:134], q=2-31, 2000 kb/s, 30 fps, 15360 tbn (default)
    Metadata:
      creation_time   : 2022-06-24T12:07:47.000000Z
      handler_name    : VideoHandler
      vendor_id       : [0][0][0][0]
      encoder         : Lavc59.37.100 h264_nvenc
    Side data:
      cpb: bitrate max/min/avg: 0/0/2000000 buffer size: 4000000 vbv_delay: N/A
  Stream #0:1(und): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, stereo, fltp, 128 kb/s (default)
    Metadata:
      creation_time   : 2022-06-24T12:07:47.000000Z
      handler_name    : Stereo
      vendor_id       : [0][0][0][0]
      encoder         : Lavc59.37.100 aac
frame= 2943 fps=470 q=9.0 Lsize=    9849kB time=00:01:38.11 bitrate= 822.3kbits/s speed=15.7x
video:8238kB audio:1526kB subtitle:0kB other streams:0kB global headers:0kB muxing overhead: 0.861115%
```

Without hardware acceleration, we get about 10% of the speed.