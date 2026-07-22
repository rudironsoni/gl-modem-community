# Repository Guidelines

## Scope and Architecture

`gl-modem-community` extends GL.iNet's stock cellular stack with community modem definitions and narrow compatibility drivers. It is not a standalone modem manager for vanilla OpenWrt. The tested reference is GL-MT3000 (Beryl AX) with Fibocom FM350-GL; keep other router and modem claims marked `[UNVERIFIED]` until they are observed on hardware.

The package must remain additive. Preserve GL.iNet's stock JSON-RPC, ubus, web UI, mobile app backend, built-in modem definitions, and fallback paths. Runtime overlays must leave SquashFS unchanged and restore stock behavior when `gl_modem_community` stops or is removed.

## Repository Layout

- `package/gl-modem-community/`: OpenWrt package definition.
- `package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/`: additive modem JSON fragments.
- `package/gl-modem-community/files/lib/netifd/proto/` and `files/etc/gcom/`: data protocols and AT scripts.
- `package/gl-modem-community/files/usr/share/gl-modem-community/rpc-drivers/`: USB-ID-specific RPC handlers.
- `package/gl-modem-community/files/usr/libexec/gl-modem-community/`: narrow compatibility helpers.
- `package/gl-modem-community/src/`: compiled compatibility code.
- `scripts/`: analysis, build, signing, and SBOM automation.
- `tests/`: deterministic regression and release-contract tests.
- `tools/`: pinned Docker build environments.
- `keys/`: public APK signing material only.
- `docs/`: design and validation documentation.
- `analysis/`: reproducible clean-room evidence. Do not treat generated analysis output as source code.

Firmware images, extracted proprietary files, SDK caches, build work, private keys, and generated packages must remain untracked.

## Build and Validation

Docker is required. Use the repository-owned commands:

- `make tools`: build the pinned analysis container.
- `make test`: run shell syntax checks, ShellCheck, Lua parsing, JSON assertions, signing checks, SBOM validation, and focused regressions.
- `make package`: build the APK with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK.
- `make package-opkg`: build the IPK with the pinned OpenWrt 24.10.7 MediaTek Filogic SDK.
- `make download verify extract inventory analyze report`: reproduce the firmware-analysis pipeline in order.
- `git diff --check`: reject whitespace errors.

Run `make test` for every change. Run both package builds when package contents, metadata, install behavior, signing, feeds, or release automation changes. Do not substitute unpinned SDKs or silently update firmware checksums.

## Coding and Extension Rules

Write portable POSIX `sh` compatible with BusyBox `ash`. Use tabs only for Make recipes and preserve surrounding indentation elsewhere. Use lowercase kebab-case for scripts, `test-<behavior>.sh` for shell tests, and existing OpenWrt naming for package files. Keep C code C11-compatible. Validate JSON with `jq` and Lua with `luac5.1`.

Add modem behavior at the narrowest extension point. Do not turn FM350-specific offsets, AT behavior, RPC handling, or network repair into global behavior. Add focused regression coverage and register new tests in `tests/run.sh`.

## APK Feed and Signing Contract

The stable public key paths are:

- `keys/gl-modem-community.pem`
- `keys/gl-modem-community.pem.sha256`

Do not add dates or release versions to key filenames. Key rotation requires a documented fingerprint, an overlap period, and an explicit migration plan. Never commit the private key or print it in logs. GitHub Actions reads `APK_SIGNING_PRIVATE_KEY` only from the protected `release-signing` environment.

The stable APK feed is:

`https://github.com/rudironsoni/gl-modem-community/releases/latest/download/packages.adb`

The release workflow signs both the APK and `packages.adb`, publishes the public key and checksum, generates CycloneDX SBOMs, and creates GitHub provenance attestations. User-facing installation must verify the key and use normal trust validation. Never recommend `--allow-untrusted`.

LuCI is the intended feed installation path after the one-time public-key bootstrap. Keep README instructions aligned with **System → Software → Configure apk**, `/etc/apk/repositories.d/customfeeds.list`, **Update lists…**, package search, installation, and service activation. If LuCI exposes **Configure opkg**, the APK feed is not compatible with that firmware.

## CI and Releases

`.github/workflows/ci.yml` is the pull-request gate. The stable required check is `CI required`; offline tests and both APK/IPK builds must succeed beneath it. Keep actions pinned to immutable commit SHAs, permissions minimal, checkout credentials disabled, and SDK caches limited to readable archives.

`.github/workflows/release.yml` reuses CI, signs release artifacts, validates SBOMs, attests assets, and lets Release Please publish only after required build and signing work succeeds. Conventional Commits drive Release Please. Manual `workflow_dispatch` with an exact existing tag is a recovery path, not the normal release path.

Do not weaken signing, checks, branch protection, or provenance to make a release pass. Diagnose the failing layer and rerun the original workflow after the fix.

## Evidence and Security Boundaries

Keep the repository clean-room. Never commit GL.iNet firmware, proprietary binaries, credentials, local caches, generated packages, or machine-specific state. Cite public upstream behavior when adapting community drivers. Separate confirmed hardware evidence from inference, redact identifiers, and preserve literal USB IDs, firmware versions, package names, hashes, and error text.

## Git and Pull Requests

Use Conventional Commits and repository branch conventions. Keep each commit to one reviewed logical change. Before publishing, inspect the worktree, staged diff, remotes, current branch, and nested repositories; preserve unrelated user changes.

Pull requests must explain the affected modem IDs and firmware scope, the user-visible behavior, the implementation boundary, exact validation commands, and any remaining hardware uncertainty. UI-visible changes should include screenshots when practical.

