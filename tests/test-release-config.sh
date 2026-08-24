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
FEED_ASSEMBLER="$REPO_DIR/tools/assemble-release-feeds"
PUBLIC_KEY="$REPO_DIR/keys/gl-modem-community.pem"
PUBLIC_KEY_CHECKSUM="$PUBLIC_KEY.sha256"

jq -e '
  .["release-type"] == "node" and
  .["include-component-in-tag"] == false and
  .["include-v-in-tag"] == true and
  .["include-v-in-release-name"] == true and
  .["skip-github-release"] == true and
  (.["last-release-sha"] == null or
    .["last-release-sha"] == "4fd19430c33adef637ee25a68c3dbea0a757e815") and
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
grep -Fq 'kind: apk' "$CI_WORKFLOW"
grep -Fq 'if: inputs.upload_packages' "$CI_WORKFLOW"
grep -Fq 'path: ${{ matrix.sdk_archive }}' "$CI_WORKFLOW"
if grep -Fq 'tool-cache/sdk-*' "$CI_WORKFLOW"; then
    echo 'CI must not cache root-owned extracted SDK files' >&2
    exit 1
fi

# Release Please owns version changes; publication only follows a manifest bump.
grep -Fq 'name: Release' "$RELEASE_WORKFLOW"
grep -Fq 'push:' "$RELEASE_WORKFLOW"
grep -Fq 'workflow_dispatch:' "$RELEASE_WORKFLOW"
grep -Fq 'group: release-main' "$RELEASE_WORKFLOW"
grep -Fq 'cancel-in-progress: false' "$RELEASE_WORKFLOW"
grep -Fq 'googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0' "$RELEASE_WORKFLOW"
grep -Fq 'config-file: release-please-config.json' "$RELEASE_WORKFLOW"
grep -Fq 'manifest-file: .release-please-manifest.json' "$RELEASE_WORKFLOW"
grep -Fq 'name: Require repository auto-merge' "$RELEASE_WORKFLOW"
grep -Fq "'.allow_auto_merge'" "$RELEASE_WORKFLOW"
grep -Fq 'Enable Settings > General > Pull Requests > Allow auto-merge' "$RELEASE_WORKFLOW"
grep -Fq 'name: Reconcile historical Release Please labels' "$RELEASE_WORKFLOW"
grep -Fq -- "--remove-label 'autorelease: pending'" "$RELEASE_WORKFLOW"
grep -Fq -- "--add-label 'autorelease: tagged'" "$RELEASE_WORKFLOW"
grep -Fq 'Release Please baseline migration did not create a release PR' "$RELEASE_WORKFLOW"
grep -Fq 'gh release view "v${version}"' "$RELEASE_WORKFLOW"
grep -Fq 'Retagging merged release PR #' "$RELEASE_WORKFLOW"
grep -Fq 'if gh release view "$tag"' "$RELEASE_WORKFLOW"
grep -Fq 'if [[ ! -s "$release_file" ]]' "$RELEASE_WORKFLOW"
grep -Fq "release_commit == 'true'" "$RELEASE_WORKFLOW"
grep -Fq 'Exact existing release tag to rebuild' "$RELEASE_WORKFLOW"
grep -Fq 'gh release view "$tag"' "$RELEASE_WORKFLOW"
grep -Fq 'test "$(git describe --tags --exact-match HEAD)" = "$tag"' "$RELEASE_WORKFLOW"

