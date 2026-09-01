FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bash build-essential ca-certificates file gawk git jq libicu72 libncurses-dev make openssl \
      patch perl python3 python3-distutils rsync unzip wget zlib1g-dev zstd \
 && rm -rf /var/lib/apt/lists/*

ARG CYCLONEDX_CLI_VERSION=0.32.0
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) asset='cyclonedx-linux-x64'; checksum='454879e6a4a405c8a13bff49b8982adcb0596f3019b26b0811c66e4d7f0783e1' ;; \
      arm64) asset='cyclonedx-linux-arm64'; checksum='abf0b7c5648a5b127791d691cad41f004aceea27c75bb42c9572fdc9694770cf' ;; \
      *) echo "Unsupported CycloneDX CLI architecture: $arch" >&2; exit 1 ;; \
    esac; \
    wget -q -O /tmp/cyclonedx \
      "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CYCLONEDX_CLI_VERSION}/$asset"; \
    printf '%s  %s\n' "$checksum" /tmp/cyclonedx | sha256sum -c -; \
    install -m 0755 /tmp/cyclonedx /usr/local/bin/cyclonedx; \
    rm /tmp/cyclonedx

WORKDIR /repo
