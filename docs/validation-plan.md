# Hardware validation plan

Do not run this plan as part of offline analysis. Every modification is reversible and begins with observation.

## Stage 1: capture stock state

1. Record firmware and configuration: `ubus call system board`, `sha256sum /usr/bin/gl_modem /usr/bin/cellular_manager /usr/lib/oui-httpd/rpc/modem.so`, `sysupgrade -b /tmp/stock-config.tar.gz`.
2. Capture packages: `apk list --installed > /tmp/apk-installed.txt`.
3. Capture interfaces and USB: `ip -details link`, `lsusb -t`, `find /sys/bus/usb/devices -maxdepth 2 -type f -name idVendor -o -name idProduct`.
4. Capture APIs: `ubus list -v > /tmp/ubus-list-v.txt`.
5. Capture processes and services: `ps w`, `service gl_cellular_manager running`, `procd` service data, `/etc/init.d/gl_cellular_manager`.
6. Capture frontend network requests using browser developer tools without changing authentication.
7. Capture `/rpc` request/response bodies and `/ws` events for every cellular screen.

## Stage 2: observe invocation and I/O contracts

8. Install a transparent `gl_modem` wrapper only after saving the original hash and path. Log timestamp, argv, duration, exit status, stdout length, and stderr length. Do not log SIM identifiers or AT responses by default.
9. Trace `execve`, file, socket, ioctl, and serial operations on `cellular_manager`, `modem_AT`, and nginx workers. Preserve timing and concurrency.
10. Repeat with one officially supported common-map modem, then FM350. Compare events, selected tty, commands, parsers, JSON fields, and netifd state.

## Stage 3: reversible package tests

Install the locally built APK or IPK appropriate for the firmware package manager, verify its checksum, confirm the package hook activated `gl_modem_community`, reboot, and confirm:

- original SquashFS model table is unchanged when the service is stopped;
- runtime merged table contains the stock 16 entries plus both FM350 IDs;
- an official modem follows the same stock path and responses as baseline;
- attach/remove emits one correct `cellular.status` lifecycle per device;
- `/rpc` authentication, error codes, stdout/stderr behavior, and websocket topics are unchanged;
- FM350 uses the expected product-specific `ttyUSB` AT interface and RNDIS data interface;
- stopping/removing the package restores stock behavior without reboot where safe.

## Test matrix

Run each case with browser UI and mobile app where available: modem disconnected; FM350 attached; supported modem attached; SIM absent; SIM PIN required; registered; searching; denied; no signal; LTE; 5G NSA; 5G SA; connect; disconnect; reset; USB re-enumeration; UI refresh; concurrent polling; and router reboot.

For every test record request, response, ubus event, AT transcript with identifiers redacted, interface/address/route/DNS state, process exit, and timeout. Compare failures against stock numeric and JSON error contracts.

Success requires basic identity, SIM state, registration, APN connect/disconnect, route/DNS, reconnect, and UI/app status to be reproduced. Advanced signal, cell, band, lock, temperature, and reset remain separate gates. Offline analysis alone cannot pass any runtime gate.

### FM350 focused loop

Use the current signed APK and install the public key as documented in the README.

Install the package. Its lifecycle hook enables and restarts `gl_modem_community`, then restarts the stock cellular manager so an already-running stock `modem_AT` process cannot survive the bind-mount change:

```sh
sha256sum /tmp/gl-modem-community-VERSION-r1.apk
apk add /tmp/gl-modem-community-VERSION-r1.apk
```

For an OpenWrt 24.10-based GL.iNet image using OPKG, substitute:

```sh
sha256sum /tmp/gl-modem-community_VERSION-r1_aarch64_cortex-a53.ipk
opkg install /tmp/gl-modem-community_VERSION-r1_aarch64_cortex-a53.ipk
```

[UNVERIFIED] These commands require an image that provides the stock GL.iNet cellular services and package dependencies; vanilla OpenWrt does not provide the proprietary backend this extension wraps.

Before pressing Connect, capture:

```sh
mount | grep -E '(/usr/bin/modem_AT|/lib/modem_data/modem_list.json)'
ubus list -v cellular.sim
ubus list -v cellular.modem
logread | grep -E 'FM350 modem_AT compatibility|modem_AT: Bus:|SIM INSERT|common_get_pdp|set min function|pdp state|get_v4_info|Dial success'
```

Pass for the primary hypothesis requires `FM350 modem_AT compatibility active bus=2-1 port=/dev/ttyUSB3` and no new `Failed to set min function` after Connect. Then verify the secondary boundary: a `CGDCONT` CID is found, `CGACT` becomes active, `CGPADDR` yields an address, and `network.interface.modem_2_1_s1` reaches up state. The Wi-Fi repeater's `wwan`/`sta0` address is unrelated and must not be counted as cellular success.

If `common_get_pdp: cid ... not found` continues, capture raw `AT+CGDCONT?` through the stock authenticated AT method before changing anything else. If PDP activation succeeds but netifd fails, the remaining defect is the `xmm` handoff, not SIM detection or APN parsing.

Revert with the package manager. The removal hook restores plugin-owned UCI values and both stock bind-mount targets before restarting the stock cellular manager:

```sh
apk del gl-modem-community
mount | grep -E '(/usr/bin/modem_AT|/lib/modem_data/modem_list.json)' || true
```

Use `tests/hardware/client-connectivity-monitor.sh` and `tests/hardware/router-sampler.sh` for synchronized evidence, then evaluate the selected expectation with `tests/hardware/analyze-run.sh`. Store local captures under the ignored `tests/hardware/results/` directory and redact them before attaching a compatibility report.
