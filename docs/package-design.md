# `gl-modem-community` package design

The package under `package/gl-modem-community/` extends GL.iNet's stock cellular stack without shipping GL.iNet binaries or decompiled code.

```mermaid
flowchart LR
    FRAG[drivers.d/fm350.json] --> MERGE[merge-models]
    STOCK[stock modem_list.json] --> MERGE
    MERGE --> RUNTIME[/var/run merged table]
    RUNTIME --> HOTPLUG[stock 30_modem]
    HOTPLUG --> GL[stock cellular_manager/libcm]
    GL --> ATWRAP[FM350-only modem_AT wrapper]
    ATWRAP -->|CFUN 0 to CFUN 4| ATD[stock modem_AT]
    ATD --> MODEM[FM350 AT port]
    UI[stock UI/app] --> PROXY[Lua modem RPC proxy]
    PROXY -->|unhandled| SO[stock modem.so]
    PROXY -->|future FM350 hook| DRIVER[FM350 driver]
    GL --> NETIFD[xmm netifd protocol]
    NETIFD --> AT[comgt FM350 AT scripts]
```

## Component contract

- `gl_modem_community` starts at priority 22, before the stock `gl_cellular_manager` service at priority 23.
- `merge-models` validates the stock and extension JSON with `jq`, deduplicates entries by `bus_type:vid:pid`, and writes `/var/run/gl-modem-community/modem_list.json` atomically.
- The service bind-mounts the generated file over `/lib/modem_data/modem_list.json`. Stopping or removing the service unmounts it and exposes the original SquashFS file.
- The service copies the stock `/usr/bin/modem_AT` binary into tmpfs and bind-mounts a shell dispatcher over the original path. Non-FM350 calls execute the copied stock binary without modification.
- FM350 calls preload a write filter that changes only the exact serial command `AT+CFUN=0` to the same-length command `AT+CFUN=4`.
- `fm350.json` adds USB IDs `0e8d:7126` and `0e8d:7127` with `function_at_common` and protocol `xmm`. Product `7126` maps USB interface `04` to `ttyUSB` AT offset `2`; product `7127` maps interface `06` to offset `3`.
- `/lib/netifd/proto/xmm.sh` uses `comgt` for discovery and connection. Its UCI inputs are `device`, `apn`, `pdp`, `delay`, `pincode`, `username`, `password`, `auth`, `profile`, `maxfail`, and optional address and interface overrides.
- The GCOM scripts issue the public `CGAUTH`, `CGDCONT`, `CGACT`, `CGPADDR`, and `GTDNS` commands and return an error when an AT command fails.
- The extensionless Lua `modem` RPC file preserves the confirmed stock method names. A community handler can answer only for its configured USB IDs. All other calls use the stock `.so` path.
- `rpc-drivers/fm350.lua` implements `get_info`, `get_status`, `set_connect`, `disconnect`, `get_sim_config`, `set_sim_config`, `get_slot_config`, and `set_slot_config` for FM350 USB IDs. Product `7127` is dual-slot; `7126` stays single-slot. Serving-cell `GTCCINFO` maps to stock UI modes `4` (LTE) and `5` (NR). `get_info`/`get_status` also emit `simsStatus` with `type=1` and `status=2` so the 4.9.x Cellular eSIM gate can light up when that payload is consumed.
- `fm350-esim-sdk` is the canonical `POST /sdk/v1` adapter. A tiny CGI launcher under `esim-http/sdk/v1` execs it. On start the service copies the nginx fragment into `/etc/nginx/gl-conf.d/` (server context), reloads nginx, and binds `127.0.0.1:3456` only when that port is free. Stop/remove deletes the fragment and reloads nginx.
- The tethering overlay copies the exact stock `tethering` RPC aside and bind-mounts a wrapper that filters FM350 RNDIS from `get_status`. Stop/remove unmounts it.
- `fm350-boot-restore` persists a deliberate disconnect immediately and a connected snapshot only after a sustained netifd-up check. Restore runs in a background procd worker and is a no-op when no record exists.
- On the legacy 4.8.1 stack, `start_legacy` installs `menu.d/esim.json` and `/www/views/gl-sdk4-ui-esim.common.js`. The view is a clean-room copy of the 4.9.x eSIM Management layout. It is not the stock 4.9.x internet bundle.

## Failure and rollback behavior

- Invalid modem fragments prevent activation and leave the stock model table visible.
- A missing FM350 RPC handler falls back to the stock backend.
- Non-FM350 AT calls execute the stock binary.
- GCOM failures propagate to netifd.
- Per-interface state remains under `/var/run`.
- The copied `modem_AT` binary exists only in tmpfs while the service is active. It is never stored in the package or repository.

## Security boundary

RPC authentication remains in GL.iNet's existing dispatcher. The proxy does not create a listener, bypass a session, or add an arbitrary command interface. The stock `send_at_command` method remains the only exposed AT-command surface.

## Firmware upgrades

Rebuild and retest the package for each GL.iNet firmware release. The private `.so` schemas, boot order, and dispatcher behavior can change even when the public package ABI remains compatible.

The model fragment and `xmm` protocol do not depend on proprietary source code, but they still depend on GL.iNet's runtime paths and services.

## Hardware findings

The initial `ttyACM` definition was wrong. A GL-MT3000 boot capture showed FM350 interfaces `02`, `03`, `04`, `06`, `07`, `08`, and `09` bound as `ttyUSB0` through `ttyUSB6`. The stock `modem_AT` command consequently reported `at_offset:-1`.

Version `0.1.1` adopted the product-specific interface mapping from modemfeed. Direct-IP addressing and `supports_ip_type: 1` still require runtime validation.

## Build evidence

The repository builds the APK with the pinned OpenWrt 25.12.5 MediaTek Filogic SDK and the IPK with the pinned OpenWrt 24.10.7 MediaTek Filogic SDK. CI verifies the current package version and artifact names on every pull request.

The files under `analysis/reports/` record individual local analysis runs. They are snapshots, not statements about the latest release.

The IPK targets the OpenWrt 24.10 ABI, but it still depends on GL.iNet's stock `cellular_manager`, `modem_AT`, model table, and RPC stack. Its installation and FM350 runtime behavior on GL.iNet OEM and OpenWrt 24 firmware have not been tested.
