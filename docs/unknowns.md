# Remaining unknowns

This page lists remaining gaps for the GL-MT3000 + Fibocom FM350 / Dell DW5931e package. Confirmed behavior lives in the README and `docs/package-design.md`.

## Hardware retest of this tree

A reporter field test on 4.8.1 / MT3000 / `0e8d:7127` is evidence of the earlier tree, not a package-level pass of the current sources. Retest this tree on that same reference before treating these as confirmed:

- slot switch plus independent per-slot APN
- Connect / Disconnect plus actual traffic
- eSIM operations through `/sdk/v1` with MSS 80
- GTCCINFO serving-cell mapping to stock UI modes 4 and 5
- tethering RNDIS filter
- cold-boot persist and restore
- stop / uninstall restore of stock bind-mounts and nginx

## Still unobserved on this repo’s package

- [UNVERIFIED] live carrier profile download with `lpac`
- [UNVERIFIED] 4.9.x / OpenWrt 24 / OpenWrt 25 hardware
- [UNVERIFIED] `0e8d:7126` dual-slot behavior
- [UNVERIFIED] other routers
- [UNVERIFIED] mobile-app tolerance of the community RPC payload

## Contracts we still do not claim

- [UNVERIFIED] exact stock `modem.so` schemas and `gl_modem` I/O for methods this package does not implement
- [UNVERIFIED] `/tmp/<bus>.sock` framing
- [UNVERIFIED] addressing, MTU, and MAC of the RNDIS data path on each firmware
