# Benchmark suite: fast and deep profiles

The benchmark suite is designed for two jobs: fast regression detection during development and deeper performance investigation when an optimization question needs more resolution.

## Running

```text
lua tests/benchmark/benchmark.lua
lua tests/benchmark/benchmark.lua fast
lua tests/benchmark/benchmark.lua deep
lua tests/benchmark/benchmark.lua --self-test
```

The default is **Fast**. It keeps representative coverage of Core/Dispatcher, Classification, Decision, Threat, Events, Cast, Absorb, Target, Focus, Halo, Wheel, Pips, steady-state, recycling and integrated workloads. Deep runs the complete scaling/microbenchmark matrix.

## Why the runner is faster

The previous runner performed a full two-pass collection around every measurement. That made the harness itself a substantial part of the runtime, especially for cheap microbenchmarks. The new harness:

1. times batches rather than individual ultra-short calls;
2. uses profile-driven warmup/sample counts and operation batches;
3. stops GC during measured CPU samples for consistent timing;
4. performs full collection only for allocation/retention scenarios that need isolation;
5. makes allocation pressure opt-in per scenario in Fast, while Deep enables it broadly;
6. measures setup, cleanup, measured operation time and total runner time separately;
7. shares scenario definitions between Fast and Deep; only the profile changes depth.

This is not an iteration-count-only optimization: most of the removed runtime was measurement infrastructure and repeated collection, not workload coverage.

## Statistical methodology

Fast uses 2 warmup rounds and 7 measured samples; Deep uses 3 warmup rounds and 15 measured samples. Each sample executes a batch selected by scenario cost (`tiny`, `normal`, `heavy`, or `cold`). This keeps timer resolution useful without forcing the same operation count on every benchmark.

Each result reports mean, p50, p90, p99 and max over sample timings. With seven Fast samples, p99 is effectively the upper observed sample; it is retained for schema compatibility and regression visibility, while Deep is preferred when tail-resolution matters.

The timing denominator is always the number of operations in the batch, so increasing batch size improves timer resolution without changing the meaning of `msPerOperation`.

## Allocation and retention

**Allocation pressure** is heap growth during a GC-stopped measured window. It is not an exact Lua object-allocation counter.

**Retained memory** is measured only for scenarios that opt into retention, after cleanup and forced collection. Negative values are treated as allocator/runtime noise, not evidence of a leak.

Fast includes allocation smoke coverage in Threat invalidation, Halo cold creation, recycling and the integrated heavy workload. Fast also performs a retention smoke check through recycling. Deep enables the full allocation/retention protocol for all applicable scenarios.

## Runtime budget and profiling

The runner prints total time and decomposes it into:

```text
Total benchmark time
Measured operation time
Harness overhead
  setup
  cleanup
Group runtime
```

This prevents a slow benchmark runner from being mistaken for slow addon code. The CSV stores the same timing metadata plus `profile` and the detected Git commit SHA.

The intended Fast budget is roughly **5–10 seconds** on the development machine class. The exact value is environment-dependent; this repository change does not fabricate a timing claim when it cannot execute the benchmark environment. A stable local baseline should be recorded before introducing hard regression thresholds.

## Parallelism

The addon benchmark is intentionally single-process/single-VM. Parallel workers would contend for host CPU and make CPU-time samples from independent workers less reproducible; they also provide no useful speedup for the in-process Lua mock environment without changing the measurement target. The suite therefore optimizes the serial harness instead of parallelizing measurements.

If parallel execution is investigated later, it should be an orchestration layer that runs independent VMs and compares serial vs 2/4/8-worker variance before becoming a default.

## Fast vs Deep

| Capability | Fast | Deep |
| --- | :---: | :---: |
| Core / Dispatcher | ✓ | ✓ |
| Threat representative workload | ✓ | ✓ |
| Threat full scaling/cache/invalidation | — | ✓ |
| Cast multi-caster workload | ✓ | ✓ |
| Cast full scaling | — | ✓ |
| Target / Focus / Halo / Wheel / Pips | ✓ | ✓ |
| Steady-state | ✓ | ✓ |
| Recycling | ✓ | ✓ |
| Integrated Normal + Heavy | ✓ | ✓ |
| Full scaling matrix | — | ✓ |
| Allocation smoke | ✓ | ✓ |
| Full retention/allocation depth | — | ✓ |
| Higher sample count | — | ✓ |

Fast answers: **did something important regress?** Deep answers: **where, how, and how does it scale?**

## Parallelism decision

No worker-count speedup experiment is checked into the suite because the repository's benchmark is a Lua process rather than an external worker farm, and the available development/test tooling cannot execute multiple isolated benchmark VMs from inside the benchmark itself. Adding a fake in-process worker abstraction would measure contention/harness behavior rather than addon CPU cost.

## Results

The historical result files under `tests/results/` are preserved. New runs write:

```text
tests/results/benchmark_suite_latest.csv
tests/results/benchmark_suite_<commit>_<profile>.csv
```

If Git is unavailable, the SHA is reported as `unknown`; when the benchmark is run from a Git checkout, `git rev-parse HEAD` is used so the result is tied to an exact commit.
