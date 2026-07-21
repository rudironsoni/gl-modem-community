FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      binutils binwalk coreutils curl device-tree-compiler file \
      findutils gawk git jq libicu72 lua5.1 make openssl p7zip-full python3 python3-pip shellcheck \
      squashfs-tools tar u-boot-tools xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --break-system-packages jsbeautifier==1.15.4

ARG ACTIONLINT_VERSION=1.7.12
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) checksum='8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8' ;; \
      arm64) checksum='325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6' ;; \
      *) echo "Unsupported actionlint architecture: $arch" >&2; exit 1 ;; \
    esac; \
    archive="actionlint_${ACTIONLINT_VERSION}_linux_${arch}.tar.gz"; \
    curl --fail --location --retry 2 \
      --output "/tmp/$archive" \
      "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/$archive"; \
    printf '%s  %s\n' "$checksum" "/tmp/$archive" | sha256sum -c -; \
    tar -xzf "/tmp/$archive" -C /usr/local/bin actionlint; \
    rm "/tmp/$archive"

ARG CYCLONEDX_CLI_VERSION=0.32.0
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) asset='cyclonedx-linux-x64'; checksum='454879e6a4a405c8a13bff49b8982adcb0596f3019b26b0811c66e4d7f0783e1' ;; \
      arm64) asset='cyclonedx-linux-arm64'; checksum='abf0b7c5648a5b127791d691cad41f004aceea27c75bb42c9572fdc9694770cf' ;; \
      *) echo "Unsupported CycloneDX CLI architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl --fail --location --retry 2 \
      --output /tmp/cyclonedx \
      "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CYCLONEDX_CLI_VERSION}/$asset"; \
    printf '%s  %s\n' "$checksum" /tmp/cyclonedx | sha256sum -c -; \
    install -m 0755 /tmp/cyclonedx /usr/local/bin/cyclonedx; \
    rm /tmp/cyclonedx

WORKDIR /repo
