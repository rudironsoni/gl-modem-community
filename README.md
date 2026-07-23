# gl-modem-community

[![Latest release](https://img.shields.io/github/v/release/rudironsoni/gl-modem-community)](https://github.com/rudironsoni/gl-modem-community/releases/latest)
[![Release](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml)
[![CI](https://github.com/rudironsoni/gl-modem-community/actions/workflows/ci.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/ci.yml)

`gl-modem-community` adds community modem definitions and narrow compatibility drivers to GL.iNet's stock cellular stack. It keeps GL.iNet's web UI, mobile-app backend, JSON-RPC, ubus interfaces, and built-in modem support in place. The package is an additive runtime overlay, so stopping or removing it exposes the stock firmware again.

The first driver targets the Fibocom FM350-GL on the GL.iNet GL-MT3000 (Beryl AX). It depends on GL.iNet's proprietary cellular services and is not a modem manager for vanilla OpenWrt.

> [!WARNING]
> This is experimental software. FM350-GL detection and UI visibility have been observed on the reference router, but the full data-session and recovery matrix has not passed yet.

## Features

- **FM350-GL model support** for USB IDs `0e8d:7126` and `0e8d:7127`, including the product-specific `ttyUSB` AT-port offsets observed on the GL-MT3000.
- **Non-invasive integration** that adds modem definitions, protocol scripts, and FM350-specific compatibility helpers without replacing GL.iNet's cellular stack.
- **Stock UI and API compatibility** that preserves the existing GL.iNet web UI, mobile app, JSON-RPC, and ubus paths.
- **Clean rollback** that removes runtime mounts and restores package-owned network settings when the service stops or the package is removed.

## Compatibility

A package build proves that the pinned SDK produced an artifact. It does not prove that the package works on a router.

| Firmware scope | Package format | Build status | Hardware status |
| --- | --- | --- | --- |
| GL.iNet OpenWrt 25 on GL-MT3000 | APK | Builds with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK | FM350-GL partially tested |
| GL.iNet OEM or OpenWrt 24 on GL-MT3000 | IPK | Builds with the pinned OpenWrt 24.10.7 MediaTek Filogic SDK | Not tested |
| Other GL.iNet routers | Target-specific package required | Not built | Not tested |
| Vanilla OpenWrt | Not applicable | GL.iNet cellular services are absent | Unsupported |

The OpenWrt 25 hardware work has confirmed FM350-GL USB detection, `ttyUSB` enumeration in observed RNDIS compositions, product-specific AT offsets, SIM identity reads through the stock common driver, and modem visibility in the GL.iNet web UI and mobile app.

PDP activation, sustained data connectivity, interface addressing, routes, DNS, USB re-enumeration, and GL.iNet OEM/OpenWrt 24 behavior still need hardware validation. Follow the [hardware validation plan](docs/validation-plan.md) before treating a data session as verified.

## Hardware evidence

These screenshots show the FM350-GL in the GL.iNet admin panel and mobile app on the reference GL-MT3000. They prove detection and UI visibility. They do not prove that the modem completed a data session. IMEI and SIM details are redacted.

| GL.iNet admin panel | GL.iNet mobile app |
| --- | --- |
| ![GL-MT3000 admin panel showing FM350-GL cellular connection](docs/images/gl-mt3000-fm350-admin-panel.png) | ![GL.iNet mobile app showing enabled FM350-GL modem](docs/images/gl-mt3000-fm350-mobile-app.png) |

## Install the current FM350 release

Download the package for your firmware and `SHA256SUMS` from the [latest release](https://github.com/rudironsoni/gl-modem-community/releases/latest). Copy them to `/tmp` on the router, replace `VERSION` with the downloaded release version, and compare the package hash with the matching entry in `SHA256SUMS` before installation.

```sh
cd /tmp
sha256sum gl-modem-community*VERSION*
cat SHA256SUMS
```

### APK firmware

Firmware that uses APK must trust this project's public key before it can install the package. LuCI can manage the feed after this one-time bootstrap, but it cannot import a third-party APK signing key for you.

```sh
cd /tmp
wget -O gl-modem-community.pem \
  https://github.com/rudironsoni/gl-modem-community/releases/latest/download/gl-modem-community.pem
wget -O gl-modem-community.pem.sha256 \
  https://github.com/rudironsoni/gl-modem-community/releases/latest/download/gl-modem-community.pem.sha256
sha256sum -c gl-modem-community.pem.sha256
cp gl-modem-community.pem /etc/apk/keys/
chmod 0644 /etc/apk/keys/gl-modem-community.pem
```

Do not bypass APK signature verification.

#### Install from the feed with LuCI

1. Open the GL.iNet admin panel and select **Advanced Settings** to enter LuCI.
2. Open **System → Software** and select **Configure apk**.
3. Add this line to `/etc/apk/repositories.d/customfeeds.list`:

   ```text
   https://github.com/rudironsoni/gl-modem-community/releases/latest/download/packages.adb
   ```

4. Save the configuration and select **Update lists…**.
5. Search for `gl-modem-community` and select **Install**.
6. Open **System → Startup** and confirm that `gl_modem_community` is enabled.

If LuCI shows **Configure opkg** instead, that firmware cannot use the APK feed. Use the IPK instructions below.

To configure and install the feed from SSH instead:

```sh
feed='https://github.com/rudironsoni/gl-modem-community/releases/latest/download/packages.adb'
mkdir -p /etc/apk/repositories.d
touch /etc/apk/repositories.d/customfeeds.list
grep -Fqx "$feed" /etc/apk/repositories.d/customfeeds.list || \
  printf '%s\n' "$feed" >> /etc/apk/repositories.d/customfeeds.list
apk update
apk add gl-modem-community
```

The service starts during installation and restarts the stock cellular manager, so the runtime overlays apply immediately. A downloaded APK uses the same trusted key after the bootstrap step:

```sh
apk add /tmp/gl-modem-community-VERSION-r1.apk
```

### IPK firmware

> [!CAUTION]
> The IPK builds with the OpenWrt 24.10 SDK, but it has not been tested on GL.iNet OEM or OpenWrt 24 firmware.

```sh
opkg install /tmp/gl-modem-community_VERSION-r1_aarch64_cortex-a53.ipk
```

The IPK still requires GL.iNet's `cellular_manager`, `modem_AT`, model-table, and RPC stack.

## Verify an FM350-GL setup

First confirm that the runtime model table and FM350 compatibility wrapper are mounted:

```sh
mount | grep -E '(/usr/bin/modem_AT|/lib/modem_data/modem_list.json)'
jq -e '.modems[] | select(.vid == "0e8d" and (.pid == "7126" or .pid == "7127"))' \
  /lib/modem_data/modem_list.json
```

Attach the modem and inspect the stock service path:

```sh
ubus list -v cellular.sim
ubus list -v cellular.modem
logread | grep -E 'FM350 modem_AT compatibility|modem_AT: Bus:|SIM INSERT|CGDCONT|CGACT|CGPADDR|Dial success'
```

A detected SIM does not prove that cellular data works. Confirm that the cellular interface has its own address, route, and DNS configuration. An address on a Wi-Fi repeater interface, usually `wwan` or `sta0`, is unrelated.

## Remove the package

For APK firmware:

```sh
apk del gl-modem-community
```

For IPK firmware:

```sh
opkg remove gl-modem-community
```

Removal stops and disables `gl_modem_community`, removes its runtime mounts, restores package-owned network values when they still contain the package-applied value, and restarts the stock cellular manager. Values later changed by the user or stock firmware are preserved.

## How it works

The package extends the narrowest available GL.iNet integration points:

| Component | Purpose |
| --- | --- |
| `drivers.d/*.json` | Adds community modem definitions to the runtime model table. |
| `lib/netifd/proto/*.sh` and `etc/gcom/*.gcom` | Adds a data protocol where the stock firmware has no suitable one. |
| `rpc-drivers/*.lua` | Handles selected RPC methods for a specific USB ID and falls back to GL.iNet's backend when it does not own a method. |
| `usr/libexec/gl-modem-community/` | Holds modem-specific compatibility helpers. |
| `etc/init.d/gl_modem_community` | Builds and mounts the runtime model table before the stock cellular manager starts. |

The FM350 implementation keeps its AT compatibility and network-repair behavior limited to the FM350 USB IDs. See the [package design](docs/package-design.md) for component contracts and rollback behavior, and the [modem architecture](docs/modem-architecture.md) for the stock integration path.

## Build and extend

Docker is required. The repository scripts use checksum-pinned SDKs and keep generated build artifacts out of Git.

```sh
make tools
make test
make package
make package-opkg
git diff --check
```

To reproduce the firmware-analysis pipeline:

```sh
make download verify extract inventory analyze report
```

When adding a modem, start with observed USB IDs, interfaces, serial driver, AT port, data interface, and stock failure mode. Add only verified fields to a driver fragment, keep modem-specific behavior scoped to that modem, and add focused regression coverage. When adding a router, confirm its stock cellular stack and test both an existing stock modem and the community modem on hardware before listing it as supported.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for compatibility-claim rules and pull-request evidence. The [FM350 gap analysis](docs/fm350-gap-analysis.md), [public-source analysis](docs/public-source-analysis.md), and [hardware validation plan](docs/validation-plan.md) record the current evidence and remaining work.

## Releases

Every pull request runs the offline test suite and builds both package formats. Releases publish a signed APK repository index, an IPK, CycloneDX SBOMs, the public key and checksum, checksums for release artifacts, and GitHub build-provenance attestations.

[Release Please](https://github.com/googleapis/release-please) manages versions from Conventional Commits after the required build and signing work succeeds.
