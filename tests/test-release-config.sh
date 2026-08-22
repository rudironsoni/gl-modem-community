#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONFIG="$REPO_DIR/release-please-config.json"
MANIFEST="$REPO_DIR/.release-please-manifest.json"
PACKAGE_MAKEFILE="$REPO_DIR/package/gl-modem-community/Makefile"
CI_WORKFLOW="$REPO_DIR/.github/workflows/ci.yml"
RELEASE_WORKFLOW="$REPO_DIR/.github/workflows/release.yml"
ROOT_MAKEFILE="$REPO_DIR/Makefile"
PUBLIC_KEY="$REPO_DIR/keys/gl-modem-community.pem"
PUBLIC_KEY_CHECKSUM="$PUBLIC_KEY.sha256"

jq -e '
  .["release-type"] == "node" and
  .["include-component-in-tag"] == false and
  .["include-v-in-tag"] == true and
  .["include-v-in-release-name"] == true and
  .["skip-github-release"] == true and
  .packages["."]["package-name"] == "gl-modem-community" and
  .packages["."]["extra-files"] == [
    {"type":"generic","path":"package/gl-modem-community/Makefile"}
  ] and
  ([.["changelog-sections"][].type] | sort) ==
    (["build", "chore", "ci", "docs", "feat", "fix", "perf", "refactor", "revert", "style", "test"] | sort) and
  all(.["changelog-sections"][]; .hidden == false)
' "$CONFIG" >/dev/null

