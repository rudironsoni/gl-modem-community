# Extraction failures

## 2026-07-19 host extraction attempt

The first case-sensitive SquashFS extraction was archived successfully, but extracting that tar into the macOS workspace failed on the device node:

```text
./dev/console: Can't create 'dev/console': Operation not permitted
tar: Error exit delayed from previous errors.
```

The reproducible alternative keeps the complete tar, including device metadata, under the ignored `work/` directory and excludes `./dev/*` only when materializing the inspection copy under `extracted/rootfs/`.

