# boru admin

Cross-cutting operational tooling for the **boru** libraries (formerly
voxgig-aql): [aless](https://github.com/voxgig-boru/aless),
[bloom-filter](https://github.com/voxgig-boru/bloom-filter),
[cache](https://github.com/voxgig-boru/cache) (design only),
[decision](https://github.com/voxgig-boru/decision),
[graph](https://github.com/voxgig-boru/graph) (design only),
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

- Go toolchain (to build `boru`) and a checkout of each library under one
  parent dir. By default the scripts look in the directory that contains this
  `admin` checkout; set `LIBS_DIR` otherwise.
- A `boru` binary built from the target ref (default: `boru` on `PATH`):
  ```bash
  cd <boru>/cmd/go
  GOWORK=off GOFLAGS=-mod=mod go build -o /tmp/boru ./boru
  ```

## Usage

```bash
BORU=/tmp/boru bash bench/verify-libs.sh          # correctness — must end "RESULT: PASS"
BORU=/tmp/boru MD=1 bash bench/verify-libs.sh     # … plus a Markdown table
BORU=/tmp/boru BASELINE=baselines/bench-2026-07-29.txt bash bench/bench-libs.sh   # timings
BORU=/tmp/boru bash bench/verify-libs.sh sort trie   # a subset of libraries
```

### One execution path (since boru 2026-09-19)

boru now has **one** execution path: a program compiles to bytecode and runs
on the VM, or it fails with `[boru/compile_failed]` — a compiler defect. The
interpreter fallback is gone, and the `--compile`, `--force-compile` and
`--no-compile` flags (and their `BORU_*` env vars) are retired. The old
four-surface sweep (interpret / bytecheck / compile-parity / force-compile)
therefore collapses to two surfaces, and "the suite runs" now *means* "the
suite fully compiles":

| surface | command | pass condition |
|---|---|---|
| run | `boru <suite>` (from the lib root) | exit 0; assertion suites print `all green` |
| check | `boru check <suite>` | 0 errors |

A run failure is classified **COMPILE** (the emitter refused the program —
the full-compilation gap), **CHECK** (the default pre-flight check refused it)
or **FAIL** (it compiled and ran, but errored or an assertion failed). Each
library's root module is also checked standalone (advisory).

`bench-libs.sh` reports compiled wall time per suite (best of `RUNS`, default
3) and, with `BASELINE=`, the ratio against an older bench file's COMPILE
column.

## Baselines

See [`baselines/`](baselines/). Latest:
[`BASELINE-2026-10-02.md`](baselines/BASELINE-2026-10-02.md) — boru `64c5ab2`
(the single execution path), 9 libraries, 58 suites: **0 compile refusals, 0
check errors, all green**; 3,785 of 3,874 runtime callbacks compiled (the 89
that run on the interpreter are all property-test closures). Fixed-work suites
run ~7× slower than on 2026-07-29 (median; a per-run check + compile cost);
property suites run at a median 0.65× of July's speed (generator-bound).

Previous: [`BASELINE-2026-07-29.md`](baselines/BASELINE-2026-07-29.md) — aql
`f3b80738`, 7 libraries, 46 suites, 0 divergences, 0 force-compile refusals.
