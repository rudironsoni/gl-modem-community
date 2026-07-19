FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash build-essential ca-certificates file gawk git libncurses-dev make \
      patch perl python3 python3-distutils rsync unzip wget zlib1g-dev zstd \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /repo
