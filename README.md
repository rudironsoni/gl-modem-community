# gl-modem-community

[![Latest release](https://img.shields.io/github/v/release/rudironsoni/gl-modem-community)](https://github.com/rudironsoni/gl-modem-community/releases/latest)
[![Release](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/release.yml)
[![CI](https://github.com/rudironsoni/gl-modem-community/actions/workflows/ci.yml/badge.svg)](https://github.com/rudironsoni/gl-modem-community/actions/workflows/ci.yml)

`gl-modem-community` adds community modem definitions and compatibility drivers to the cellular stack included in GL.iNet firmware. It keeps the stock web UI, mobile app backend, JSON-RPC and ubus interfaces, and built-in modem definitions.

The first driver targets the Fibocom FM350-GL on a GL.iNet GL-MT3000 (Beryl AX). The package depends on GL.iNet's proprietary cellular services and does not replace them, so it is not a modem manager for vanilla OpenWrt.

> [!WARNING]
> This project is still experimental. The FM350-GL is detected and visible in the GL.iNet interfaces, but the complete data-session and recovery test matrix has not passed yet.

## Compatibility status

A package that builds against an SDK has not necessarily been tested on firmware from the same OpenWrt release.

| Firmware scope | Package format | Build status | Hardware status |
| --- | --- | --- | --- |
| GL.iNet OpenWrt 25 on GL-MT3000 | APK | Builds with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK | Partially tested with FM350-GL |
| GL.iNet OEM or OpenWrt 24 on GL-MT3000 | IPK | Builds with the pinned OpenWrt 24.10.7 MediaTek Filogic SDK | Not tested |
| Other GL.iNet routers | Target-specific package required | Not built | Not tested |
| Vanilla OpenWrt | Not applicable | GL.iNet cellular services are absent | Not supported |

The OpenWrt 25 hardware work has verified:

- FM350-GL USB IDs `0e8d:7126` and `0e8d:7127`;
- `ttyUSB` enumeration in the observed RNDIS compositions;
- AT offset `2` for product `7126` and offset `3` for product `7127`;
- SIM detection and ICCID and IMSI reads through the stock common driver;
- modem visibility in the GL.iNet web UI and mobile app.

The following behavior still needs hardware testing:

- PDP activation and a sustained data session;
- interface addressing, routes, and DNS;
- reconnect and recovery after USB re-enumeration;
- the complete web UI and mobile app flows;
- installation and runtime behavior on current GL.iNet OEM and OpenWrt 24 firmware;
- regression testing with a modem already supported by GL.iNet.

See the [hardware validation plan](docs/validation-plan.md) for the full test matrix.

## Hardware evidence

The screenshots below show the FM350-GL in the GL.iNet admin panel and mobile app on the reference GL-MT3000. They prove detection and UI visibility. They do not prove that the modem completed a data session. IMEI and SIM details are redacted.

| GL.iNet admin panel | GL.iNet mobile app |
| --- | --- |
| ![GL-MT3000 admin panel showing the FM350-GL cellular connection](docs/images/gl-mt3000-fm350-admin-panel.png) | ![GL.iNet mobile app showing the enabled FM350-GL modem](docs/images/gl-mt3000-fm350-mobile-app.png) |

## Feeds

Three version-specific feeds are published:

| OpenWrt version | Package format | Feed URL |
| --- | --- | --- |
| 21.02 (GL.iNet 21) | IPK | `https://rudironsoni.github.io/gl-modem-community/feed/21.02/aarch64_cortex-a53/custom/` |
| 24.10 | IPK | `https://rudironsoni.github.io/gl-modem-community/feed/24.10/aarch64_cortex-a53/custom/` |
| 25.12 | APK | `https://rudironsoni.github.io/gl-modem-community/feed/25.12/aarch64_cortex-a53/custom/` |

### APK feed (OpenWrt 25.12+)

```sh
mkdir -p /etc/apk/repositories.d
touch /etc/apk/repositories.d/customfeeds.list
grep -Fqx 'https://rudironsoni.github.io/gl-modem-community/feed/25.12/aarch64_cortex-a53/custom/' \
  /etc/apk/repositories.d/customfeeds.list || \
  printf '%s\n' 'https://rudironsoni.github.io/gl-modem-community/feed/25.12/aarch64_cortex-a53/custom/' \
  >> /etc/apk/repositories.d/customfeeds.list
apk update
```

The APK feed requires the project's public key for signature verification. Install it first:

```sh
wget -O /etc/apk/keys/gl-modem-community.pem \
  https://github.com/rudironsoni/gl-modem-community/releases/latest/download/gl-modem-community.pem
wget -O - https://github.com/rudironsoni/gl-modem-community/releases/latest/download/gl-modem-community.pem.sha256 \
  | sha256sum -c
```

### IPK feeds (OpenWrt 21.02 / 24.10)

```sh
touch /etc/opkg/customfeeds.conf
chmod 0644 /etc/opkg/customfeeds.conf

# For OpenWrt 21.02 (GL.iNet 21)
grep -Fqx 'src/gz gl-modem-community https://rudironsoni.github.io/gl-modem-community/feed/21.02/aarch64_cortex-a53/custom/' \
  /etc/opkg/customfeeds.conf || \
  printf '%s\n' 'src/gz gl-modem-community https://rudironsoni.github.io/gl-modem-community/feed/21.02/aarch64_cortex-a53/custom/' \
  >> /etc/opkg/customfeeds.conf

# For OpenWrt 24.10
grep -Fqx 'src/gz gl-modem-community https://rudironsoni.github.io/gl-modem-community/feed/24.10/aarch64_cortex-a53/custom/' \
  /etc/opkg/customfeeds.conf || \
  printf '%s\n' 'src/gz gl-modem-community https://rudironsoni.github.io/gl-modem-community/feed/24.10/aarch64_cortex-a53/custom/' \
  >> /etc/opkg/customfeeds.conf

opkg update
```

## Verify the FM350 setup

Confirm that the merged model table and FM350 compatibility wrapper are mounted:

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

A detected SIM does not prove that the data session works. Confirm that the cellular interface has its own address, route, and DNS configuration. An address on the Wi-Fi repeater interface, usually `wwan` or `sta0`, is unrelated.

## Remove the package

For APK:

```sh
/etc/init.d/gl_modem_community stop
apk del gl-modem-community
/etc/init.d/gl_cellular_manager restart
```

For IPK:

```sh
/etc/init.d/gl_modem_community stop
opkg remove gl-modem-community
sed -i '/gl-modem-community/d' /etc/opkg/customfeeds.conf 2>/dev/null || true
/etc/init.d/gl_cellular_manager restart
```

Stopping or removing the package unmounts its runtime overlays and restores the original stock paths.

## How the package extends GL.iNet firmware

| Path | Purpose |
| --- | --- |
| `files/usr/share/gl-modem-community/drivers.d/*.json` | Adds modem definitions to the runtime model table |
| `files/lib/netifd/proto/*.sh` and `files/etc/gcom/*.gcom` | Adds a data protocol when the stock firmware does not provide one |
| `files/usr/share/gl-modem-community/rpc-drivers/*.lua` | Handles selected stock RPC methods for a specific USB ID |
| `files/usr/libexec/gl-modem-community/` | Contains modem-specific compatibility helpers |
| `files/etc/init.d/gl_modem_community` | Builds and mounts the runtime model table before the stock cellular manager starts |

The model merger accepts JSON fragments with a `modems` array and deduplicates entries by `bus_type:vid:pid`. The RPC dispatcher loads a community driver by USB ID. If that driver does not implement a method, the dispatcher calls GL.iNet's stock backend.

The FM350 implementation also uses an AT compatibility wrapper and a network repair helper. Both are limited to the FM350 USB IDs.

See the [package design](docs/package-design.md) for the component contract and rollback behavior.

## Add another modem

1. Capture the modem's USB IDs, USB interfaces, serial driver, AT port, data interface, and stock failure.
2. Add a model fragment under `package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/`. Use [`fm350.json`](package/gl-modem-community/files/usr/share/gl-modem-community/drivers.d/fm350.json) as a structural reference, but include only fields verified for the new modem.
3. Reuse a stock function map and existing netifd protocol when hardware tests show that they work. Add modem-specific GCOM, protocol, RPC, or compatibility code only for missing behavior.
4. Update `package/gl-modem-community/Makefile` so the package installs every new runtime file.
5. Add focused tests and register them in `tests/run.sh`.
6. Run the offline test suite and build each applicable package format.
7. Test the package on hardware. Include service restart, router reboot, removal, stock-path restoration, and a modem already supported by GL.iNet.

```sh
make tools
make test
make package
make package-opkg
git diff --check
```

A pull request must include the modem name, USB IDs, router model, exact firmware version, package format, test commands, and redacted hardware evidence. Follow the claim rules in [CONTRIBUTING.md](CONTRIBUTING.md).

## Add another GL.iNet router

Supporting another router requires more than adding its name to a table:

1. Confirm that its stock firmware provides compatible `cellular_manager`, `modem_AT`, model table, RPC, and ubus paths.
2. Record the router architecture, exact firmware version, package manager, and SDK source.
3. Add a checksum-pinned package target for the architecture.
4. Run the offline suite and inspect the package contents before installation.
5. Test both a stock-supported modem and a community modem on the router.
6. Confirm that stopping the service restores stock behavior.

List the router as tested only after these checks have run on the device.

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

The [modem architecture](docs/modem-architecture.md), [package design](docs/package-design.md), [public source analysis](docs/public-source-analysis.md), and [FM350 gap analysis](docs/fm350-gap-analysis.md) document the evidence and proprietary-code boundary behind the driver.

## Releases

Every pull request runs the offline test suite and builds both package formats. A release adds the signed APK and repository index, the IPK, CycloneDX SBOMs, the public key, checksums, and GitHub build-provenance attestations.

[Release Please](https://github.com/googleapis/release-please) manages versions from Conventional Commits after the release artifacts pass CI and signing.
