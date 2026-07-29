# boru admin

Cross-cutting operational tooling for the **boru** libraries (formerly
voxgig-aql): [aless](https://github.com/voxgig-boru/aless),
[bloom-filter](https://github.com/voxgig-boru/bloom-filter),
[decision](https://github.com/voxgig-boru/decision),
[sort](https://github.com/voxgig-boru/sort),
[stats](https://github.com/voxgig-boru/stats),
[template](https://github.com/voxgig-boru/template),
[trie](https://github.com/voxgig-boru/trie).

The per-library repos hold their own source, suites, and CI. This repo holds
what spans all of them: verification/benchmark harnesses and the baseline
snapshots they produce.

## Layout

```
bench/verify-libs.sh   4-surface correctness sweep across all libs
bench/bench-libs.sh    interpret-vs-compiled wall-time benchmark
baselines/             dated snapshots (report + raw timings)
```

## Prerequisites

- Go toolchain (to build `aql`) and a checkout of each library under one
  parent dir (default `~/Projects/voxgig-aql`; edit `LIBS_DIR` in the scripts
  if yours differ).
- An `aql` binary built from the target ref. CI parity build:
  ```bash
  cd <aql>/cmd/go
  GOWORK=off GOFLAGS=-mod=mod go build -o /tmp/aql ./aql
  ```

## Usage

```bash
AQL=/tmp/aql bash bench/verify-libs.sh    # correctness — must end "RESULT: PASS"
AQL=/tmp/aql bash bench/bench-libs.sh     # timings
```

`verify-libs.sh` runs every `test/*_test.aql` / `*_spec.aql` in each lib, from
that lib's repo root, on four surfaces and tallies any deviation:

| surface | command | pass condition |
|---|---|---|
| interpret | `aql --no-compile <suite>` | exit 0 |
| bytecheck | `aql check <suite>` | 0 errors |
| compile-parity | `aql --compile <suite>` | output byte-identical to interpret |
| force-compile | `aql --force-compile <suite>` | compiles fully (no refusal), exit 0 |

## Baselines

See [`baselines/`](baselines/). Latest:
[`BASELINE-2026-07-29.md`](baselines/BASELINE-2026-07-29.md) — aql `f3b80738`,
46 suites, **0 divergences, 0 force-compile refusals**; full compilation across
all 7 libraries.
