# GL-MT3000 stock modem research

Offline, reproducible analysis of GL.iNet's GL-MT3000 OpenWrt 25 beta cellular stack, plus a clean-room `gl-modem-community` package for exposing community-supported modems through the stock web UI and mobile-app backend contract.

The first driver targets Fibocom FM350-GL using the public `xmm-modem` contract from [`koshev-msk/modemfeed`](https://github.com/koshev-msk/modemfeed). Rudi reports that path works on vanilla OpenWrt 25. [UNVERIFIED] No hardware was used here, so this repository does not claim working FM350 support on stock GL.iNet firmware.

## Result

[CONFIRMED] Stock USB hotplug rejects FM350 before the generic modem path because `/lib/modem_data/modem_list.json` lacks `0e8d:7126` and `0e8d:7127`. The kernel serial-option table contains both IDs, but the proprietary backend has no Fibocom function map and its advanced paths are strongly Quectel-specific.

The package implements the smallest evidence-supported approach:

- additively merge FM350 definitions at runtime without changing SquashFS;
- use stock `function_at_common` for basic identity, SIM, and registration;
- supply a hardened `xmm` netifd protocol and GCOM scripts for APN/data connection;
- preserve stock `/rpc`, ubus, websocket, UI, app, and supported-modem fallback;
- provide a narrow Lua RPC extension point for later Fibocom handlers after live schemas are captured.

Replacing only `/usr/bin/gl_modem` is insufficient because `cellular_manager` and `modem.so` link directly to proprietary `libcm` libraries.

Start with [modem architecture](docs/modem-architecture.md), [FM350 gap analysis](docs/fm350-gap-analysis.md), [implementation options](docs/implementation-options.md), [package design](docs/package-design.md), and the [validation plan](docs/validation-plan.md). Public-source boundaries are recorded in [GL.iNet source analysis](docs/public-source-analysis.md) and [modemfeed source analysis](docs/modemfeed-source-analysis.md).

## Reproduce

```sh
make tools
make download
make verify
make extract
make inventory
make analyze
make report
make test
make package
make package-opkg
```

`make package` builds the OpenWrt 25 APK. `make package-opkg` builds the OpenWrt 24.10 IPK with the pinned official `24.10.7` MediaTek Filogic SDK. The OPKG package targets GL.iNet firmware that retains the stock cellular backend; it does not add that proprietary backend to vanilla OpenWrt.

The original firmware, extracted filesystem, SDK cache, package artifacts, and proprietary binaries are ignored. Git contains only scripts, public clean-room source, metadata, hashes, string catalogs, and reports.
