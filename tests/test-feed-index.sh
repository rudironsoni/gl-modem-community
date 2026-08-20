#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-feed-index.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$tmp/feed/25.12" "$tmp/feed/24.10" "$tmp/feed/21.02"
printf 'apk' > "$tmp/feed/25.12/gl-modem-community-0.0.1-r1.apk"
printf 'adb' > "$tmp/feed/25.12/packages.adb"
printf 'ipk' > "$tmp/feed/24.10/gl-modem-community_0.0.1-r1_aarch64_cortex-a53.ipk"
printf 'idx' > "$tmp/feed/24.10/Packages"
printf 'idz' > "$tmp/feed/24.10/Packages.gz"
printf 'ipk' > "$tmp/feed/21.02/gl-modem-community_0.0.1-1_glinet-21.02_aarch64_cortex-a53.ipk"
printf 'idx' > "$tmp/feed/21.02/Packages"
printf 'idz' > "$tmp/feed/21.02/Packages.gz"

make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed"

for page in index.html 25.12/index.html 24.10/index.html 21.02/index.html; do
	test -s "$tmp/feed/$page"
done

# Channel pages carry the install snippet and link every published file.
# apk resolves a repository line as the index URL itself, so the snippet
# must point at packages.adb, not at the channel directory.
grep -Fq '<pre>https://github.rudironsoni.com/gl-modem-community/feed/25.12/packages.adb</pre>' \
	"$tmp/feed/25.12/index.html"
grep -Fq '/etc/apk/repositories.d/customfeeds.list' "$tmp/feed/25.12/index.html"
grep -Fq 'href="gl-modem-community-0.0.1-r1.apk"' "$tmp/feed/25.12/index.html"
grep -Fq 'href="packages.adb"' "$tmp/feed/25.12/index.html"

grep -Fq '<pre>src/gz gl-modem-community https://github.rudironsoni.com/gl-modem-community/feed/24.10</pre>' \
	"$tmp/feed/24.10/index.html"
grep -Fq '/etc/opkg/customfeeds.conf' "$tmp/feed/24.10/index.html"
grep -Fq 'href="gl-modem-community_0.0.1-r1_aarch64_cortex-a53.ipk"' "$tmp/feed/24.10/index.html"
grep -Fq 'href="Packages"' "$tmp/feed/24.10/index.html"
grep -Fq 'href="Packages.gz"' "$tmp/feed/24.10/index.html"

grep -Fq '<pre>src/gz gl-modem-community https://github.rudironsoni.com/gl-modem-community/feed/21.02</pre>' \
	"$tmp/feed/21.02/index.html"
grep -Fq 'href="gl-modem-community_0.0.1-1_glinet-21.02_aarch64_cortex-a53.ipk"' \
	"$tmp/feed/21.02/index.html"

# Channel pages never link themselves.
if grep -Fq 'href="index.html"' "$tmp/feed/24.10/index.html"; then
	echo 'Channel index must not link itself' >&2
	exit 1
fi

# The root page links every channel.
grep -Fq 'href="25.12/"' "$tmp/feed/index.html"
grep -Fq 'href="24.10/"' "$tmp/feed/index.html"
grep -Fq 'href="21.02/"' "$tmp/feed/index.html"

# Regeneration is idempotent: the index pages do not list themselves after a rerun.
make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed"
if grep -Fq 'href="index.html"' "$tmp/feed/25.12/index.html"; then
	echo 'Channel index must not link itself after regeneration' >&2
	exit 1
fi

# Unknown channels are rejected instead of published with a wrong snippet.
mkdir "$tmp/feed/9.99"
if make -C "$REPO_DIR" --no-print-directory generate-feed-index FEED_DIR="$tmp/feed" 2>/dev/null; then
	echo 'generate-feed-index must reject unknown channels' >&2
	exit 1
fi
