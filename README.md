# gl-modem-community

[![Latest release](https://img.shields.io/github/v/release/rudironsoni/gl-modem-community)](https://github.com/rudironsoni/gl-modem-community/releases/latest)
[![Release](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml)
[![CI](https://github.com/rudironsoni/gl-modem-community/actions/workflows/ci.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/ci.yml)

Community modem definitions and compatibility drivers for GL.iNet's stock cellular stack.

`gl-modem-community` lets users add modems that GL.iNet firmware does not support out of the box. It extends the stock model table and modem services while keeping the GL.iNet web UI, mobile app backend, JSON-RPC, ubus APIs, and built-in modem support in place.

The first tested setup is a GL-MT3000 (Beryl AX) with a Fibocom FM350-GL. The project is structured so contributors can add more modems and validate more GL.iNet routers without folding every device into one driver.

> [!IMPORTANT]
> This package depends on GL.iNet's stock cellular backend. It is not a standalone modem manager for vanilla OpenWrt.

## What this project provides

- Additive modem definitions that leave the stock SquashFS model table unchanged.
- Per-modem protocol, RPC, and compatibility hooks when the stock common path is not enough.
- Stock fallback for modem calls that a community driver does not handle.
- Clean-room source only. The repository does not contain GL.iNet firmware or proprietary binaries.

Stopping or removing the package unmounts its runtime overlays and restores the original stock paths.

## Current support

| Component | Status |
| --- | --- |
| GL.iNet GL-MT3000 (Beryl AX) | Tested reference router |
| Fibocom FM350-GL | Current community modem driver |
| FM350 USB IDs | `0e8d:7126`, `0e8d:7127` |
| APK package | Built with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK |
| IPK package | Built with the pinned OpenWrt 24.10.7 MediaTek Filogic SDK; hardware runtime is unverified |
| Other GL.iNet routers | Require a compatible stock backend, a target-specific build, and hardware validation |
| Vanilla OpenWrt | Unsupported because the GL.iNet cellular backend is absent |

The FM350 work has produced the following hardware evidence:

- [CONFIRMED] FM350 appears as `ttyUSB` in the observed RNDIS composition. Product `7126` uses AT offset `2`; product `7127` uses AT offset `3`.
- [CONFIRMED] The stock common driver detects the SIM and reads ICCID and IMSI.
- [UNVERIFIED] The full PDP, routing, DNS, reconnect, web UI, and mobile app test matrix is not complete.

See [hardware validation](docs/validation-plan.md) for the remaining test cases and the evidence required to mark them complete.

## Extension points

| Path | Purpose |
| --- | --- |
| `files/usr/share/gl-modem-community/drivers.d/*.json` | Add modem definitions to the runtime model table |
| `files/lib/netifd/proto/*.sh` and `files/etc/gcom/*.gcom` | Add a data protocol when the stock firmware does not provide one |
| `files/usr/share/gl-modem-community/rpc-drivers/*.lua` | Handle selected stock RPC methods for specific USB IDs |
| `files/usr/libexec/gl-modem-community/` | Keep narrow modem-specific compatibility code outside the stock binaries |
| `files/etc/init.d/gl_modem_community` | Build and mount the runtime model table before the stock cellular manager starts |

The model merger accepts any JSON fragment with a `modems` array and deduplicates entries by `bus_type:vid:pid`. The RPC dispatcher loads community drivers by USB ID. If a driver does not implement a method, the dispatcher sends the call to GL.iNet's stock backend.

The current FM350 implementation also needs an AT compatibility wrapper and a network repair helper. Those pieces are specific to FM350 and should not become global behavior for future modems.

## Add another modem

1. Capture the modem's USB IDs, USB interfaces, serial driver, AT port, data interface, and stock failure. Do not start by copying another modem's offsets.
2. Add a model fragment under `package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/`. Use [`fm350.json`](package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/fm350.json) as a structural reference, but keep only fields confirmed for the new modem.
3. Reuse a stock function map and existing netifd protocol when hardware evidence shows they work. Add modem-specific GCOM, protocol, RPC, or compatibility code only for the missing behavior.
4. Update `package/gl-modem-community/Makefile` so every new runtime file is installed in the package.
5. Add focused tests and register them in `tests/run.sh`. Cover model merging, expected port selection, modem-specific behavior, and stock fallback.
6. Run the offline checks and build both package formats where applicable.
7. Validate the package on hardware. Test the new modem, one modem already supported by GL.iNet, service restart, router reboot, removal, and restoration of the stock paths.

```sh
make tools
make test
make package
make package-opkg
git diff --check
```

A pull request should include the modem name, USB IDs, router model, firmware version, package format, exact test commands, and redacted hardware evidence. Mark anything not observed on hardware as `[UNVERIFIED]`.

## Add another GL.iNet router

The current release targets the GL-MT3000 architecture and SDKs. Supporting another router requires more than adding its name to a table:

1. Confirm that its stock firmware provides compatible `cellular_manager`, `modem_AT`, model table, RPC, and ubus paths.
2. Record the router architecture, firmware version, package manager, and SDK source.
3. Add a checksum-pinned build target for that architecture. Keep the existing GL-MT3000 builds reproducible.
4. Run the offline suite and inspect the package contents before installation.
5. Validate a stock-supported modem and a community modem on the router. Confirm that stopping the service restores stock behavior.

Router support remains `[UNVERIFIED]` until those checks run on the device.

## Install the current FM350 release

Download the package for your firmware and `SHA256SUMS` from the [latest release](https://github.com/rudironsoni/gl-modem-community/releases/latest), then copy both files to `/tmp` on the router. Replace `VERSION` below with the release number you downloaded.

Check the package before installing it:

```sh
cd /tmp
sha256sum gl-modem-community*VERSION*
cat SHA256SUMS
```

For GL.iNet firmware using APK, trust the project's public key once and add the stable feed:

```sh
cd /tmp
wget -O gl-modem-community-2026.pem \
  https://github.com/rudironsoni/gl-modem-community/releases/latest/download/gl-modem-community-2026.pem
wget -O gl-modem-community-2026.pem.sha256 \
  https://github.com/rudironsoni/gl-modem-community/releases/latest/download/gl-modem-community-2026.pem.sha256
sha256sum -c gl-modem-community-2026.pem.sha256
cp gl-modem-community-2026.pem /etc/apk/keys/
chmod 0644 /etc/apk/keys/gl-modem-community-2026.pem

feed='https://github.com/rudironsoni/gl-modem-community/releases/latest/download/packages.adb'
grep -Fqx "$feed" /etc/apk/repositories.d/customfeeds.list || \
  printf '%s\n' "$feed" >> /etc/apk/repositories.d/customfeeds.list
apk update
apk add gl-modem-community
/etc/init.d/gl_modem_community enable
/etc/init.d/gl_modem_community restart
/etc/init.d/gl_cellular_manager restart
```

The release APK carries the same signature, so a direct local install also verifies normally after the key is installed:

```sh
apk add /tmp/gl-modem-community-VERSION-r1.apk
```

For GL.iNet firmware using OPKG:

```sh
opkg install /tmp/gl-modem-community_VERSION-r1_aarch64_cortex-a53.ipk
/etc/init.d/gl_modem_community enable
/etc/init.d/gl_modem_community restart
/etc/init.d/gl_cellular_manager restart
```

The OPKG package targets OpenWrt 24.10 on `aarch64_cortex-a53`, but it still requires GL.iNet's proprietary cellular services. Its runtime behavior has not been verified on hardware.

## Verify the FM350 setup

Confirm that the runtime model table and FM350 compatibility wrapper are mounted:

```sh
mount | grep -E '(/usr/bin/modem_AT|/lib/modem_data/modem_list.json)'
jq -e '.modems[] | select(.vid == "0e8d" and (.pid == "7126" or .pid == "7127"))' \
  /lib/modem_data/modem_list.json
```

Attach the modem, then inspect the stock service path:

```sh
ubus list -v cellular.sim
ubus list -v cellular.modem
logread | grep -E 'FM350 modem_AT compatibility|modem_AT: Bus:|SIM INSERT|CGDCONT|CGACT|CGPADDR|Dial success'
```

A detected SIM does not prove that the data session is working. Confirm that the cellular interface has its own address, route, and DNS. The Wi-Fi repeater's `wwan` or `sta0` address is unrelated.

## Remove

For APK:

```sh
/etc/init.d/gl_modem_community stop
apk del gl-modem-community
/etc/init.d/gl_cellular_manager restart
```

For OPKG:

```sh
/etc/init.d/gl_modem_community stop
opkg remove gl-modem-community
/etc/init.d/gl_cellular_manager restart
```

## Build and research

Docker is required. The build scripts download checksum-pinned SDKs and keep generated artifacts out of Git.

```sh
make tools
make test
make package
make package-opkg
```

To reproduce the stock firmware analysis:

```sh
make download verify extract inventory analyze report
```

The [modem architecture](docs/modem-architecture.md), [package design](docs/package-design.md), [public source analysis](docs/public-source-analysis.md), and [FM350 gap analysis](docs/fm350-gap-analysis.md) explain the clean-room boundary and the evidence behind the current driver.

## Releases

Every pull request runs the offline test suite and builds both package formats. Releases add a signed APK and repository index, CycloneDX SBOMs, the public key, checksums, and GitHub build-provenance attestations.

[Release Please](https://github.com/googleapis/release-please) manages versions from Conventional Commits after release artifacts pass CI and signing.
