# Unknowns and blocked evidence

- [UNVERIFIED] Exact JSON schemas, optional fields, timeouts, and numeric errors for each proprietary RPC method.
- [UNVERIFIED] Exact stdout, stderr, exit codes, signals, concurrency, and timeout behavior for every `gl_modem` command.
- [UNVERIFIED] Proprietary `/tmp/<bus>.sock` framing.
- [UNVERIFIED] Whether FM350 `CGMI`/`CGMM` response formatting passes the stock common parser.
- [UNVERIFIED] Correct `ttyACM` offset, data interface name, `supports_ip_type`, direct-IP prefix, gateway, MTU, and MAC behavior on this router/firmware.
- [UNVERIFIED] Whether a later binary allowlist exists after hotplug admission.
- [UNVERIFIED] Mobile-app transport and tolerance of partial capabilities.
- [UNVERIFIED] Runtime behavior of the Lua `.so` fallback and exact GL error propagation.
- [UNVERIFIED] FM350 reset, USB re-enumeration, concurrent polling, and reconnect behavior.
- [BLOCKED] Ghidra/radare/checksec analysis was unavailable in the pinned analysis container.
- [BLOCKED] Physical GL-MT3000, FM350, supported comparison modem, and mobile app were outside this offline task.
- [BLOCKED] Full advanced Fibocom support needs live schemas and command captures before clean-room handlers can be implemented safely.

Conclusion: [CONFIRMED] The current package is a concrete implementation of the smallest evidence-supported path, not proof of successful FM350 operation in stock UI.

Evidence: all package behavior is syntax/unit-tested and SDK-built where reported; no hardware was used.

Confidence: confirmed.

Alternative explanations: runtime results may expose a narrower fix or an additional proprietary constraint.

How to verify dynamically: execute `docs/validation-plan.md` in order and promote individual statements only after captured evidence.
