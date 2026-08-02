# Tasks: Intel x86 Support

## 1. Build target

- [x] 1.1 `build.sh`: replace hardcoded `TARGET="arm64-apple-macosx14.0"` with a `uname -m` switch (`arm64` → arm64 target, `x86_64` → x86_64 target, else exit 1)

## 2. Intel temperature platform

- [x] 2.1 `TemperatureSensorSelector.swift`: add `.intel` case to `CPUTemperaturePlatform`; `platform(brandString:)` returns `.intel` for Intel brand strings
- [x] 2.2 `TemperatureSensorSelector.swift`: `isCPUCoreKey` matches Intel core pattern `TC<n>C` plus `TC0E`/`TC0D`; `hasCPUCoreSet` returns true for `.intel`

## 3. Sensor discovery

- [x] 3.1 `SystemMonitor.swift`: extend `keys(where:)` filter to collect Intel keys `TC*` (CPU), `TG*` (GPU), `TM*` (memory), `Ts*` (battery), keeping existing Apple Silicon prefixes
- [x] 3.2 `SystemMonitor.swift`: classify collected keys into `cpuKeys`/`gpuKeys`/`batteryKeys` for both naming schemes

## 4. Build and verify on x86_64

- [x] 4.1 `./build.sh --test` passes on this Intel machine
- [x] 4.2 `./build.sh` release build succeeds; `file build/Vorssaint` reports x86_64
- [x] 4.3 `./build/Vorssaint --selftest` passes

## 5. Runtime verification

- [x] 5.1 Launch the app and confirm System Monitor shows a plausible CPU temperature from Intel SMC keys (fallback: small harness that enumerates keys via `SMCClient`)

## 6. Documentation

- [x] 6.1 `README.md`: update "What you need" to note Intel Macs build and run locally (official releases remain Apple Silicon)
