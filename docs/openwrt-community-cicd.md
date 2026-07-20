# OpenWrt community CI/CD patterns

Research date: 2026-07-20

This note compares active OpenWrt package repositories using their workflow source at fixed commits. The useful community convention is to build packages with an OpenWrt SDK action and publish immutable release assets. The community examples do not provide the complete contract needed here: automatic SemVer, generated changelog, APK and IPK build gate, and release creation only after both packages pass.

## Evidence

| Repository | Trigger and versioning | Build and publication | Security and failure behavior | Relevance |
| --- | --- | --- | --- | --- |
| [`openwrt/packages`](https://github.com/openwrt/packages/tree/0d0e892a6a93ff498c8f1f88e99eb86613d7ca25) | Pull requests only. Its thin workflow delegates to the official reusable workflow ([caller, lines 1-27](https://github.com/openwrt/packages/blob/0d0e892a6a93ff498c8f1f88e99eb86613d7ca25/.github/workflows/multi-arch-test-build.yml#L1-L27)). | The official workflow builds a multi-architecture matrix with `openwrt/gh-action-sdk@v11`, recognizes either `.apk` or `.ipk`, uploads packages and logs, and performs runtime tests where supported ([workflow, lines 20-107](https://github.com/openwrt/actions-shared-workflows/blob/2eeb2b6dd131b814f246133d7a0d80976c8abfc8/.github/workflows/multi-arch-test-build.yml#L20-L107), [lines 109-194](https://github.com/openwrt/actions-shared-workflows/blob/2eeb2b6dd131b814f246133d7a0d80976c8abfc8/.github/workflows/multi-arch-test-build.yml#L109-L194)). | The caller references the reusable workflow by floating `@main`; the reusable workflow uses version tags rather than commit pins. It is CI only and creates no release. | [CONFIRMED] This is the strongest primary-source precedent for SDK package validation and artifact retention, but it does not solve release automation. |
| [`immortalwrt/homeproxy`](https://github.com/immortalwrt/homeproxy/tree/7826c263609cf413c355eea6fd8cc1255b85f5c7) | Pushes and pull requests build artifacts. A separately published GitHub Release triggers the release path ([workflow, lines 1-33](https://github.com/immortalwrt/homeproxy/blob/7826c263609cf413c355eea6fd8cc1255b85f5c7/.github/workflows/build-ipk.yml#L1-L33)). | The same script builds APK and IPK. Non-release runs upload Actions artifacts; a `release: published` run uploads both files to the existing release using `github.token` ([lines 91-124](https://github.com/immortalwrt/homeproxy/blob/7826c263609cf413c355eea6fd8cc1255b85f5c7/.github/workflows/build-ipk.yml#L91-L124)). | Actions use floating major tags. Because the release exists before its build runs, this is not a build gate for release creation. | [CONFIRMED] This validates producing APK and IPK from one package source, but versioning and changelog creation remain manual. |
| [`sbwml/luci-app-mosdns`](https://github.com/sbwml/luci-app-mosdns/tree/e2d0877f0ce2553840d6aaf8a1f8578328910b25) | Any pushed tag starts a matrix for OpenWrt 24.10 and 25.12; the tag is the manually supplied version ([workflow, lines 1-6](https://github.com/sbwml/luci-app-mosdns/blob/e2d0877f0ce2553840d6aaf8a1f8578328910b25/.github/workflows/release-build.yml#L1-L6), [lines 48-50](https://github.com/sbwml/luci-app-mosdns/blob/e2d0877f0ce2553840d6aaf8a1f8578328910b25/.github/workflows/release-build.yml#L48-L50)). | `sbwml/openwrt-gh-action-sdk` builds the package, then each successful matrix cell uploads its archive with `ncipollo/release-action` ([lines 73-96](https://github.com/sbwml/luci-app-mosdns/blob/e2d0877f0ce2553840d6aaf8a1f8578328910b25/.github/workflows/release-build.yml#L73-L96)). | Action references are floating tags. Matrix publication can leave a release with only the successful architecture archives. | [CONFIRMED] This is a direct tag-to-packages model, without automatic SemVer, generated changelog, or an all-artifacts release gate. |
| [`nikkinikki-org/OpenWrt-nikki`](https://github.com/nikkinikki-org/OpenWrt-nikki/tree/cce63f83cd23cab2a0ea6b9471569dde1fcf60a5) | Manual dispatch or a `v*` tag starts releases across OpenWrt 24.10, 25.12, and snapshot ([workflow, lines 1-7](https://github.com/nikkinikki-org/OpenWrt-nikki/blob/cce63f83cd23cab2a0ea6b9471569dde1fcf60a5/.github/workflows/release-packages.yml#L1-L7), [lines 42-56](https://github.com/nikkinikki-org/OpenWrt-nikki/blob/cce63f83cd23cab2a0ea6b9471569dde1fcf60a5/.github/workflows/release-packages.yml#L42-L56)). | `openwrt/gh-action-sdk@main` builds signed package feeds. Tag runs upload GitHub Release archives, all runs retain artifacts, and a later job publishes a web feed ([lines 58-91](https://github.com/nikkinikki-org/OpenWrt-nikki/blob/cce63f83cd23cab2a0ea6b9471569dde1fcf60a5/.github/workflows/release-packages.yml#L58-L91), [lines 93-120](https://github.com/nikkinikki-org/OpenWrt-nikki/blob/cce63f83cd23cab2a0ea6b9471569dde1fcf60a5/.github/workflows/release-packages.yml#L93-L120)). | The matrix job has `continue-on-error: true`, so partial package publication is explicitly allowed; action references are floating. | [CONFIRMED] This is appropriate for a broad community feed, but its partial-success policy conflicts with the required APK+IPK release gate. |
| [`JeffResc/8311-exporter`](https://github.com/JeffResc/8311-exporter/tree/51baa3a6b21bbcccfa24b2e9b055c91cbbbdd85a) | Release Please runs on pushes to `main` and supplies SemVer/tag outputs ([workflow, lines 1-29](https://github.com/JeffResc/8311-exporter/blob/51baa3a6b21bbcccfa24b2e9b055c91cbbbdd85a/.github/workflows/release.yml#L1-L29)). | Artifacts and checksums are built and uploaded only after Release Please reports `release_created` ([lines 31-41](https://github.com/JeffResc/8311-exporter/blob/51baa3a6b21bbcccfa24b2e9b055c91cbbbdd85a/.github/workflows/release.yml#L31-L41), [lines 93-100](https://github.com/JeffResc/8311-exporter/blob/51baa3a6b21bbcccfa24b2e9b055c91cbbbdd85a/.github/workflows/release.yml#L93-L100)). | It uses the built-in token and floating action tags. The release is created before the package build, so a failed build leaves a release without the promised assets. | [CONFIRMED] This proves Release Please is used in an OpenWrt-adjacent package, but copying it would reproduce both the token-setting problem and the missing build gate. |

The examples show a practical split. Official OpenWrt CI is strongest at SDK-based package validation, while community CD usually begins from a manually pushed tag or an already-created release. [INFERENCE] Floating major tags are common community practice, but they are weaker than this repository's existing commit-pinned action policy and should not be copied.

## Why the current Release Please call is blocked

**Conclusion:** [CONFIRMED] The repository checkbox controls whether the repository's built-in `GITHUB_TOKEN` can create **and** approve pull requests. GitHub documents both capabilities as one setting ([source, lines 105-110](https://github.com/github/docs/blob/27a4008f193706042a40cbb6c71cf85633249e79/content/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository.md#L105-L110)). The failed Release Please run used `GITHUB_TOKEN`, so `pull-requests: write` in YAML could not override the repository-level restriction.

**Alternative explanations:** A missing workflow `pull-requests: write` permission produces a similar API failure, but the workflow already declares that permission. The reported GitHub error explicitly identifies the repository setting.

**How to verify dynamically:** Rerun the workflow after replacing only the Release Please credential. The release PR should be created while the combined repository checkbox remains disabled.

Release Please also documents that its default `GITHUB_TOKEN` does not trigger workflows from its PRs or tags and recommends a custom token when release PR CI must run ([Release Please README, lines 92-128](https://github.com/googleapis/release-please-action/blob/45996ed1f6d02564a971a2fa1b5860e934307cf7/README.md#L92-L128)). GitHub's own reusable documentation states the same general `GITHUB_TOKEN` event suppression rule ([source](https://github.com/github/docs/blob/27a4008f193706042a40cbb6c71cf85633249e79/data/reusables/actions/actions-do-not-trigger-workflows.md)). This matters because a Release Please PR should receive the repository's ordinary pull-request checks.

## Current repository state

[CONFIRMED] On 2026-07-20, `rudironsoni/gl-modem-community` enabled GitHub's combined "Allow GitHub Actions to create and approve pull requests" setting while keeping `default_workflow_permissions` set to `read`. This is the operational fallback used because no repository-scoped GitHub App credentials exist yet. Rerunning the original failure succeeded and created [release PR #1](https://github.com/rudironsoni/gl-modem-community/pull/1); [workflow attempt 2](https://github.com/rudironsoni/gl-modem-community/actions/runs/29728670622) is green.

This fallback is functional and matches the built-in-token Release Please pattern found in `8311-exporter`, but its combined repository setting grants broader authority than Release Please needs. The GitHub App design below is the recommended hardening path, not a prerequisite for the current release workflow.

## Recommended pattern

**Conclusion:** [HIGH] Keep the combined repository checkbox disabled. Give only the Release Please step a short-lived GitHub App installation token scoped to `rudironsoni/gl-modem-community`. Keep the current build-gated control flow and use the ordinary job-scoped `GITHUB_TOKEN` only for uploading assets after the release exists.

GitHub directs workflows to use a GitHub App installation token when `GITHUB_TOKEN` cannot provide the required permissions, with a personal access token as the alternative ([GitHub authentication guidance, lines 77-82](https://github.com/github/docs/blob/27a4008f193706042a40cbb6c71cf85633249e79/content/actions/tutorials/authenticate-with-github_token.md#L77-L82)). The official `actions/create-github-app-token` action documents repository variables/secrets and current-repository token generation ([README, lines 11-38](https://github.com/actions/create-github-app-token/blob/a8d616148505b5069dccd32f177bb87d7f39123b/README.md#L11-L38)). When `owner` and `repositories` are omitted, the token is limited to the current repository; the action recommends explicitly requesting permissions ([lines 327-340](https://github.com/actions/create-github-app-token/blob/a8d616148505b5069dccd32f177bb87d7f39123b/README.md#L327-L340)). The installation token expires after one hour and is revoked by the action's post step unless explicitly configured otherwise ([lines 15-16](https://github.com/actions/create-github-app-token/blob/a8d616148505b5069dccd32f177bb87d7f39123b/README.md#L15-L16), [lines 368-374](https://github.com/actions/create-github-app-token/blob/a8d616148505b5069dccd32f177bb87d7f39123b/README.md#L368-L374)).

Create a GitHub App installed only on `rudironsoni/gl-modem-community` with:

- Contents: read and write
- Pull requests: read and write
- Issues: read and write

Store the App ID as repository variable `RELEASE_APP_ID` and the private key as repository secret `RELEASE_APP_PRIVATE_KEY`. Then mint the token immediately before Release Please:

```yaml
release-please:
  permissions: {}
  steps:
    - name: Create release automation token
      id: release-token
      uses: actions/create-github-app-token@a8d616148505b5069dccd32f177bb87d7f39123b # v2.1.1
      with:
        app-id: ${{ vars.RELEASE_APP_ID }}
        private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
        permission-contents: write
        permission-issues: write
        permission-pull-requests: write

    - name: Run Release Please
      id: release
      uses: googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0
      with:
        token: ${{ steps.release-token.outputs.token }}
        config-file: release-please-config.json
        manifest-file: .release-please-manifest.json
```

Do not pass `owner` or `repositories` to `create-github-app-token`. That preserves its documented current-repository scope. The `publish-assets` job should continue using `GITHUB_TOKEN` with only `contents: write`; it does not need pull-request authority.

The release ordering should remain:

1. A normal `main` push uses the App token to create or update the Release Please PR.
2. The App-authored PR triggers ordinary pull-request CI.
3. Merging that PR changes the release manifest.
4. The workflow detects the manifest change and requires both APK and IPK builds to pass.
5. Only then does Release Please create the tag and GitHub Release.
6. The asset job uploads the exact APK, IPK, and `SHA256SUMS` files.

This ordering retains the community's SDK package-build convention while tightening its release semantics. A release cannot be created after either package build fails.

## Tradeoffs and fallback

| Option | Security | Automation behavior | Decision |
| --- | --- | --- | --- |
| Repository-scoped GitHub App installation token | Short-lived, installation-scoped, not tied to a user; the App private key is the durable secret. | Can create/update the Release Please PR and allows ordinary PR workflows to run. Leaves the combined `GITHUB_TOKEN` create/approve setting disabled. | **Recommended.** |
| Fine-grained personal access token | Can be restricted to this repository and the same three permissions, but remains tied to Rudi's user identity and should have an expiration. | Solves PR creation and workflow-trigger suppression with less initial setup. | Acceptable temporary fallback. |
| Enable "Allow GitHub Actions to create and approve pull requests" | Grants the repository's built-in workflow token both capabilities represented by the combined checkbox. | Immediate fix with no extra credential, but it broadens what compromised write-capable workflows may do. | Avoid because the GitHub App pattern satisfies the goal with narrower authority. |
| Manual version tag and release | No release automation credential. | Matches many community repositories, but loses automatic SemVer, generated changelog, and the Release Please PR review point. | Does not meet the requested contract. |

**Remaining external prerequisite:** [UNVERIFIED] The GitHub App, installation, variable, and private-key secret do not yet exist unless configured separately. Their presence and exact permissions must be read back from GitHub before declaring the fix operational.

**Dynamic validation:** Keep the combined repository setting disabled, push a Conventional Commit, and verify that Release Please creates a PR whose checks run. Merge the release PR only after those checks pass. Confirm that a deliberately failing APK or IPK build prevents the tag and release, then restore the build and verify the release contains exactly the APK, IPK, and `SHA256SUMS` assets.
