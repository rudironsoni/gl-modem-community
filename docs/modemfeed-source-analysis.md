# modemfeed FM350 evidence

Source: [koshev-msk/modemfeed](https://github.com/koshev-msk/modemfeed/tree/528e0dfc4ad1cc813e39eb1ca04794a539e894e2), pinned at `528e0dfc4ad1cc813e39eb1ca04794a539e894e2`.

## Conclusion

[CONFIRMED] `xmm-modem` `0.1.7-r1` supplies a non-resident netifd protocol for FM350 USB modes `0e8d:7126` and `0e8d:7127`. It is a connection implementation, not a replacement for GL.iNet's identity, SIM, signal, cell, capability, RPC, or websocket backend.

Evidence: [`packages/net/xmm-modem/Makefile`](https://github.com/koshev-msk/modemfeed/blob/528e0dfc4ad1cc813e39eb1ca04794a539e894e2/packages/net/xmm-modem/Makefile), [`xmm.sh`](https://github.com/koshev-msk/modemfeed/blob/528e0dfc4ad1cc813e39eb1ca04794a539e894e2/packages/net/xmm-modem/root/lib/netifd/proto/xmm.sh), and [`luci.proto.xmm`](https://github.com/koshev-msk/modemfeed/blob/528e0dfc4ad1cc813e39eb1ca04794a539e894e2/luci/protocols/luci-proto-xmm/root/usr/libexec/rpcd/luci.proto.xmm).

Confidence: confirmed.

Alternative explanations: none for the source-level package boundary. Runtime behavior on this GL-MT3000 firmware remains untested.

How to verify dynamically: compare netifd state, the AT port, `+CGPADDR`, `+GTDNS`, routes, and DNS on Rudi's known-working vanilla OpenWrt setup and then on the stock firmware test plan.

## Confirmed contract

- USB `0e8d:7126` uses AT USB interface `04`; `0e8d:7127` uses interface `06`.
- UCI inputs are `device`, `apn`, `pdp`, `delay`, `pincode`, `username`, `password`, `auth`, `profile`, and `maxfail` plus netifd defaults.
- Dependencies are `comgt`, `kmod-usb-acm`, `kmod-usb-serial-option`, `kmod-usb-net-cdc-ncm`, and `kmod-usb-net-rndis`.
- FM350 authentication uses `AT+CGAUTH`; session setup uses `AT+CGDCONT`, `AT+CGACT`, and `AT+CGPADDR`; DNS uses `AT+GTDNS`.
- It does not use MBIM and does not change USB composition with `AT+GTUSBMODE`.

The separate `modeminfo` `0.4.7-r3` FM350 profile queries `COPS`, `CEREG`, `CGREG`, `CESQ`, `GTCCINFO`, `GTCAINFO`, `GTSENRDTEMP`, `GTPKGVER`, `CGMI`, `CGMM`, `CGMR`, `CIMI`, `ICCID`, and `CGSN`. Its output includes identity, SIM identifiers, registration, RSSI, SINR, RSRP, RSRQ, EARFCN, PCI, bandwidth, cell, temperature, and carrier aggregation.

## Behaviors not copied unchanged

- A hard-coded data-interface MAC of `00:00:11:12:13:14`.
- A fixed IPv4 `/24` and synthesized `.1` gateway without validation.
- Ignored authentication, connect, and disconnect errors.
- A teardown profile fixed to `1`.
- Unconditional `AT+XDATACHANNEL=0` for FM350.
- Global `kill -9` of other `modeminfo` and `atinout` processes.
- UCI mutation during port probing.

`xmm-modem` ships GPLv3 text. `luci-proto-xmm` declares Apache-2.0. [UNVERIFIED] `modeminfo` has no clear package-level license at the pinned revision, so its parser implementation is not copied; only its public command and response contract is used as clean-room evidence.