test "$(grep -c '^# x-release-please-start-version$' "$PACKAGE_MAKEFILE")" -eq 1
test "$(grep -c '^# x-release-please-end$' "$PACKAGE_MAKEFILE")" -eq 1
PACKAGE_VERSION=$(sed -n 's/^PKG_VERSION:=//p' "$PACKAGE_MAKEFILE")
printf '%s\n' "$PACKAGE_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$'
jq -e --arg version "$PACKAGE_VERSION" '
  type == "object" and ((length == 0) or (."." | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+")))
' "$MANIFEST" >/dev/null

for workflow in "$REPO_DIR"/.github/workflows/*.yml; do
    sed -n 's/^[[:space:]]*uses:[[:space:]]*//p' "$workflow" | while IFS= read -r use; do
        case "$use" in
            ./*|docker://*) continue ;;
        esac
        if ! printf '%s\n' "$use" | grep -Eq '^[^@]+@[0-9a-f]{40}[[:space:]]+# v[0-9]'; then
            echo "Workflow action is not pinned to an immutable SHA: $use" >&2
            exit 1
        fi
    done
done

checkout_count=$(grep -RhEc 'uses: actions/checkout@[0-9a-f]{40}' "$REPO_DIR/.github/workflows" | awk '{sum += $1} END {print sum}')
credential_count=$(grep -RhEc 'persist-credentials: false' "$REPO_DIR/.github/workflows" | awk '{sum += $1} END {print sum}')
test "$checkout_count" -eq "$credential_count"

grep -Fq 'pull_request:' "$CI_WORKFLOW"
grep -Fq 'workflow_call:' "$CI_WORKFLOW"
grep -Fq 'workflow_dispatch:' "$CI_WORKFLOW"
grep -Fq 'name: CI required' "$CI_WORKFLOW"
grep -Fq 'kind: ipk' "$CI_WORKFLOW"
grep -Fq 'kind: ipk-glinet21' "$CI_WORKFLOW"
grep -Fq 'kind: ipk-be3600' "$CI_WORKFLOW"
grep -Fq 'kind: apk' "$CI_WORKFLOW"
grep -Fq 'package-be3600: SDK_NAME = openwrt-sdk-23.05.5-ipq807x-generic' "$ROOT_MAKEFILE"
grep -Fq 'if: inputs.upload_packages' "$CI_WORKFLOW"
grep -Fq 'path: ${{ matrix.sdk_archive }}' "$CI_WORKFLOW"
if grep -Fq 'tool-cache/sdk-*' "$CI_WORKFLOW"; then
    echo 'CI must not cache root-owned extracted SDK files' >&2
    exit 1
fi

# Release workflow checks (simplified for new workflow)
grep -Fq 'name: Release' "$RELEASE_WORKFLOW"
grep -Fq 'push:' "$RELEASE_WORKFLOW"
grep -Fq 'workflow_dispatch:' "$RELEASE_WORKFLOW"
grep -Fq 'needs: build' "$RELEASE_WORKFLOW"
grep -Fq 'softprops/action-gh-release@' "$RELEASE_WORKFLOW"
grep -Fq 'actions/upload-artifact@' "$RELEASE_WORKFLOW"
grep -Fq 'actions/download-artifact@' "$RELEASE_WORKFLOW"
grep -Fq 'publish-feeds' "$RELEASE_WORKFLOW"
grep -Fq 'feed/25.12' "$RELEASE_WORKFLOW"
grep -Fq 'feed/24.10' "$RELEASE_WORKFLOW"
grep -Fq 'feed/21.02' "$RELEASE_WORKFLOW"
grep -Fq 'feed/23.05-be3600' "$RELEASE_WORKFLOW"
grep -Fq 'Packages.gz' "$RELEASE_WORKFLOW"
grep -Fq 'packages.adb' "$RELEASE_WORKFLOW"
grep -Fq 'actions/checkout@' "$RELEASE_WORKFLOW"

BASE_FEED_DEPENDS="printf 'Depends: comgt, flock, jq, kmod-usb-acm, kmod-usb-serial-option, kmod-usb-net-rndis\\n'"
BE3600_FEED_DEPENDS="printf 'Depends: adb, comgt, flock, jq, kmod-usb-acm, kmod-usb-serial-option, kmod-usb-net-qmi-wwan, kmod-usb-net-rndis, lua, luci-lib-nixio, uqmi\\n'"
test "$(grep -Fc "$BASE_FEED_DEPENDS" "$RELEASE_WORKFLOW")" -eq 2
test "$(grep -Fc "$BE3600_FEED_DEPENDS" "$RELEASE_WORKFLOW")" -eq 1

# APK signing runs in the protected environment and publishes the key material.
grep -Fq 'environment: release-signing' "$RELEASE_WORKFLOW"
grep -Fq 'APK_SIGNING_PRIVATE_KEY' "$RELEASE_WORKFLOW"
grep -Fq 'prepare-apk-sdk' "$RELEASE_WORKFLOW"
grep -Fq 'sign-apk-release' "$RELEASE_WORKFLOW"
grep -Fq 'generate-feed-index' "$RELEASE_WORKFLOW"
grep -Fq 'keys/gl-modem-community.pem' "$RELEASE_WORKFLOW"
grep -Fq 'SHA256SUMS' "$RELEASE_WORKFLOW"

grep -Fq 'sign-apk-release:' "$ROOT_MAKEFILE"
grep -Fq 'adbsign' "$ROOT_MAKEFILE"
grep -Fq 'mkndx' "$ROOT_MAKEFILE"
grep -Fq 'verify --keys-dir' "$ROOT_MAKEFILE"
grep -Fq 'empty-keys' "$ROOT_MAKEFILE"
grep -Fq 'prepare-apk-sdk:' "$ROOT_MAKEFILE"
grep -Fq 'generate-feed-index:' "$ROOT_MAKEFILE"
grep -Fq '23.05-be3600)' "$ROOT_MAKEFILE"

# README contains every feed URL
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/25.12' "$REPO_DIR/README.md"
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/24.10' "$REPO_DIR/README.md"
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/21.02' "$REPO_DIR/README.md"
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/23.05-be3600' "$REPO_DIR/README.md"

test ! -d "$REPO_DIR/scripts"
test -s "$PUBLIC_KEY"
test -s "$PUBLIC_KEY_CHECKSUM"
openssl pkey -pubin -in "$PUBLIC_KEY" -noout
(
    cd "$(dirname "$PUBLIC_KEY")"
    sha256sum -c "$(basename "$PUBLIC_KEY_CHECKSUM")"
)

if grep -RFn --include='*.md' -- '--allow-untrusted' "$REPO_DIR/README.md" "$REPO_DIR/docs"; then
    echo 'Documentation must not instruct users to bypass APK signature verification' >&2
    exit 1
fi
