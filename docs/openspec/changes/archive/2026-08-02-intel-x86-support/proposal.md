# Intel x86 Support

## Motivation

Vorssaint currently targets Apple Silicon only: `build.sh` hardcodes
`TARGET="arm64-apple-macosx14.0"`, and the SMC temperature sensor mapping only
knows Apple Silicon keys (`Tp*`/`Te*`/`Tg*`). On an Intel x86 Mac the project
cannot even compile, and users on Intel hardware (still common, and macOS 14
Sonoma still supports Intel) cannot run the app at all.

This change makes the project build and run on Intel x86 Macs while keeping
Apple Silicon builds unchanged.

## Goals

- `./build.sh` compiles a working x86_64 build on Intel Macs and keeps producing
  arm64 builds on Apple Silicon.
- CPU/GPU/battery temperature sensors report real values on Intel Macs by
  reading Intel SMC keys (`TC*`/`TG*`/`TM*`/`Ts*` style naming).
- Features that rely on Apple Silicon-only hardware (XDR extra brightness,
  per-app GPU time) degrade gracefully instead of showing empty data.
- All existing tests still pass on both architectures.

## Scope

In scope:

- `build.sh`: architecture-aware `TARGET` selection.
- `TemperatureSensorSelector.swift`: new `.intel` platform with Intel CPU core
  key detection.
- `SystemMonitor.swift`: SMC temperature key filter extended to Intel key
  naming.
- README support statement update.

Out of scope:

- Universal binaries (`arm64,x86_64` combined). A single-arch build per machine
  keeps the build simple and avoids signing/size complexity.
- Intel GPU per-process usage (`accumulatedGPUTime` is AGX-only); existing
  graceful degradation already covers it.
- External display DDC via Intel framebuffer (`AppleCLCD2` is Apple Silicon
  only; the software gamma fallback already exists).

## Risks

- Intel SMC key naming varies by generation; the approach matches by prefix and
  data type (`sp78`) rather than a fixed model list, so it degrades to "no
  reading" rather than wrong readings on unknown hardware.
- The SMC ABI (`SMCParamStruct`) is identical on Intel; only key names differ.
