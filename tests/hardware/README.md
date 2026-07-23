# Hardware evidence harness

These scripts capture synchronized, diffable evidence without changing router state. Run the client monitor on a laptop behind the router and the router sampler over SSH during one manually controlled lifecycle event.

Artifacts can contain public or private addresses, routes, DNS servers, and interface state. They are ignored by Git. Redact them before attaching to an issue. The sampler intentionally does not query ICCID, IMSI, phone numbers, credentials, or raw AT responses.

## Run

Use the same duration and begin both commands as close together as practical:

```sh
mkdir -p tests/hardware/results
tests/hardware/client-connectivity-monitor.sh \
  --duration 180 \
  --probe-url https://your-controlled-endpoint.example/healthz \
  --expected-code 204 \
  --output tests/hardware/results/client.csv

ssh root@192.168.8.1 'sh -s -- --duration 180 --interface modem_2_1_s1 --output /tmp/router.jsonl' \
  < tests/hardware/router-sampler.sh
scp root@192.168.8.1:/tmp/router.jsonl tests/hardware/results/router.jsonl
```

Trigger exactly one event after baseline samples exist: modem detach/attach, cellular-manager restart, USB reset, package stop, package upgrade or reinstall, package removal, or router reboot. Keep an independent LAN recovery path. The scripts do not trigger or recover disruptive events.

Analyze the result using the expectation appropriate to the case:

```sh
tests/hardware/analyze-run.sh \
  --client tests/hardware/results/client.csv \
  --router tests/hardware/results/router.jsonl \
  --expect transition-recovered \
  --output tests/hardware/results/summary.json
```

Supported expectations are `all-online`, `all-offline`, `final-online`, and `transition-recovered`. A `PASS` only proves the selected connectivity expectation and artifact validity. Review router samples separately before promoting modem or router support to `[CONFIRMED]`.
