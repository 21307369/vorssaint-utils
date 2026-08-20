# Design: Intel x86 Support

## 1. Build target selection (`build.sh`)

Replace the hardcoded `TARGET` with a `uname -m` switch:

```zsh
case "$(uname -m)" in
    arm64)   TARGET="arm64-apple-macosx14.0" ;;
    x86_64)  TARGET="x86_64-apple-macosx14.0" ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
```

No other build step is architecture-dependent: signing, DMG assembly and the
icon tooling are arch-agnostic.

## 2. Intel temperature platform (`TemperatureSensorSelector.swift`)

Extend `CPUTemperaturePlatform` with a `.intel` case:

- `platform(brandString:)` returns `.intel` when the brand string does not
  start with `Apple M` but contains `Intel`.
- Intel CPU core keys are not a fixed per-generation list like Apple Silicon;
  instead `isCPUCoreKey` matches the classic Intel SMC pattern for core
  temperature: `TC<n>C` (e.g. `TC0C`, `TC1C`, `TC2C`…), plus `TC0E`/`TC0D`
  (efficiency/die) as fallbacks. Core temperature is reported as the max of
  the matched keys, which matches the existing `displayedCPUTemperature`
  aggregation (max of core readings, fallback to max of all readings).
- `hasCPUCoreSet` returns `true` for `.intel`.

## 3. Sensor key discovery (`SystemMonitor.swift`)

Extend the `keys(where:)` filter to also accept Intel-style temperature keys.
Intel temperature keys all share a `<T><location><index><type>` shape, e.g.
`TC0P` (CPU proximity), `TC0C`/`TC1C` (cores), `TG0D` (GPU die), `TM0P`
(memory), `Ts0P` (battery). The filter gains:

- `TC` prefix → CPU keys (classified as `cpuKeys`, cores via the `TC<n>C`
  pattern in `isCPUCoreKey`)
- `TG` prefix → GPU keys
- `TM` prefix → memory keys (falls into the generic temperature bucket)
- `Ts` prefix → battery keys (existing `TB` pattern already covers Apple
  Silicon battery keys; keep both)

Filtering by prefix keeps the existing Apple Silicon behavior intact (`Tp`/`Te`/
`Tg`/`TB[0-9]T`), so both architectures share one code path. Unknown keys are
simply not collected; nothing crashes.

## 4. Graceful degradation (no change needed)

Already in place and verified by the audit:

- `PowerSampler` reads `PSTR`/`PDTR` via `key(named:)` — returns nil when
  absent, UI shows no data. (Many Intel Macs do expose `PSTR`/`PDTR`, so
  system wattage often works as-is.)
- GPU usage reads `IOAccelerator` → `PerformanceStatistics`; on Intel the
  dictionary shape differs and the read returns nil, handled by optional
  plumbing.
- Per-process GPU time (`accumulatedGPUTime`) is AGX-only → empty on Intel.
- Extra brightness (`xdrModelIdentifiers`) only lists Apple Silicon models →
  self-disables on Intel.
- External display DDC walks `AppleCLCD2`/`IOMobileFramebufferShim` → not
  found on Intel, falls back to software gamma dimming.

## 5. Verification

This machine is x86_64 (macOS 14.8.7, Xcode 16.2), so the whole verification
runs locally:

1. `./build.sh --test` — unit/selftest suite passes.
2. `./build.sh` — release build succeeds, `.app` assembles and signs.
3. `./build/Vorssaint --selftest` — binary self-test passes.
4. Manual: launch and confirm the System Monitor shows a real CPU temperature
   reading (Intel SMC keys enumerated).
