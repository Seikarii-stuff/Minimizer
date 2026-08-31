# Benchmark suite audit and methodology

## Scope

The audit started from `Minimizer.toc` and the production tree rather than from the old benchmark. The hot-path review covered the Plater pipeline, overlays, Wheel/Pips, cache, utilities, lifecycle and event dispatch.

### Execution-frequency inventory

| Area | Relevant pattern | Benchmark priority | Reason |
| --- | --- | --- | --- |
| `Plater/Dispatcher.lua` | `ApplyToUnit`, `ApplyToAll`, `OnUpdate` monitor, `pairs/next` | Critical | central fan-out and the only production `OnUpdate` |
| `Plater/Events.lua` | `OnEvent`, unit events, cast events, threat events | Critical | event frequency directly drives pipeline work |
| `Plater/Lifecycle.lua` | register/unregister, generation, removal cleanup | Critical | recycling and retained references |
| `Plater/Snapshot.lua` | classification/threat/absorb/cast aggregation | Critical | hot path and nested work |
| `Plater/Threat.lua` | threat API calls, caches, state transitions | Critical | potentially repeated per-unit work and monitor polling |
| `Plater/Cast.lua` | `UnitCastingInfo`, `UnitChannelInfo` | High | scales with active casters and is intentionally uncached |
| `Plater/Absorb.lua` | absorb API + persistent state | High | called from snapshot and health-bar rendering |
| `Plater/Classification.lua` | unit classification | High | hot path decision input |
| `Plater/Decision.lua` | simplify/unsimplify decisions | High | hot path branch density |
| `Plater/Core.lua` | module fan-out + `pcall` | Critical | per-update module overhead |
| `Plater/HealthBarColor.lua` | health color, absorb visuals, hooks | High | per-nameplate module and lifecycle allocations |
| `Plater/CastingBar.lua` | cast visuals, target marker, hooks | High | per-caster work and cold visual setup |
| `Plater/Markers.lua` | font-string creation and show/hide | Medium | lifecycle allocation + steady-state updates |
| `Overlays/Target.lua` | Halo + stripes + cooldown | High | hot overlay path and throttle behavior |
| `Overlays/Focus.lua` | portrait + cooldown | High | independent path; **does not use Halo** |
| `Overlays/Halo.lua` | frame/texture/cooldown creation, Show/Hide | High | cold vs hot path must be separated |
| `Wheel/Wheel.lua` | update, interrupt, config | Medium/High | player-frame steady-state and interrupt path |
| `Wheel/Pips.lua` | six pip updates, cooldown lookup | Medium/High | repeated work inside Wheel updates |
| `Overlays/Widgets.lua` | cooldown helpers and castbar discovery | Medium | shared utility cost; benchmarked through consumers |
| `Core/Cache.lua` | per-unit cache reads/writes/invalidation | High | allocation and invalidation pressure |
| `Core/Utils.lua` | nameplate lookup, throttle/debounce, hooks | High | shared utilities can amplify caller cost |

The current production tree has no general-purpose `NewTimer`/`NewTicker` usage in the audited hot path. `C_Timer.After` is used by the shared throttle/debounce helpers, while the Dispatcher owns the production `OnUpdate` monitor. The suite therefore measures those actual mechanisms instead of inventing a second polling loop.

## Important audit findings

1. The old benchmark used a single 50-nameplate randomized workload. That is useful as a smoke workload, but it cannot answer scaling, cold/hot lifecycle, stable threat, recycling or component-isolation questions.
2. The old benchmark measured individual `ApplyToUnit` calls with `os.clock()`. On the observed environment, p50/p90 collapsed to `0.000 ms` while p99/max became `1.000 ms`; batch timing is now used so the timer resolution is amortized.
3. The old allocation metric was a no-GC heap delta and was described as generated garbage. The new suite calls this **allocation pressure / heap growth during a no-GC window** and separately reports retained heap after cleanup.
4. `Snapshot.Build()` gathers threat state and then `Decision`, `HealthBarColor` and other consumers may consult threat-related state again. The new integrated and isolated threat measurements are intended to expose this inclusive cost without claiming that component timings are additive.
5. `Cast.GetState()` deliberately has no cache because of nameplate-token recycling correctness. The suite measures both direct cast reads and integrated active-caster workloads rather than assuming caching is desirable.
6. Halo is a shared component for Target and Wheel. Its creation/configuration path is measured separately from `ShowFor`/`Hide` reuse. Focus is explicitly kept separate because it owns a portrait, not Halo.
7. Dispatcher does **not** implement a generic listener registry. Therefore the requested 1/5/10/20-listener matrix is not fabricated. The suite measures the actual dispatcher pipeline and module fan-out; a listener-count benchmark is a documented gap rather than an artificial workload.
8. Target and Focus are global overlays around one selected unit, not N independent overlays. Scaling them by pretending there are 100 simultaneous targets would misrepresent the architecture. Nameplate scaling is measured at the central pipeline, while Target/Focus get isolated lifecycle/hot-path benchmarks.

## Methodology

Each measurement has:

- warmup iterations before timing;
- multiple measured samples;
- a batch of operations per sample;
- mean, p50, p90, p99 and max;
- allocation-pressure measurement with GC stopped only during the timed window;
- retained-memory measurement after scenario cleanup and full collection;
- explicit scenario metadata such as units/casters/state.

The default harness uses 3 warmup batches, 9 measured samples and 100 operations per sample. Individual cold-path measurements lower the batch size so that frame creation does not dominate the process indefinitely.

### Allocation terminology

**Allocation pressure** is the heap growth observed while GC is disabled. It is useful for spotting churn but is not an exact object-allocation counter.

**Retained memory** is the heap delta after the scenario's cleanup and two full collections. It is a leak signal, not a proof by itself; allocator/runtime noise must be considered.

The suite does not claim that every byte allocated in the WoW client is represented by the Lua mock heap.

## Scenarios

- Core scaling: 1 / 10 / 25 / 50 / 100 active plates.
- Classification and Decision: isolated single-unit cost plus integrated scaling.
- Threat: 1 / 5 / 10 / 20 / 50 units, stable cached state vs invalidated event path.
- Event storm: 10 / 50 / 100 plates with plausible threat/cast/absorb/classification events.
- Cast: 1 / 5 / 10 / 20 active casters, direct and integrated paths.
- Absorb: 1 / 10 / 50 / 100 units.
- Target and Focus: isolated overlay updates, with Focus portrait measured independently of Halo.
- Halo: cold creation vs hot reuse.
- Wheel: disabled vs active.
- Pips: hot update and configuration/layout path.
- Steady-state: 10 / 50 / 100 plates with no intentional state changes.
- Recycling: repeated add/update/remove/reuse cycles.
- Integrated Normal: 10 plates, 1 caster, normal threat.
- Integrated Heavy: 50 plates, 10 casters, repeated threat/absorb/cast events and recycling.

## Regression policy

No arbitrary absolute threshold is asserted by the new suite. A threshold is only useful after collecting a stable baseline on the same runtime and machine class. The result format is designed for historical comparison by commit SHA; once a baseline is recorded, a CI comparison can be added without changing the measurement model.

The old `tests/results/benchmark_aggregated.txt` and `benchmark_latest.txt` are historical artifacts and are intentionally not overwritten or deleted by the redesigned suite.

## Running

```text
lua tests/benchmark/benchmark.lua --self-test
lua tests/benchmark/benchmark.lua
```

The full run writes `tests/results/benchmark_suite_latest.csv` and, when a Git working tree is available, a commit-addressed archive. The normal functional test runner remains unchanged so benchmark timing cannot affect its historical test count.
