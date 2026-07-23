#!/bin/bash
set -euo pipefail

unset CDPATH
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/gl-modem-sbom-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

printf 'signed apk fixture\n' > "$tmp/package.apk"
cat > "$tmp/apk-metadata.json" <<'JSON'
{
  "info": {
    "name": "gl-modem-community",
    "version": "1.2.3-r1",
    "description": "Fixture package",
    "arch": "aarch64_cortex-a53",
    "license": "GPL-3.0-only",
    "depends": ["jq>=0", "libc"]
  },
  "paths": [
    {
      "name": "etc/config",
      "files": [
        {
          "name": "gl_modem_community",
          "hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        }
      ]
    }
  ]
}
JSON

make -C "$REPO_DIR" --no-print-directory generate-sbom \
	SBOM_FORMAT=apk \
	SBOM_ARTIFACT="$tmp/package.apk" \
	SBOM_OUTPUT="$tmp/apk.cdx.json" \
	APK_METADATA="$tmp/apk-metadata.json"
make -C "$REPO_DIR" --no-print-directory validate-sbom SBOM="$tmp/apk.cdx.json"
jq -e '
    .metadata.component.name == "gl-modem-community" and
    .metadata.component.version == "1.2.3-r1" and
    ([.components[] | select(.type == "library") | .name] == ["jq", "libc"]) and
    ([.components[] | select(.type == "file") | .name] == ["/etc/config/gl_modem_community"])
' "$tmp/apk.cdx.json" >/dev/null

mkdir -p "$tmp/ipk/control" "$tmp/ipk/data/etc/config" "$tmp/ipk/outer"
cat > "$tmp/ipk/control/control" <<'CONTROL'
Package: gl-modem-community
Version: 1.2.3-r1
Depends: jq (>=0), libc
License: GPL-3.0-only
Architecture: aarch64_cortex-a53
Description: Fixture package
CONTROL
printf 'config fixture\n' > "$tmp/ipk/data/etc/config/gl_modem_community"
tar -czf "$tmp/ipk/outer/control.tar.gz" -C "$tmp/ipk/control" ./control
tar -czf "$tmp/ipk/outer/data.tar.gz" -C "$tmp/ipk/data" .
printf '2.0\n' > "$tmp/ipk/outer/debian-binary"
tar -czf "$tmp/package.ipk" -C "$tmp/ipk/outer" control.tar.gz data.tar.gz debian-binary

make -C "$REPO_DIR" --no-print-directory generate-sbom \
	SBOM_FORMAT=ipk \
	SBOM_ARTIFACT="$tmp/package.ipk" \
	SBOM_OUTPUT="$tmp/ipk.cdx.json"
make -C "$REPO_DIR" --no-print-directory validate-sbom SBOM="$tmp/ipk.cdx.json"
make -C "$REPO_DIR" --no-print-directory generate-sbom \
	SBOM_FORMAT=ipk \
	SBOM_ARTIFACT="$tmp/package.ipk" \
	SBOM_OUTPUT="$tmp/ipk-second.cdx.json"
cmp "$tmp/ipk.cdx.json" "$tmp/ipk-second.cdx.json"
jq -e '.metadata.component.name == "gl-modem-community" and .metadata.component.version == "1.2.3-r1"' \
    "$tmp/ipk.cdx.json" >/dev/null
jq -e '([.components[] | select(.type == "library") | .name] | sort) == ["jq", "libc"]' \
    "$tmp/ipk.cdx.json" >/dev/null
jq -e '[.components[] | select(.type == "file") | .name] == ["/etc/config/gl_modem_community"]' \
    "$tmp/ipk.cdx.json" >/dev/null
