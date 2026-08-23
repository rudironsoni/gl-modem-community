#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-feed-index.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

feed_url='https://github.rudironsoni.com/gl-modem-community/feed'
apk_dir="$tmp/feed/releases/25.12/packages/aarch64_cortex-a53/packages"
ipk24_dir="$tmp/feed/releases/24.10/packages/aarch64_cortex-a53/packages"
ipk21_dir="$tmp/feed/releases/21.02/packages/aarch64_cortex-a53/packages"
ipk21_neon_dir="$tmp/feed/releases/21.02/packages/aarch64_cortex-a53_neon-vfpv4/packages"

mkdir -p "$apk_dir" "$ipk24_dir" "$ipk21_dir" "$ipk21_neon_dir" \
	"$tmp/feed/25.12" "$tmp/feed/24.10" "$tmp/feed/21.02"
printf 'apk' > "$apk_dir/gl-modem-community-0.0.1-r1.apk"
printf 'adb' > "$apk_dir/packages.adb"
for dir in "$ipk24_dir"; do
	printf 'ipk' > "$dir/gl-modem-community_0.0.1-r1_all.ipk"
	printf 'idx' > "$dir/Packages"
	printf 'idz' > "$dir/Packages.gz"
	printf 'sig' > "$dir/Packages.sig"
done
for dir in "$ipk21_dir" "$ipk21_neon_dir"; do
	printf 'ipk' > "$dir/gl-modem-community_0.0.1-1_glinet-21.02_all.ipk"
	printf 'idx' > "$dir/Packages"
	printf 'idz' > "$dir/Packages.gz"
	printf 'sig' > "$dir/Packages.sig"
done
printf 'key' > "$tmp/feed/releases/24.10/ab12cd34ef567890.pub"
printf 'key' > "$tmp/feed/releases/21.02/ab12cd34ef567890.pub"

printf 'apk' > "$tmp/feed/25.12/gl-modem-community-0.0.1-r1.apk"
printf 'adb' > "$tmp/feed/25.12/packages.adb"
printf 'ipk' > "$tmp/feed/24.10/gl-modem-community_0.0.1-r1_all.ipk"
printf 'idx' > "$tmp/feed/24.10/Packages"
printf 'idz' > "$tmp/feed/24.10/Packages.gz"
printf 'ipk' > "$tmp/feed/21.02/gl-modem-community_0.0.1-1_glinet-21.02_all.ipk"
printf 'idx' > "$tmp/feed/21.02/Packages"
printf 'idz' > "$tmp/feed/21.02/Packages.gz"

make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed"

for page in \
	index.html \
	releases/index.html \
	releases/25.12/index.html \
	releases/25.12/packages/index.html \
	releases/25.12/packages/aarch64_cortex-a53/index.html \
	releases/25.12/packages/aarch64_cortex-a53/packages/index.html \
	releases/24.10/index.html \
	releases/24.10/packages/aarch64_cortex-a53/packages/index.html \
	releases/21.02/index.html \
	releases/21.02/packages/aarch64_cortex-a53/packages/index.html \
	releases/21.02/packages/aarch64_cortex-a53_neon-vfpv4/packages/index.html \
	25.12/index.html \
	24.10/index.html \
	21.02/index.html
do
	test -s "$tmp/feed/$page"
done

# Section pages carry the install snippet and link every published file.
# apk resolves a repository line as the index URL itself, so the snippet
# must point at packages.adb, not at the section directory.
grep -Fq "<pre>$feed_url/releases/25.12/packages/aarch64_cortex-a53/packages/packages.adb</pre>" \
	"$apk_dir/index.html"
grep -Fq '/etc/apk/repositories.d/customfeeds.list' "$apk_dir/index.html"
grep -Fq 'href="gl-modem-community-0.0.1-r1.apk"' "$apk_dir/index.html"
grep -Fq 'href="packages.adb"' "$apk_dir/index.html"

grep -Fq "<pre>src/gz gl-modem-community $feed_url/releases/24.10/packages/aarch64_cortex-a53/packages</pre>" \
	"$ipk24_dir/index.html"
grep -Fq '/etc/opkg/customfeeds.conf' "$ipk24_dir/index.html"
grep -Fq 'href="gl-modem-community_0.0.1-r1_all.ipk"' "$ipk24_dir/index.html"
grep -Fq 'href="Packages"' "$ipk24_dir/index.html"
grep -Fq 'href="Packages.gz"' "$ipk24_dir/index.html"
grep -Fq 'href="Packages.sig"' "$ipk24_dir/index.html"

# Both 21.02 architecture directories advertise their own feed line for the
# identical architecture-independent package.
grep -Fq "<pre>src/gz gl-modem-community $feed_url/releases/21.02/packages/aarch64_cortex-a53/packages</pre>" \
	"$ipk21_dir/index.html"
grep -Fq "<pre>src/gz gl-modem-community $feed_url/releases/21.02/packages/aarch64_cortex-a53_neon-vfpv4/packages</pre>" \
	"$ipk21_neon_dir/index.html"
grep -Fq 'href="gl-modem-community_0.0.1-1_glinet-21.02_all.ipk"' "$ipk21_dir/index.html"
grep -Fq 'href="gl-modem-community_0.0.1-1_glinet-21.02_all.ipk"' "$ipk21_neon_dir/index.html"

# Release pages list the published opkg signing key.
grep -Fq 'href="ab12cd34ef567890.pub"' "$tmp/feed/releases/24.10/index.html"
grep -Fq 'href="ab12cd34ef567890.pub"' "$tmp/feed/releases/21.02/index.html"

# The releases page links every release; the root page links releases and
# marks legacy channel directories as deprecated.
grep -Fq 'href="25.12/"' "$tmp/feed/releases/index.html"
grep -Fq 'href="24.10/"' "$tmp/feed/releases/index.html"
grep -Fq 'href="21.02/"' "$tmp/feed/releases/index.html"
grep -Fq 'href="releases/"' "$tmp/feed/index.html"
grep -Fq 'href="25.12/"' "$tmp/feed/index.html"
grep -Fq 'deprecated location' "$tmp/feed/index.html"
grep -Fq 'Deprecated' "$tmp/feed/21.02/index.html"
grep -Fq "releases/21.02/packages/" "$tmp/feed/21.02/index.html"

# Section pages never link themselves.
if grep -Fq 'href="index.html"' "$ipk24_dir/index.html"; then
	echo 'Section index must not link itself' >&2
	exit 1
fi

# Regeneration is idempotent: the index pages do not list themselves after a rerun.
make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed"
if grep -Fq 'href="index.html"' "$apk_dir/index.html"; then
	echo 'Section index must not link itself after regeneration' >&2
	exit 1
fi

# Unknown releases are rejected instead of published with a wrong snippet.
mkdir -p "$tmp/feed/releases/9.99/packages/aarch64_cortex-a53/packages"
if make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed" 2>/dev/null; then
	echo 'generate-feed-index must reject unknown releases' >&2
	exit 1
fi
rm -rf "$tmp/feed/releases/9.99"

# Unknown root channels are rejected as well.
mkdir "$tmp/feed/9.99"
if make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed" 2>/dev/null; then
	echo 'generate-feed-index must reject unknown channels' >&2
	exit 1
fi
