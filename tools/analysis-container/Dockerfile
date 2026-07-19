FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      binutils binwalk coreutils curl device-tree-compiler file \
      findutils gawk git jq lua5.1 make openssl p7zip-full python3 python3-pip shellcheck \
      squashfs-tools tar u-boot-tools xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --break-system-packages jsbeautifier==1.15.4

WORKDIR /repo