# The proposed release is built, signed, revalidated, and automatically merged.
grep -Fq 'name: Build proposed release' "$RELEASE_WORKFLOW"
grep -Fq 'name: Add signed feeds to release PR' "$RELEASE_WORKFLOW"
grep -Fq 'name: Merge validated release PR' "$RELEASE_WORKFLOW"
grep -Fq 'source_ref: ${{ needs.release-please.outputs.pr_sha }}' "$RELEASE_WORKFLOW"
grep -Fq 'ref: ${{ needs.release-please.outputs.pr_sha }}' "$RELEASE_WORKFLOW"
grep -Fq 'Release Please branch advanced from $RELEASE_SHA to $remote_sha' "$RELEASE_WORKFLOW"
grep -Fq "jq 'del(.[\"last-release-sha\"])' release-please-config.json" "$RELEASE_WORKFLOW"
grep -Fq 'sh tools/assemble-release-feeds "$version" release-assets feed' "$RELEASE_WORKFLOW"
grep -Fq 'git push origin "HEAD:refs/heads/${RELEASE_BRANCH}"' "$RELEASE_WORKFLOW"
grep -Fq 'gh workflow run ci.yml' "$RELEASE_WORKFLOW"
grep -Fq 'ci_run_id: ${{ steps.feed.outputs.ci_run_id }}' "$RELEASE_WORKFLOW"
grep -Fq 'feed_sha: ${{ steps.feed.outputs.feed_sha }}' "$RELEASE_WORKFLOW"
grep -Fq 'version: ${{ steps.feed.outputs.version }}' "$RELEASE_WORKFLOW"
grep -Fq 'gh run watch "$CI_RUN_ID"' "$RELEASE_WORKFLOW"
grep -Fq '.headSha == $sha and' "$RELEASE_WORKFLOW"
grep -Fq '.conclusion == "success"' "$RELEASE_WORKFLOW"
grep -Fq 'pull-requests: write' "$RELEASE_WORKFLOW"
grep -Fq 'gh pr merge "$pr_number"' "$RELEASE_WORKFLOW"
grep -Fq -- '--auto' "$RELEASE_WORKFLOW"
grep -Fq -- '--match-head-commit "$FEED_SHA"' "$RELEASE_WORKFLOW"
grep -Fq 'release_sha: ${{ steps.merge.outputs.release_sha }}' "$RELEASE_WORKFLOW"
grep -Fq 'Merged release feeds do not match validated feed commit' "$RELEASE_WORKFLOW"
grep -Fq "needs.merge-release-pr.result == 'success'" "$RELEASE_WORKFLOW"
grep -Fq 'needs.merge-release-pr.outputs.release_sha || needs.detect-release.outputs.source_ref' "$RELEASE_WORKFLOW"
grep -Fq 'name: Mark automated release PR as tagged' "$RELEASE_WORKFLOW"
! grep -Fq "if: needs.merge-release-pr.outputs.release_pr_number != ''" "$RELEASE_WORKFLOW"
grep -Fq -- "--add-label 'autorelease: tagged'" "$RELEASE_WORKFLOW"
grep -Fq -- "--remove-label 'autorelease: pending'" "$RELEASE_WORKFLOW"
dispatch_line=$(grep -nF 'gh workflow run ci.yml' "$RELEASE_WORKFLOW" | cut -d: -f1)
watch_line=$(grep -nF 'gh run watch "$CI_RUN_ID"' "$RELEASE_WORKFLOW" | cut -d: -f1)
auto_merge_line=$(grep -nF 'name: Require repository auto-merge' "$RELEASE_WORKFLOW" | cut -d: -f1)
merge_line=$(grep -nF 'gh pr merge "$pr_number"' "$RELEASE_WORKFLOW" | cut -d: -f1)
publish_line=$(grep -nF 'uses: softprops/action-gh-release@' "$RELEASE_WORKFLOW" | cut -d: -f1)
test "$dispatch_line" -lt "$watch_line"
test "$watch_line" -lt "$auto_merge_line"
test "$watch_line" -lt "$merge_line"
test "$merge_line" -lt "$publish_line"
if grep -Fq 'git push origin main' "$RELEASE_WORKFLOW"; then
	echo 'Release workflow must not bypass pull-request-only main protection' >&2
	exit 1
fi

# The merged feed packages are the exact GitHub Release inputs.
grep -Fq 'softprops/action-gh-release@' "$RELEASE_WORKFLOW"
grep -Fq 'actions/download-artifact@' "$RELEASE_WORKFLOW"
grep -Fq 'feed/releases/25.12/packages/aarch64_cortex-a53/packages' "$RELEASE_WORKFLOW"
grep -Fq 'feed/releases/24.10/packages/aarch64_cortex-a53/packages' "$RELEASE_WORKFLOW"
grep -Fq 'feed/releases/21.02/packages/aarch64_cortex-a53/packages' "$RELEASE_WORKFLOW"
grep -Fq 'feed/releases/21.02/packages/aarch64_cortex-a53_neon-vfpv4/packages' "$RELEASE_WORKFLOW"
grep -Fq 'packages.adb' "$RELEASE_WORKFLOW"
grep -Fq 'actions/checkout@' "$RELEASE_WORKFLOW"
grep -Fq 'actions/attest@f7c74d28b9d84cb8768d0b8ca14a4bac6ef463e6 # v4.2.0' "$RELEASE_WORKFLOW"
grep -Fq 'target_commitish: ${{ needs.merge-release-pr.outputs.release_sha || needs.detect-release.outputs.source_sha }}' "$RELEASE_WORKFLOW"
grep -Fq 'SBOM_FORMAT=apk' "$RELEASE_WORKFLOW"
grep -Fq 'gl-modem-community.glinet21.ipk.cdx.json' "$RELEASE_WORKFLOW"
grep -Fq '(.packages // .) as $packages' "$RELEASE_WORKFLOW"
grep -Fq '.metadata.component.version == $version' "$RELEASE_WORKFLOW"
grep -Fq 'sha256sum -c gl-modem-community.pem.sha256' "$RELEASE_WORKFLOW"
test "$(grep -Fc '"${RELEASE_VERSION}-1" all' "$RELEASE_WORKFLOW")" -eq 1
test "$(grep -Fc '"${RELEASE_VERSION}-r1" all' "$RELEASE_WORKFLOW")" -eq 1
test "$(grep -Fc '"${RELEASE_VERSION}-r1" noarch' "$RELEASE_WORKFLOW")" -eq 1

