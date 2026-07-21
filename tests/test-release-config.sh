#!/bin/sh
set -eu

unset CDPATH
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONFIG="$REPO_DIR/release-please-config.json"
MANIFEST="$REPO_DIR/.release-please-manifest.json"
PACKAGE_MAKEFILE="$REPO_DIR/package/gl-modem-community/Makefile"
CI_WORKFLOW="$REPO_DIR/.github/workflows/ci.yml"
RELEASE_WORKFLOW="$REPO_DIR/.github/workflows/release.yml"
SIGNING_SCRIPT="$REPO_DIR/scripts/sign-apk-release.sh"
PUBLIC_KEY="$REPO_DIR/keys/gl-modem-community.pem"
PUBLIC_KEY_CHECKSUM="$PUBLIC_KEY.sha256"

jq -e '
  .["release-type"] == "simple" and
  .["include-component-in-tag"] == false and
  .["include-v-in-tag"] == true and
  .["include-v-in-release-name"] == true and
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
  type == "object" and ((length == 0) or (. == {".": $version}))
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
grep -Fq 'target: package' "$CI_WORKFLOW"
grep -Fq 'target: package-opkg' "$CI_WORKFLOW"
grep -Fq 'if: inputs.upload_packages' "$CI_WORKFLOW"
grep -Fq 'path: ${{ matrix.sdk_archive }}' "$CI_WORKFLOW"
if grep -Fq 'tool-cache/sdk-*' "$CI_WORKFLOW"; then
    echo 'CI must not cache root-owned extracted SDK files' >&2
    exit 1
fi

grep -Fq 'description: Existing release tag to rebuild and republish' "$RELEASE_WORKFLOW"
grep -Fq 'test "$(git describe --tags --exact-match HEAD)" = "$tag"' "$RELEASE_WORKFLOW"
grep -Fq 'gh release view "$tag"' "$RELEASE_WORKFLOW"
grep -Fq 'source_ref="$tag"' "$RELEASE_WORKFLOW"
grep -Fq 'environment: release-signing' "$RELEASE_WORKFLOW"
grep -Fq 'APK_SIGNING_PRIVATE_KEY: ${{ secrets.APK_SIGNING_PRIVATE_KEY }}' "$RELEASE_WORKFLOW"
grep -Fq 'fail-on-cache-miss: true' "$RELEASE_WORKFLOW"
grep -Fq 'name: Extract APK SDK' "$RELEASE_WORKFLOW"
grep -Fq '/repo/scripts/sign-apk-release.sh' "$RELEASE_WORKFLOW"
grep -Fq 'actions/attest@' "$RELEASE_WORKFLOW"
grep -Fq 'gh workflow run ci.yml' "$RELEASE_WORKFLOW"
grep -Fq 'needs.sign-release.result == '\''success'\''' "$RELEASE_WORKFLOW"
grep -Fq 'release-assets/packages.adb' "$RELEASE_WORKFLOW"
grep -Fq 'adbsign' "$SIGNING_SCRIPT"
grep -Fq 'mkndx' "$SIGNING_SCRIPT"
grep -Fq 'verify --keys-dir' "$SIGNING_SCRIPT"
grep -Fq 'empty-keys' "$SIGNING_SCRIPT"

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
