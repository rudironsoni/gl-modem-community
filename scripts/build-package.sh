#!/bin/sh
set -eu
. "$(dirname "$0")/common.sh"

SDK_NAME='openwrt-sdk-25.12.5-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst'
SDK_URL="https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/$SDK_NAME"
SDK_SHA256='ff4a38a397caa2cfe1c39e18f84ddede14878221b3593c3f2c4cfe24e3ec4c25'
SDK_ARCHIVE="$REPO_DIR/tool-cache/$SDK_NAME"
SDK_DIR="$REPO_DIR/tool-cache/sdk-25.12.5-mediatek-filogic"
BUILD_IMAGE='mt3000-openwrt-sdk:25.12.5'

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

docker build --platform linux/amd64 -t "$BUILD_IMAGE" "$REPO_DIR/tools/sdk-container"
docker run --rm --platform linux/amd64 \
	--mount "type=bind,src=$REPO_DIR,dst=/repo" \
	"$BUILD_IMAGE" sh -c '
set -eu
cd /repo/tool-cache/sdk-25.12.5-mediatek-filogic
make defconfig
make package/gl-modem-community/compile V=s
' > "$ANALYSIS_DIR/reports/package-build.txt" 2>&1

artifact=$(find "$SDK_DIR/bin/packages" -type f -name 'gl-modem-community*.apk' -print | head -n 1)
test -n "$artifact"
cp "$artifact" "$REPO_DIR/artifacts/"
shasum -a 256 "$artifact" | sed "s#  $REPO_DIR/#  #" > "$ANALYSIS_DIR/hashes/gl-modem-community.apk.sha256"
printf '%s\n' "${artifact#$REPO_DIR/}" > "$ANALYSIS_DIR/reports/package-artifact-path.txt"
