# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**fd1** is a Garmin ConnectIQ watch app (Monkey C language) for freediving pool training. It tracks dive/rest intervals, enforces the 2× surface rule, and saves sessions as FIT activities. Target devices: `instinct2s`, `instinct2x`, `fenix6pro`.

## Build & Run

This project uses the **Monkey C** toolchain via the VS Code ConnectIQ extension. There is no CLI build script — all builds and tests are launched through VS Code:

- **Run App**: VS Code Debug → "Run App" (launches in simulator for selected device)
- **Run Tests**: VS Code Debug → "Run Tests" (runs Monkey C unit tests in simulator)
- **Build**: `Monkey C: Build` from the VS Code command palette

The compiled output lands in `fd1/bin/fd1.prg`. The manifest (`fd1/manifest.xml`) drives device targeting and permissions.

## Architecture

All source lives in `fd1/source/`. The app follows Garmin's View/Delegate pattern:

```
Fd1App         — AppBase entry point; wires together state, view, and delegate
Fd1State       — Core state machine (in Fd1Util module); owns mode transitions,
                 timer logic, wait-mode calculations, pressure-based auto-start,
                 heart rate polling, and vibration/tone notifications
Fd1View        — Renders two pages (page 1: session info + HR; page 2: settings summary);
                 drives a 1-second Timer that calls Ui.requestUpdate()
Fd1Delegate    — Button handler (Select = changeMode, Menu = settings, Back = save/exit,
                 Up/Down = page flip)
Fd1MenuDelegate — Settings menus: Start Mode, Wait Mode, Notification Options
Fd1SessionRecorder — Wraps ActivityRecording session; records laps per dive,
                     tracks min HR as a custom FIT field, saves on finish
```

### State machine (`Fd1State.mode`)

- `"REST"` → countdown timer counts down; `"DIVE"` → holdTime counts up
- `changeMode()` transitions between them, calculates rest duration based on `waitMode`
- `waitMode` options: `x2` (2× last dive), `30sec`, `1min`, `co2` (CO2 table: 120s − 15s×cycle, floor 30s)
- `startMode`: `manual` (button press) or `auto` (pressure sensor crosses threshold)

### Settings persistence

`Fd1State.saveSettings()` / `loadSettings()` use `Toybox.Application.Storage` (key-value store). Settings saved: `startMode`, `waitMode`, `notification_option_label`, and the three notify flags.

### Resources

- `resources/strings/strings.xml` — all UI strings (menu labels, app name)
- `resources/menus/` — XML-defined menus: `main_menu`, `start_mode_menu`, `wait_mode_menu`, `notification_mode_menu`
- `resources/layouts/layout.xml` — `MainLayout` (single centered label; most drawing is done programmatically in `Fd1View`)
- `resources/drawables/` — PNG icons (heart, diving mask, clock, launcher icon)

### Permissions (manifest.xml)

`Fit`, `FitContributor`, `Sensor`, `SensorHistory`, `SensorLogging`

## Key Monkey C Notes

- `static var` on View/Delegate classes is used as a workaround for passing state (Monkey C has limited constructor flexibility).
- `Fd1View.mFdState` and `Fd1Delegate._FdState` are `static` — there is only ever one instance, so this is intentional.
- `test_Fd1Util.mc` is the unit test file; it's currently empty (1 line). Tests run via the "Run Tests" launch config.
- The `formatSecundes` function (note the typo — keep it consistent) formats seconds as `M:SS`-style output.
