# Benchmark suite: Fast and Deep

The benchmark has two jobs: fast daily regression detection and deeper performance investigation. It remains single-process/single-VM so CPU contention or fake worker parallelism cannot contaminate Lua timing.

## Running

```text
lua tests/benchmark/benchmark.lua
lua tests/benchmark/benchmark.lua fast
lua tests/benchmark/benchmark.lua deep
lua tests/benchmark/benchmark.lua --self-test
```

The default is **Fast**. Fast keeps representative coverage of Core/Dispatcher, Classification, Decision, Threat, Events, Cast, Absorb, Target, Focus, Halo, Wheel, Pips, steady-state, recycling and integrated workloads. Deep runs the complete scaling/microbenchmark matrix plus the more expensive memory experiments.

`--self-test` is a harness check, not a functional test. `tests/test_all.lua` deliberately does not invoke it because doing so would duplicate benchmark startup work.

## Timing methodology

Lua `os.clock()` is CPU time and can be too coarse for microsecond operations. After warmup, tiny and normal profile-selected scenarios perform a one-time calibration batch. If that batch is below the profile's useful timing window, the batch is increased up to a cost-specific cap. The measured samples then time the calibrated batch and divide by its logical operation count.

Explicit batches are never changed. Heavy/cold scenarios keep their explicit batches because multiplying expensive work only to satisfy a timer would distort the workload. This is adaptive batching for timer resolution, not an assertion that a raw `0.000000` sample means zero cost.

Fast uses 2 warmups and 7 measured samples; Deep uses 3 warmups and 15. Results report mean, p50, p90, p99 and max. With seven Fast samples, p99 is necessarily close to the highest observed sample; Deep is preferred for tail investigation.

## Threat

Threat deliberately separates query cost from population work:

1. `threat.query.N` isolates a single `GetUnitThreatState` query. `N` is metadata here, not work performed per operation.
2. `threat.multi_unit.N` makes one logical operation query every tracked unit, so workload grows with `N`.
3. `threat.invalidation.N` invalidates and queries every tracked unit in each logical operation, representing a changed/event path across the tracked population.

No production Threat code is changed to make these measurements possible.

## Cast

`cast.query.N` isolates one caster's state query. `cast.pipeline.N` processes all `N` active casters per logical operation and performs cast state detection plus `Dispatcher.ApplyToUnit`. This makes the incremental cost of simultaneous casters visible instead of merely rotating a single query through a larger table.

## Memory methodology

**Allocation pressure** is net heap growth during a GC-stopped measured window. It is not an exact Lua allocation counter: allocation and reuse can cancel in net heap size, so zero growth does not prove zero allocations.

**Retained memory** is the heap delta after cleanup and forced collection. A single positive delta does not prove a leak, and a negative delta is allocator/runtime noise rather than proof of reclamation.

Lifecycle recycling compares 1, 10 and 100 repeated cycles in Deep, with a reduced 1/10 smoke sweep in Fast. The intended leak signal is progressive retained growth as cycle count increases.

## Run metadata

Every new benchmark result records the UTC start timestamp and the benchmark schema version. The timestamp identifies **when** a measurement was taken; it is not a version identifier and does not identify the exact source revision.

New output uses:

```text
timestamp=YYYY-MM-DDTHH:MM:SSZ
benchmark_schema=v5
```

The CSV stores `timestamp` as run-level metadata and no longer contains `commit` or `commit_source` fields. Archived result filenames use the timestamp and profile, for example `benchmark_suite_20260831T184213Z_fast.csv`.

Historical result files are preserved as-is. Older files may contain commit metadata because they were produced by an earlier schema; their metadata is not rewritten or given fabricated timestamps. New and historical result formats should therefore be interpreted according to the schema documented by the run that produced them.

## Runner integration

`tests/test_all.lua` treats functional tests and benchmarks as separate categories. Functional tests are judged by process exit status plus their own summaries. The benchmark is then run as `fast`; its exit status is authoritative and the runner additionally requires the explicit `Status: PASS` line. Benchmark stdout is never passed through the functional `FAIL` parser.

The functional test list intentionally excludes helper/debug files and the benchmark itself; the benchmark is invoked exactly once in its own section. The harness self-test remains independent. This avoids the old failure mode where benchmark output looked like an ordinary test result such as `... OK` while hiding the actual benchmark summary.

## Output

The CSV stores `profile`, `timestamp`, `benchmark_schema`, total/measurement/harness timing, setup/cleanup timing, timing percentiles, `heap_growth_kb`, `heap_growth_kb_per_op`, and `retained_kb`. The benchmark prints a compact summary including total runtime, measured operation time, harness overhead, timestamp and explicit status.

The intended Fast budget is roughly **5–10 seconds or less** on the development machine class. The suite does not trade away coverage merely to hit a lower number; if an 8-second run is more stable than a 4-second run, the 8-second run is preferred.

## Reproducibility

For a baseline, run Fast five times in the same environment and record timestamp, total runtime, representative p50/p90/p99 values and memory columns. Run Deep separately for full scaling, allocation and retention analysis. Because timestamp is temporal metadata rather than source identity, preserve the benchmark input/configuration alongside baselines when exact source provenance matters.