BASE_FEED_DEPENDS="printf 'Depends: comgt, flock, jq, kmod-usb-acm, kmod-usb-serial-option, kmod-usb-net-rndis\\n'"
test "$(grep -Fc "$BASE_FEED_DEPENDS" "$FEED_ASSEMBLER")" -eq 1
test "$(grep -Fc "printf 'SHA256sum: %s" "$FEED_ASSEMBLER")" -eq 1
grep -Fq "printf 'Architecture: all" "$FEED_ASSEMBLER"

# APK signing runs in the protected environment and publishes the key material.
grep -Fq 'environment: release-signing' "$RELEASE_WORKFLOW"
grep -Fq 'APK_SIGNING_PRIVATE_KEY' "$RELEASE_WORKFLOW"
grep -Fq 'prepare-apk-sdk' "$RELEASE_WORKFLOW"
grep -Fq 'sign-apk-release' "$RELEASE_WORKFLOW"
grep -Fq 'keys/gl-modem-community.pem' "$RELEASE_WORKFLOW"
grep -Fq 'SHA256SUMS' "$RELEASE_WORKFLOW"
grep -Fq 'generate-feed-index FEED_DIR="$FEED_DIR"' "$FEED_ASSEMBLER"

# IPK Packages indexes are usign-signed with the dedicated stable key.
grep -Fq 'test -n "$USIGN_SIGNING_PRIVATE_KEY"' "$RELEASE_WORKFLOW"
grep -Fq 'USIGN_SIGNING_PRIVATE_KEY' "$RELEASE_WORKFLOW"
grep -Fq 'keys/gl-modem-community-usign.pub' "$RELEASE_WORKFLOW"
grep -Fq 'sha256sum -c gl-modem-community-usign.pub.sha256' "$RELEASE_WORKFLOW"
grep -Fq 'USIGN_SEC_FILE' "$FEED_ASSEMBLER"
grep -Fq 'keys/gl-modem-community-usign.pub' "$FEED_ASSEMBLER"
grep -Fq '"$1.sig"' "$FEED_ASSEMBLER"
grep -Fq '$USIGN_KEY_ID.pub' "$FEED_ASSEMBLER"
test -s "$REPO_DIR/keys/gl-modem-community-usign.pub"
test -s "$REPO_DIR/keys/gl-modem-community-usign.pub.sha256"

grep -Fq 'sign-apk-release:' "$ROOT_MAKEFILE"
grep -Fq 'adbsign' "$ROOT_MAKEFILE"
grep -Fq 'mkndx' "$ROOT_MAKEFILE"
grep -Fq 'verify --keys-dir' "$ROOT_MAKEFILE"
grep -Fq 'empty-keys' "$ROOT_MAKEFILE"
grep -Fq 'prepare-apk-sdk:' "$ROOT_MAKEFILE"
grep -Fq 'generate-feed-index:' "$ROOT_MAKEFILE"
grep -Fq 'tools/generate-feed-index "$(FEED_DIR)" "$(FEED_URL)"' "$ROOT_MAKEFILE"

# README contains every feed URL
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/releases/25.12/packages/aarch64_cortex-a53/packages/packages.adb' "$REPO_DIR/README.md"
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/releases/24.10/packages/aarch64_cortex-a53/packages' "$REPO_DIR/README.md"
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/releases/21.02/packages/aarch64_cortex-a53/packages' "$REPO_DIR/README.md"
grep -Fq 'https://github.rudironsoni.com/gl-modem-community/feed/releases/21.02/packages/aarch64_cortex-a53_neon-vfpv4/packages' "$REPO_DIR/README.md"
if grep -Fq 'releases/latest/download/SHA256SUMS' "$REPO_DIR/README.md"; then
	echo 'Versioned package instructions must fetch checksums from the same release tag' >&2
	exit 1
fi

test ! -d "$REPO_DIR/scripts"
test -s "$PUBLIC_KEY"
test -s "$PUBLIC_KEY_CHECKSUM"
openssl pkey -pubin -in "$PUBLIC_KEY" -noout
(
    cd "$(dirname "$PUBLIC_KEY")"
    sha256sum -c "$(basename "$PUBLIC_KEY_CHECKSUM")"
    sha256sum -c gl-modem-community-usign.pub.sha256
)
grep -Fq '79b5dc268b4698f5' "$REPO_DIR/README.md"

if grep -RFn --include='*.md' -- '--allow-untrusted' "$REPO_DIR/README.md" "$REPO_DIR/docs"; then
    echo 'Documentation must not instruct users to bypass APK signature verification' >&2
    exit 1
fi
