# LocalSend v2 transfer baseline

This is an **opt-in diagnostic**, not a normal-CI gate. It starts a small LocalSend v2 receiver in the same process, sends deterministic synthetic payloads through the existing v2 HTTP client/server path, and emits one JSON report on stdout. It makes no production transfer or architecture changes.

## Run it

From the repository root:

```sh
cargo run --release -p localsend --example transfer_baseline --features http -- > transfer-baseline.json
```

The default run uses a fixed seed, three payload sizes (64 KiB, 1 MiB, and 8 MiB), three files per size, a 64 KiB source chunk, and at most two simultaneous uploads. For a given seed and case index, the generated payload is a deterministic function of the absolute byte offset, so both payload bytes and SHA-256 are invariant to source and digest buffer boundaries—including non-aligned sizes such as a 1,048,577-byte chunk. Timings remain machine- and run-dependent.

The receiver binds **only** to IPv4 loopback (`127.0.0.1`) through the loopback-only server start helper. The helper rejects wildcard and non-loopback addresses, and the report includes the actual bound socket address(es); the harness fails closed if any reported receiver address is not loopback. No unauthenticated wildcard receiver is started by the harness.

To reproduce the reviewer’s non-default chunk-size case:

```sh
cargo run --release -p localsend --example transfer_baseline --features http -- \
  --sizes 3MiB --files-per-size 1 --concurrency 1 --seed 42 \
  --chunk-size 1048577 > transfer-baseline-3mib.json
```

For a repeatable receiver-delay and cancellation-probe run:

```sh
cargo run --release -p localsend --example transfer_baseline --features http -- \
  --sizes 64KiB,1MiB,8MiB --files-per-size 3 --concurrency 4 --seed 42 \
  --chunk-size 64KiB --receiver-delay-ms 1 --cancel-probe \
  --cancel-after-ms 50 > transfer-baseline.json
```

Options are `--sizes` (comma-separated positive bytes, or KiB/MiB/GiB suffixes), `--files-per-size`, `--concurrency`, `--chunk-size`, `--seed` (decimal or `0x` hexadecimal), `--receiver-delay-ms`, `--cancel-probe`, and `--cancel-after-ms`. The cancellation delay starts **after the receiver consumer signals that it has received a nonempty body chunk**. The entire probe—including first-byte synchronization, cancellation, client completion, and receiver completion—has a fixed 15-second timeout. Run with `--help` for the short CLI summary. Keep comparisons on the same machine, build profile, OS, and configuration; run several times and compare distributions rather than treating a single sample as a performance claim.

## What the JSON reports

- Source Git revision (`unknown` if Git metadata is unavailable), whether the checkout is dirty (null if unknown), build profile (`debug`/`release`), platform, and actual receiver bind socket addresses.
- Per-file request outcome, receiver byte count and SHA-256, independent exact-size and digest-match flags, receiver accept/reject status, latency, and source-channel send wait time.
- Overall successful bytes, elapsed time, throughput in MiB/s, and nearest-rank p50/p95/p99 upload latency across the regular payload cases.
- Configured concurrency, payload/chunk sizes, seed, and the deliberate source and receiver queue capacities.
- When `--cancel-probe` is supplied: declared probe size, fixed 64 KiB source chunk, fixed 2 ms inter-chunk source delay, 15-second total timeout, delay after first received bytes, client cancellation outcome, receiver observation time, received byte count, and whether the received body is nonzero and shorter than the declared size.
- `receiver_observed_partial_payload` means only that the receiver consumed **more than zero but fewer than the declared bytes** before the request completed. It does **not** claim that a transport disconnect itself was observed. A zero-byte rejection, full-length body with a bad digest, or oversized body is never labelled partial. `correctness_ok` requires all regular uploads to pass the existing protocol checks and, when enabled, both a cancelled client outcome and a nonzero partial receiver observation.
- `totals.source_backpressure_ms` is the sum of per-transfer source-channel send-wait durations. Its explicit JSON definition is included in `source_backpressure_measure`; under concurrency this aggregate may exceed `totals.elapsed_ms` because waits across transfers are summed, not wall-clock-unioned.

The receiver independently counts and hashes every received byte. It only reports successful consumption when both match the deterministic expected size and digest. The server also keeps its normal v2 checksum verification enabled; a successful upload status is an additional protocol-level integrity check.

## Assumptions and limits

- Sender and receiver are in one process and use plain HTTP on IPv4 loopback. This isolates the existing Rust v2 client/server transfer path for a repeatable baseline, but does **not** represent Wi-Fi, WAN, a physical device, or the application’s actual storage provider.
- The receiver consumes a bounded stream and can add a configured per-chunk delay. The source-channel send-wait sum is one partial backpressure observation, not a complete measurement of TCP/kernel buffering or receiver-side blocking.
- The cancellation probe adds a deterministic 16 MiB-or-larger file and uses fixed 64 KiB chunks with a 2 ms inter-chunk delay. It first waits for server-side consumption of body bytes; it measures client cancellation responsiveness and a partial receive, not proof of transport closure or a platform UI’s cancellation path.
- The build profile is inferred from Rust debug assertions. Git revision/status are obtained from the package’s source checkout at runtime and fall back to unknown when Git metadata is unavailable.
- This harness does not bypass or test secure-path authentication and makes no TLS, authentication, file-permission, Android descriptor, filesystem durability, Flutter UI, or production architecture claim.
- RSS and file-descriptor sampling are intentionally omitted. There is no portable, dependency-free process sampler with consistent semantics across the project’s supported platforms; adding platform-specific or third-party sampling would make this initial baseline less comparable rather than more reliable.
- Large sizes increase generation, hashing, and memory/CPU work in the harness itself. The deterministic source is chunked, but the receiver and HTTP stack still consume real buffers. Start with moderate sizes and tune upward deliberately.
