# gl-modem-community

[![Latest release](https://img.shields.io/github/v/release/rudironsoni/gl-modem-community)](https://github.com/rudironsoni/gl-modem-community/releases/latest)
[![Release](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml)

`gl-modem-community` adds Fibocom FM350-GL support to GL.iNet's stock cellular stack on the GL-MT3000. It extends the existing modem service instead of replacing it, so the stock web UI, mobile app backend, JSON-RPC, ubus APIs, and supported modem paths stay in place.

The package contains clean-room community code only. It does not include GL.iNet firmware or proprietary binaries.

> [!IMPORTANT]
> This package depends on GL.iNet's stock cellular backend. It is not a standalone modem manager for vanilla OpenWrt.

## Compatibility

| Component | Support |
| --- | --- |
| Router | GL.iNet GL-MT3000 |
| Modem | Fibocom FM350-GL |
| USB IDs | `0e8d:7126`, `0e8d:7127` |
| GL.iNet firmware using APK | Package built with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK |
| GL.iNet firmware using OPKG | Package built with the pinned OpenWrt 24.10.7 MediaTek Filogic SDK; runtime behavior is unverified |
| Vanilla OpenWrt | Unsupported because the stock GL.iNet cellular backend is absent |

Current hardware evidence is deliberately narrow:

- [CONFIRMED] FM350 appears as `ttyUSB` in the observed RNDIS composition. Product `7126` uses AT offset `2`; product `7127` uses AT offset `3`.
- [CONFIRMED] The stock common driver reaches SIM detection and reads ICCID and IMSI.
- [UNVERIFIED] End-to-end PDP activation, address and route setup, reconnect behavior, and full web UI or mobile app behavior still need hardware validation.

## Install

Download the package for your firmware and `SHA256SUMS` from the [latest release](https://github.com/rudironsoni/gl-modem-community/releases/latest), then copy both files to `/tmp` on the router. Replace `VERSION` below with the release number you downloaded.

Check the package before installing it:

```sh
cd /tmp
sha256sum gl-modem-community-VERSION-r1.apk
cat SHA256SUMS
```

For GL.iNet firmware using APK:

```sh
apk add --allow-untrusted /tmp/gl-modem-community-VERSION-r1.apk
/etc/init.d/gl_modem_community enable
/etc/init.d/gl_modem_community restart
/etc/init.d/gl_cellular_manager restart
```

For GL.iNet firmware using OPKG:

```sh
opkg install /tmp/gl-modem-community_VERSION-r1_aarch64_cortex-a53.ipk
/etc/init.d/gl_modem_community enable
/etc/init.d/gl_modem_community restart
/etc/init.d/gl_cellular_manager restart
```

The OPKG package targets OpenWrt 24.10 on `aarch64_cortex-a53`, but it still requires GL.iNet's proprietary cellular services. Its runtime behavior has not been verified on hardware.

## Verify

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

A detected SIM does not prove that the data session is working. Confirm the cellular interface has its own address, route, and DNS before counting the connection as successful. The Wi-Fi repeater's `wwan` or `sta0` address is unrelated.

## Remove

Stopping the service removes the runtime overlays and exposes the original SquashFS files again.

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

## How it works

The service starts before GL.iNet's stock cellular manager and builds a runtime modem table containing the original entries plus the FM350 definitions. It bind-mounts that table over the stock path without changing the firmware image.

FM350 traffic uses the public `xmm` netifd and GCOM contract from [`koshev-msk/modemfeed`](https://github.com/koshev-msk/modemfeed). A narrow compatibility wrapper changes the FM350 cold-activation command from `AT+CFUN=0` to `AT+CFUN=4`. Calls for every other modem go to the original stock binary unchanged.

See [package design](docs/package-design.md) for the component contract and [hardware validation](docs/validation-plan.md) for the full test matrix.

## Build and test

Docker is required. The build scripts download checksum-pinned SDKs and keep generated artifacts out of Git.

```sh
make tools
make test
make package
make package-opkg
```

`make package` builds the APK with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK. `make package-opkg` builds the IPK with the pinned OpenWrt 24.10.7 SDK.

To reproduce the stock firmware analysis:

```sh
make download verify extract inventory analyze report
```

Start with the [modem architecture](docs/modem-architecture.md), [FM350 gap analysis](docs/fm350-gap-analysis.md), and [public source analysis](docs/public-source-analysis.md) if you want to inspect the evidence behind the implementation.

## Releases

[Release Please](https://github.com/googleapis/release-please) manages versions from Conventional Commits. Each GitHub release includes APK and IPK packages plus `SHA256SUMS`. GitHub Actions runs the offline test suite and builds both package formats before publishing them.
