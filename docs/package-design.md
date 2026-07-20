# `gl-modem-community` package design

The package under `package/gl-modem-community/` is an offline-buildable clean-room extension. It does not contain GL.iNet binaries or decompiled code.

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
    PROXY -->|future FM350 hook| DRIVER[FM350 clean-room driver]
    GL --> NETIFD[xmm netifd protocol]
    NETIFD --> AT[comgt FM350 AT scripts]
```

Component contract:

- `gl_modem_community` starts at priority 22, before stock `gl_cellular_manager` at 23.
- `merge-models` validates stock and extension JSON with `jq`, deduplicates by `bus_type:vid:pid`, and writes `/var/run/gl-modem-community/modem_list.json` atomically.
- The service bind-mounts the runtime file over `/lib/modem_data/modem_list.json`. Stop/uninstall unmounts it, restoring the immutable SquashFS file.
- The service also copies stock `/usr/bin/modem_AT` into tmpfs and bind-mounts a shell dispatcher over its original path. Non-FM350 invocations execute the stock binary unchanged. FM350 invocations preload a clean-room write filter that changes only the exact serial command `AT+CFUN=0` to same-length `AT+CFUN=4`.
- `fm350.json` adds `0e8d:7126` and `0e8d:7127`, `function_at_common`, protocol `xmm`, and no unsupported advanced capability flags. Product `7126` maps USB interface `04` to `ttyUSB` AT offset `2`; product `7127` maps USB interface `06` to `ttyUSB` AT offset `3`.
- `/lib/netifd/proto/xmm.sh` implements discovery and connection using `comgt`. Its UCI inputs are `device`, `apn`, `pdp`, `delay`, `pincode`, `username`, `password`, `auth`, `profile`, `maxfail`, and explicit address/interface overrides.
- GCOM scripts issue the public `CGAUTH`, `CGDCONT`, `CGACT`, `CGPADDR`, and `GTDNS` contract and fail on AT errors.
- The extensionless Lua `modem` RPC file preserves the confirmed stock method names. A community method handler may answer only for a matched community VID/PID; all other calls execute the stock `.so` path.
- `rpc-drivers/fm350.lua` currently overrides no methods. This is intentional until exact live schemas are captured.

Failure and fallback:

- Invalid fragments prevent activation and leave the stock file visible.
- A missing FM350 handler falls through to stock behavior.
- Non-FM350 devices always fall through.
- No logging of AT commands or identifiers occurs by default.
- Per-interface netifd state and service serialization provide concurrency boundaries; hardware tests must verify simultaneous polling and reconnect.
- Removal stops the service, unmounts the runtime table, deletes package files, and leaves the original firmware unchanged.
- The proprietary `modem_AT` copy exists only under `/var/run` while the service is active and is never stored in the package or repository.

Security: RPC authentication remains in GL.iNet's existing dispatcher. The proxy does not create a new listener, bypass a session, or permit arbitrary commands beyond the stock `send_at_command` surface. Shell inputs are quoted and GCOM failures are propagated.

Upgrade behavior: the package must be rebuilt and revalidated for each stock firmware because private `.so` schemas can change. The additive model fragment and public `xmm` protocol are independent of proprietary code, but boot order and dispatcher semantics must be rechecked.

[CONFIRMED] The initial `ttyACM` definition was wrong. A GL-MT3000 boot capture showed FM350 interfaces `02`, `03`, `04`, `06`, `07`, `08`, and `09` bound as `ttyUSB0` through `ttyUSB6`; stock `modem_AT` consequently reported `at_offset:-1`. Version `0.1.1` uses modemfeed's product-specific interface mapping. [INFERENCE] `supports_ip_type: 1` and default direct-IP addressing still require runtime validation.

Build status: [CONFIRMED] OpenWrt SDK `25.12.5` produced `gl-modem-community-0.1.2-r1.apk` for `aarch64_cortex-a53`. SHA-256 is `58eabf76096e9f6778268f4f53a791c4313c0c049aa60833e776339a21e7269a`. APK v3 metadata and dependency inspection are recorded in `analysis/reports/package-inspection.txt`.

[CONFIRMED] The official OpenWrt `24.10.7` MediaTek Filogic SDK produced `gl-modem-community_0.1.2-r1_aarch64_cortex-a53.ipk`. Its SHA-256 is `55dfd5a47a2e065c6151c8c366ce57c58e787056a3e899e82a1854db1051eea0`, and its exact size is 8780 bytes. Package metadata and ELF inspection are recorded in `analysis/reports/package-opkg-inspection.txt`. The build input SDK URL and SHA-256 are pinned in `scripts/build-package-opkg.sh`.

The IPK format and ABI target OpenWrt 24.10, but the package still depends on GL.iNet's stock `cellular_manager`, `modem_AT`, model table, and RPC stack being present. It is not a replacement cellular backend for vanilla OpenWrt. The exact AT rewrite has a host regression test and the full offline suite passes. Installation and FM350 runtime behavior of `0.1.2` on OpenWrt 24 remain [UNVERIFIED].
