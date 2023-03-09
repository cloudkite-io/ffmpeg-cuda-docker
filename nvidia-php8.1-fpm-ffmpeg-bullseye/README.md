# PHP 8.1 FPM combined with NVIDIA CUDA on Debian Bullseye

```shell
docker build --target=nvidia-php-ffmpeg -t us.gcr.io/cloudkite-public/nvidia-php8.1-fpm-ffmpeg-bullseye .
```
### Building with cloudbuild
Substitute `_IMAGE_TAG` value with an appropriate value for tagging the built docker image, it defaults to `latest`.
```
gcloud builds submit --project=cloudkite-public --config cloudbuild.yaml --substitutions=_IMAGE_TAG="<image tag here>" --timeout=2h
```
