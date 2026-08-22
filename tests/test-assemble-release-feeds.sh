#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-feed-assembly.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

version=1.2.3
assets="$tmp/assets"
feed="$tmp/feed"
mkdir -p "$assets"

printf 'apk\n' >"$assets/gl-modem-community-${version}-r1.apk"
printf 'index\n' >"$assets/packages.adb"
printf 'ipk24\n' >"$assets/gl-modem-community_${version}-r1_aarch64_cortex-a53.ipk"
printf 'ipk21\n' >"$assets/gl-modem-community_${version}-1_glinet-21.02_aarch64_cortex-a53.ipk"
printf 'ipkbe3600\n' >"$assets/gl-modem-community_${version}-r1_gl-be3600-4.9_aarch64_cortex-a53_neon-vfpv4.ipk"

sh "$REPO_DIR/tools/assemble-release-feeds" "$version" "$assets" "$feed"

cmp "$assets/gl-modem-community-${version}-r1.apk" \
	"$feed/25.12/gl-modem-community-${version}-r1.apk"
cmp "$assets/packages.adb" "$feed/25.12/packages.adb"
cmp "$assets/gl-modem-community_${version}-r1_aarch64_cortex-a53.ipk" \
	"$feed/24.10/gl-modem-community_${version}-r1_aarch64_cortex-a53.ipk"
cmp "$assets/gl-modem-community_${version}-1_glinet-21.02_aarch64_cortex-a53.ipk" \
	"$feed/21.02/gl-modem-community_${version}-1_glinet-21.02_aarch64_cortex-a53.ipk"
cmp "$assets/gl-modem-community_${version}-r1_gl-be3600-4.9_aarch64_cortex-a53_neon-vfpv4.ipk" \
	"$feed/23.05-be3600/gl-modem-community_${version}-r1_gl-be3600-4.9_aarch64_cortex-a53_neon-vfpv4.ipk"

grep -Fqx "Version: ${version}-r1" "$feed/24.10/Packages"
grep -Fqx "Version: ${version}-1" "$feed/21.02/Packages"
grep -Fqx "Version: ${version}-r1" "$feed/23.05-be3600/Packages"
grep -Fqx 'Depends: comgt, flock, jq, kmod-usb-acm, kmod-usb-serial-option, kmod-usb-net-rndis' \
	"$feed/24.10/Packages"
grep -Fqx 'Depends: adb, comgt, flock, jq, kmod-usb-acm, kmod-usb-serial-option, kmod-usb-net-qmi-wwan, kmod-usb-net-rndis, lua, luci-lib-nixio, uqmi' \
	"$feed/23.05-be3600/Packages"

for path in \
	"$feed/index.html" \
	"$feed/25.12/index.html" \
	"$feed/24.10/index.html" \
	"$feed/24.10/Packages.gz" \
	"$feed/21.02/index.html" \
	"$feed/21.02/Packages.gz" \
	"$feed/23.05-be3600/index.html" \
	"$feed/23.05-be3600/Packages.gz"
do
	test -s "$path"
done
