# Unknowns and blocked evidence

- [UNVERIFIED] Exact JSON schemas, optional fields, timeouts, and numeric errors for each proprietary RPC method.
- [UNVERIFIED] Exact stdout, stderr, exit codes, signals, concurrency, and timeout behavior for every `gl_modem` command.
- [UNVERIFIED] Proprietary `/tmp/<bus>.sock` framing.
- [UNVERIFIED] Whether FM350 `CGMI`/`CGMM` response formatting passes the stock common parser.
- [CONFIRMED] FM350 uses `ttyUSB`, not `ttyACM`, in the observed RNDIS composition. Product-specific AT offsets are `2` for `7126`/USB interface `04` and `3` for `7127`/USB interface `06`.
- [CONFIRMED] Dell DW5931e-eSIM (`0e8d:7127`) on GL-MT3000 4.8.1 uses USB interface `06` (`/dev/ttyUSB4`) as AT. Interface `05` is ADB (`bInterfaceSubClass=0x42`). Hotplug `PRODUCT` can be `e8d/7127/1`.
- [CONFIRMED] That Dell variant enables RF with `AT+GTFCCLOCKMODE=0` plus a USB power cycle after `AT+GTFCCEFFSTATUS?` returns `2,0`. The ModemManager `3df8c719` challenge was rejected.
- [CONFIRMED] 4.8.1 ships no eSIM Management view. 4.9.x embeds the drawer in `gl-sdk4-ui-internet.common.js` and POSTs `/sdk/v1`. MT3000 firmware does not ship an eSIM daemon.
- [UNVERIFIED] Correct data interface addressing, `supports_ip_type`, direct-IP prefix, gateway, MTU, and MAC behavior on this router/firmware.
- [CONFIRMED] Stock `function_at_common` reaches SIM insert and reads ICCID/IMSI, then fails before PDP activation with missing `CGDCONT` definitions and a failed minimum-function transition.
- [UNVERIFIED] Whether FM350-only `CFUN=0` to `CFUN=4` translation lets stock `CGDCONT`, `CGACT`, and `CGPADDR` complete.
- [UNVERIFIED] Whether the UI's SIM state failure is caused by the padded ICCID suffix `f`, a failed status poll, or a frontend schema expectation.
- [UNVERIFIED] Whether a later binary allowlist exists after hotplug admission.
- [UNVERIFIED] Mobile-app transport and tolerance of partial capabilities.
- [UNVERIFIED] Runtime behavior of the Lua `.so` fallback and exact GL error propagation.
- [UNVERIFIED] FM350 reset, USB re-enumeration, concurrent polling, and reconnect behavior.
- [UNVERIFIED] Package-level 4.8.1 / MT3000 / `0e8d:7127` retest of slot switch, per-slot APN, `/sdk/v1` profile ops with MSS 80, GTCCINFO modes 4/5, tethering RNDIS filter, and cold-boot persist/restore. Reporter diffs for `AT+GTCCINFO?`, `AT+GTDUALSIM?`, and the exact connectivity predicate were not available; restore uses netifd-up plus address and optional KMWAN member presence.
- [BLOCKED] Ghidra/radare/checksec analysis was unavailable in the pinned analysis container.
- [BLOCKED] Physical GL-MT3000, FM350, supported comparison modem, and mobile app were outside this offline task.
- [BLOCKED] Full advanced Fibocom support needs live schemas and command captures before clean-room handlers can be implemented safely.

Conclusion: [CONFIRMED] The current package is a concrete implementation of the smallest evidence-supported path, not proof of successful FM350 operation in stock UI.

Evidence: all package behavior is syntax/unit-tested and SDK-built where reported; no hardware was used.

Confidence: confirmed.

Alternative explanations: runtime results may expose a narrower fix or an additional proprietary constraint.

How to verify dynamically: execute `docs/validation-plan.md` in order and promote individual statements only after captured evidence.
