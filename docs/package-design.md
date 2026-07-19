# `gl-modem-community` package design

The package under `package/gl-modem-community/` is an offline-buildable clean-room extension. It does not contain GL.iNet binaries or decompiled code.

```mermaid
flowchart LR
    FRAG[drivers.d/fm350.json] --> MERGE[merge-models]
    STOCK[stock modem_list.json] --> MERGE
    MERGE --> RUNTIME[/var/run merged table]
    RUNTIME --> HOTPLUG[stock 30_modem]
    HOTPLUG --> GL[stock cellular_manager/libcm]
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
- `fm350.json` adds `0e8d:7126` and `0e8d:7127`, `function_at_common`, protocol `xmm`, and no unsupported advanced capability flags.
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

Security: RPC authentication remains in GL.iNet's existing dispatcher. The proxy does not create a new listener, bypass a session, or permit arbitrary commands beyond the stock `send_at_command` surface. Shell inputs are quoted and GCOM failures are propagated.

Upgrade behavior: the package must be rebuilt and revalidated for each stock firmware because private `.so` schemas can change. The additive model fragment and public `xmm` protocol are independent of proprietary code, but boot order and dispatcher semantics must be rechecked.

[INFERENCE] `ttyACM` offset `0`, `supports_ip_type: 1`, and the default direct-IP addressing are starting values derived from public source shape. Hardware validation is mandatory before release.

Build status: [CONFIRMED] OpenWrt SDK `25.12.5` produced `gl-modem-community-0.1.0-r1.apk` as `noarch`. SHA-256 is `35834a7e6e356c1f90e80662980268bba5cf88ea04d7704ef0dec34009c5e87d`. APK v3 metadata and dependency inspection are recorded in `analysis/reports/package-inspection.txt`. Installation and runtime were not performed.
