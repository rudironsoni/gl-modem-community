#!/bin/sh
set -eu

. "$(dirname "$0")/common.sh"

SDK_NAME='openwrt-sdk-24.10.7-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst'
SDK_URL="https://downloads.openwrt.org/releases/24.10.7/targets/mediatek/filogic/$SDK_NAME"
SDK_SHA256='8d8fd6dd96458f6f397b069e3212c6dc365c306b0be32c95c9497b52d80b13df'
SDK_ARCHIVE="$REPO_DIR/tool-cache/$SDK_NAME"
SDK_DIR="$REPO_DIR/tool-cache/sdk-24.10.7-mediatek-filogic"
BUILD_IMAGE='mt3000-openwrt-sdk:24.10.7'

mkdir -p "$REPO_DIR/tool-cache" "$REPO_DIR/artifacts" "$ANALYSIS_DIR/reports"
if ! test -f "$SDK_ARCHIVE"; then
	curl --fail --location --retry 2 --output "$SDK_ARCHIVE.partial" "$SDK_URL"
	mv "$SDK_ARCHIVE.partial" "$SDK_ARCHIVE"
fi
printf '%s  %s\n' "$SDK_SHA256" "$SDK_ARCHIVE" | shasum -a 256 -c -

if ! test -d "$SDK_DIR"; then
	mkdir -p "$SDK_DIR"
	tar --zstd --strip-components=1 -xf "$SDK_ARCHIVE" -C "$SDK_DIR"
fi

mkdir -p "$SDK_DIR/package/gl-modem-community"
rsync -a --delete "$REPO_DIR/package/gl-modem-community/" "$SDK_DIR/package/gl-modem-community/"
find "$SDK_DIR/bin/packages" -type f -name 'gl-modem-community*.ipk' -delete 2>/dev/null || true
find "$REPO_DIR/artifacts" -type f -name 'gl-modem-community*.ipk' -delete 2>/dev/null || true

docker build --platform linux/amd64 -t "$BUILD_IMAGE" "$REPO_DIR/tools/sdk-container"
docker run --rm --platform linux/amd64 \
	--mount "type=bind,src=$REPO_DIR,dst=/repo" \
	"$BUILD_IMAGE" sh -c '
set -eu
cd /repo/tool-cache/sdk-24.10.7-mediatek-filogic
make defconfig
make package/gl-modem-community/compile V=s
' > "$ANALYSIS_DIR/reports/package-opkg-build.txt" 2>&1

artifact=$(find "$SDK_DIR/bin/packages" -type f -name 'gl-modem-community*.ipk' -print | head -n 1)
test -n "$artifact"
artifact_name=${artifact##*/}
cp "$artifact" "$REPO_DIR/artifacts/"
chmod 0644 "$REPO_DIR/artifacts/$artifact_name"
shasum -a 256 "$artifact" | sed "s#  $REPO_DIR/#  #" > "$ANALYSIS_DIR/hashes/gl-modem-community.ipk.sha256"
printf '%s\n' "${artifact#$REPO_DIR/}" > "$ANALYSIS_DIR/reports/package-opkg-artifact-path.txt"
