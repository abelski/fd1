# Codebase research — fd1

A map for agents to read before they grep the repo. Every claim cites a file or `file:line`.
`(inferred)` marks things that were reasoned about, not read directly. This file describes the working tree,
including uncommitted changes (pool length, dive distance and speed, and the Adjust Distance menu, per `git status`).
Plan 1 items 10–11 later added code to `fd1/source/Fd1Util.mc` and `fd1/source/Fd1View.mc`. Line numbers in those
two files can be off by up to about 30 lines, so search by function name.

## 1. What it is

fd1 ("FreeDive timer", `fd1/resources/strings/strings.xml:2`) is a Garmin ConnectIQ watch app for freediving
pool training. It switches between REST and DIVE. A REST interval counts down, and its length is set by a wait
mode, by default twice the last dive (the 2× surface rule, `README.md`). A dive can start on a button press or
automatically when the barometer sees depth. During a dive the app counts pool lengths from accelerometer spikes.
It shows heart rate, the clock and session totals, vibrates and beeps for notices, and records the session as a
FIT activity with one lap per dive.

## 2. Stack and entry points

- Language: Monkey C, ConnectIQ manifest v3, `minApiLevel="2.2.0"` (`fd1/manifest.xml:8`).
- App type `watch-app`, entry class `Fd1App` (`fd1/manifest.xml:8`).
- Targets: `instinct2s`, `instinct2x`, `fenix6pro` (`fd1/manifest.xml:17-19`).
- Permissions: Fit, FitContributor, Sensor, SensorHistory, SensorLogging (`fd1/manifest.xml:26-30`).
- Build config: `fd1/monkey.jungle:1` (manifest only, with default source and resource paths (inferred)).
- Startup: `Fd1App.getInitialView` (`fd1/source/Fd1App.mc:26-38`) creates the FIT recorder, the state (and
  loads its settings), the view and the delegate, then returns `[view, delegate]`.
- Shutdown: `Fd1App.onStop` calls `_session.finish()` (`fd1/source/Fd1App.mc:20-23`).
- Run and test launchers: VS Code `monkeyc` launch configs (`.vscode/launch.json`). There is a second copy with
  an extra "Run Native Pairing" config in `fd1/.vscode/launch.json`.

## 3. Layout

- `fd1/` — the ConnectIQ project: manifest, jungle, source, resources.
- `fd1/source/` — all Monkey C code, flat: 7 `.mc` files plus `test_Fd1Util.mc`. `Fd1AdjustDistanceView.mc` was
  added by plan 1.
- `fd1/resources/` — strings, menus, layout and drawables (XML and PNG).
- `fd1/bin/` — build output, gitignored (`.gitignore:5`).
- `.vscode/` — launch configs for Run App, Run Tests and Run Complication Apps.
- `.claude/skills/feature-creator/` — repo-local skill with CLI build and run commands.
- `plans/`, `specs/`, `docs/` — moonlight SDLC folders (plans, component specs, this file).

## 4. Main flows

**A. App start**
1. `fd1/source/Fd1App.mc:26-38` — `getInitialView`.
2. `fd1/source/Fd1SessionRecorder.mc:131-140` — `Fd1Activity.initialize`: creates the FIT session and custom
   fields, and starts a 1 s `refreshActivityStats` timer.
3. `fd1/source/Fd1Util.mc:94-127` — `Fd1State.loadSettings`, with a default for each missing key.
4. `fd1/source/Fd1View.mc:35-43` — `onLayout` starts two 1 s timers: UI redraw, and pressure.

**B. Dive / rest cycle (manual and auto)**
1. Manual: Select → `Fd1Delegate.onSelect` (`fd1/source/Fd1Delegate.mc:20-25`).
   Auto: `Fd1View.pressureCallback` (`fd1/source/Fd1View.mc:29-32`) → `Fd1State.updatePressure`
   (`fd1/source/Fd1Util.mc:335-376`). This fires after 3 matching ticks (`fd1/source/Fd1Util.mc:55`).
2. `Fd1State.changeMode` (`fd1/source/Fd1Util.mc:252-289`):
   - REST→DIVE: `session.startSession()` (`fd1/source/Fd1SessionRecorder.mc:49-58`), resets the dive counters and
     turns on sensor events.
   - DIVE→REST: computes distance and speed, calls `session.updateDiveMetrics` (`fd1/source/Fd1SessionRecorder.mc:97-104`)
     and `session.stopSession()`, then sets the rest length from `waitMode`. The CO2 rest is `getCo2Rest`
     (`fd1/source/Fd1Util.mc:239-248`).
3. Manual only: `informNotice` plays a tone and a 2 s vibration (`fd1/source/Fd1Util.mc:231-237`).
4. Every redraw: `Fd1View.onUpdate` (`fd1/source/Fd1View.mc:52-68`) → `updateTimer` (`fd1/source/Fd1Util.mc:290-332`)
   counts up or down and vibrates → `updateHeartrate` (`fd1/source/Fd1Util.mc:378-390`) → draws page 1 or 2.
5. During a dive:
   - `startAccel` registers a 25 Hz accelerometer listener, and `stopAccel` removes it at dive end.
   - `onSensorData` passes each 1 s batch plus the compass heading to `onAccelSamples`. That logs both to FIT
     (`logSample`) and counts at most one turn.
   - A turn is the 8 s mean heading flipping by more than 120° (`headingFlipped`). The push-off spike is used only
     when no heading came in.
   - After the start and after each turn, `minLengthTicks()` (pool length × 2/3 s) blocks a new turn.
   - A dive starts on length 1.

**C. Settings menu**
1. Menu → `Fd1Delegate.onMenu` (`fd1/source/Fd1Delegate.mc:33-38`) pushes `MainMenu` (`fd1/resources/menus/main_menu.xml`).
2. `Fd1MenuDelegate.onMenuItem` (`fd1/source/Fd1MenuDelegate.mc:17-35`) pushes a sub-menu.
3. The sub-menu delegate (`fd1/source/Fd1MenuDelegate.mc:59-133`) calls `Fd1State.setNotificationOption`,
   `setWaitingMode`, `setStartMode`, `setPoolLength` (`fd1/source/Fd1Util.mc:129-227`). Adjust Distance instead switches to the correction screen
   `AdjustDistanceView` (`fd1/source/Fd1AdjustDistanceView.mc`), where UP and DOWN call `adjustDistance(±10)`.
4. Each setter except the length adjusters calls `saveSettings` (`fd1/source/Fd1Util.mc:81-91`).

**D. Save and exit**
1. Back → `Fd1Delegate.onBack` shows "Save & exit?" (`fd1/source/Fd1Delegate.mc:27-31`).
2. Yes → `ConfirmationDelegate.onResponse` calls `System.exit()` (`fd1/source/Fd1Delegate.mc`). The old
   `popView` there crashed the simulator before `onStop`; plan 1 fixed it.
3. `Fd1App.onStop` → `Fd1Activity.finish` stops and saves the FIT session (`fd1/source/Fd1SessionRecorder.mc:142-146`).

## 5. Data

- No database and no migrations.
- Settings live in `Toybox.Application.Storage`, a key-value store (`fd1/source/Fd1Util.mc:5`). The keys are
  `startMode`, `autoStartPressure`, `waitMode`, `poolLength`, `notification_option_label`, `needNotify1min`,
  `needNotify30sec` and `needNotifyStart` (`fd1/source/Fd1Util.mc:81-91`). The defaults are in
  `fd1/source/Fd1Util.mc:94-127`.
- The session is a FIT activity: sport `SPORT_GENERIC`, sub-sport 62 "breathworks" (`fd1/source/Fd1SessionRecorder.mc:11-19`).
- Custom FIT fields (`fd1/source/Fd1SessionRecorder.mc:66-93`):
  - `min_hr`: id 0, UINT16, session message.
  - `dive_distance`: id 1, FLOAT m, lap message.
  - `dive_speed`: id 2, FLOAT m/s, lap message.
- Laps: the first dive starts the recording. Each later dive calls `addLap()` (`fd1/source/Fd1SessionRecorder.mc:43-58`).
- Runtime state is the fields of `Fd1State` (`fd1/source/Fd1Util.mc:30-69`).

## 6. Configuration and external services

- No environment variables, no `.env`, no network calls (grep of `fd1/source/`).
- Device sensors:
  - Barometer: `Activity.getActivityInfo().ambientPressure` (`fd1/source/Fd1Util.mc:338`).
  - Accelerometer: `Sensor.registerSensorDataListener` at 25 Hz, 1 s period, only during a dive (`startAccel` and
    `stopAccel` in `fd1/source/Fd1Util.mc`).
  - Heart rate: `currentHeartRate`, falling back to `ActivityMonitor.getHeartRateHistory` (`fd1/source/Fd1Util.mc:379-389`).
- Notices use `Toybox.Attention` tones and vibration (`fd1/source/Fd1Util.mc:231-237`, `:297-328`).
- Tuning constants: pressure thresholds (`fd1/source/Fd1Util.mc:53-55`) and the accelerometer threshold
  (`fd1/source/Fd1Util.mc:64-65`).
- Toolchain: the ConnectIQ SDK and the developer key live outside the repo. Their paths are named in
  `.claude/skills/feature-creator/SKILL.md:12-13`.

## 7. Tests

- The test file is `fd1/source/test_Fd1Util.mc`. It was empty before plan 1 and now has 21 `(:test)` functions,
  plus `StubSession` and `Sim` helpers. `Sim.dive` simulates a whole dive with a synthetic 25 Hz accelerometer
  signal.
- Run them with the VS Code "Run Tests" launch config (`runTests: true`, `.vscode/launch.json`). The engine is the
  ConnectIQ simulator's `Toybox.Test` runner (inferred).
- Coverage:
  - Covered: lengths, distance, speed, turn detection, the ±10 m correction, the FIT values sent, STA, the
    formatters including `formatSecundes`, and the settings round-trip.
  - Not covered: the `changeMode` rest lengths, `getCo2Rest` and the `updatePressure` debounce.
  - CLI run: see `## Build & Run` in CLAUDE.md. The tests need the simulator to be running.

## 8. Commands

See `## Build & Run` in `CLAUDE.md`. The file has no `## Commands` heading. The CLI build and run lines are in
`.claude/skills/feature-creator/SKILL.md:16-17` and `:82-101`.

## 9. Conventions

- Naming: classes and modules use the `Fd1` prefix (`fd1/source/Fd1App.mc:8`, `fd1/source/Fd1Util.mc:30`).
  Field case is mixed: camelCase `holdTime` (`fd1/source/Fd1Util.mc:34`) and snake_case
  `notification_option_label` (`fd1/source/Fd1Util.mc:44`). Private fields use a `_` prefix
  (`fd1/source/Fd1Util.mc:51`) or an `m` prefix (`fd1/source/Fd1SessionRecorder.mc:29`).
- Modes are strings, not enums. They are compared as `"REST".equals(mode)` (`fd1/source/Fd1Util.mc:253`).
- Menu item ids are matched as strings in the state setters, via `item.toString()`
  (`fd1/source/Fd1MenuDelegate.mc:68`, `fd1/source/Fd1Util.mc:149-161`).
- State is shared through `static var` plus a `setvarfd1State` setter (`fd1/source/Fd1View.mc:11-21`,
  `fd1/source/Fd1Delegate.mc:5-10`). Sub-menu delegates take the state in their constructor
  (`fd1/source/Fd1MenuDelegate.mc:62-65`).
- Error handling is a null check with an early return. Nothing is thrown (`fd1/source/Fd1SessionRecorder.mc:113-115`,
  `fd1/source/Fd1Util.mc:197-199`).
- Settings setters persist right away by calling `saveSettings()` (`fd1/source/Fd1Util.mc:146`).
- Module boundaries:
  - Module `Fd1Util` holds the state and the formatters (`fd1/source/Fd1Util.mc:9`).
  - Module `Fd1SessionRecorder` holds the FIT recording (`fd1/source/Fd1SessionRecorder.mc:9`).
  - The views and delegates are global classes (`fd1/source/Fd1View.mc:10`).
- Timers: the view runs two 1 s timers, UI redraw and pressure. The recorder runs a third, for HR stats
  (`fd1/source/Fd1View.mc:35-43`, `fd1/source/Fd1SessionRecorder.mc:137-138`).
- Comments are sparse. They explain screen-size limits (`fd1/source/Fd1View.mc:107-109`). Some are in Russian
  (`fd1/source/Fd1MenuDelegate.mc:69`).

## 10. Risks and gaps

- No tests at all (section 7).
- Fixed in plan 1: the `min_hr` FIT field is now written with each new minimum. It was only ever 0.
- `mHRHistory` gets a new entry every second while recording and is never read
  (`fd1/source/Fd1SessionRecorder.mc:31`, `:123`), so it grows with session length.
- Fixed in plan 1: the clock ticked in `onUpdate`. It froze while a menu was open, which was confirmed in the
  simulator. It now ticks in the 1 s timer (`fd1/source/Fd1View.mc`).
- Missing null checks:
  - The result of `Activity.getActivityInfo()` is used without a check in `updatePressure` and `updateHeartrate`
    (`fd1/source/Fd1Util.mc:338`, `:379`).
  - The result of `HRH.next()` is used without a check (`fd1/source/Fd1Util.mc:384-385`).
  - The recorder does check `getActivityInfo()` (`fd1/source/Fd1SessionRecorder.mc:113`).
- Fixed in plan 1: `formatSecundes` now zero-pads (`1:03`).
- Fixed in plan 1: `finish()` now stops the 1 s refresh timer before it nulls the session.
- Hard-coded pixel offsets (`x+57`, `y-70`) serve three screen sizes (`fd1/source/Fd1View.mc:83-84`, `:130-131`).
- The accelerometer threshold is untuned. The code says "needs pool tuning" (`fd1/source/Fd1Util.mc:64`).
- Duplicated logic:
  - Five near-identical sub-menu delegate classes (`fd1/source/Fd1MenuDelegate.mc:59-133`).
  - Identical `onNextPage` and `onPreviousPage` (`fd1/source/Fd1Delegate.mc:40-48`).
  - The same tone plus 2 s vibration in two places (`fd1/source/Fd1Util.mc:231-237`, `:304-311`).
- Largest file: `fd1/source/Fd1Util.mc`, 391 lines. One class holds the state machine, the sensors, the
  notifications and the settings.
- Stale docs:
  - `CLAUDE.md` "Settings persistence" leaves out `autoStartPressure` and `poolLength` (`fd1/source/Fd1Util.mc:83-85`).
  - `CLAUDE.md` says the view drives "a 1-second Timer", but it starts two (`fd1/source/Fd1View.mc:38-42`).
  - `CLAUDE.md` does not mention the Pool Length or Adjust Distance menus.
  - `CLAUDE.md` says "no CLI build script", but the skill has CLI commands (`.claude/skills/feature-creator/SKILL.md:16-17`).
  - That skill names a file `Fd1State.mc`, which does not exist (`.claude/skills/feature-creator/SKILL.md:11`).
- Unused tracked files:
  - `diving-mask.png`, `diving-mask1.png` and `monkey.png` are not in `fd1/resources/drawables/drawables.xml`.
  - The `prompt` string is unused (`fd1/resources/strings/strings.xml:4`).
  - The `timeLabel` label is unused (`fd1/resources/layouts/layout.xml:2`).
  - `fd1/resources/drawables/.DS_Store` is tracked even though `.gitignore:2` ignores it.
- Two `launch.json` copies that differ: `.vscode/launch.json` and `fd1/.vscode/launch.json`.
- Secrets: none found in tracked files. The developer key is referenced by path only, and the file lives outside
  the repo (`.claude/skills/feature-creator/SKILL.md:13`).

## 11. Open questions

- Is `onLayout` called more than once, for example after a menu pops? Plan 1 guards the timer creation, so this
  no longer matters for the timers (`fd1/source/Fd1View.mc`).
- `ConfirmationDelegate.initialize()` at `fd1/source/Fd1Delegate.mc:53` is called inside a class with the same
  name as its parent. Does it resolve to `WatchUi.ConfirmationDelegate`?
- Which device is the main test target? The skill uses `instinct2s` (`.claude/skills/feature-creator/SKILL.md:15`).
- Is there an issue tracker for user reports? The moonlight triage adapters need one.
- Does `finish()` save an empty FIT activity when no dive was started (`fd1/source/Fd1SessionRecorder.mc:142-146`)?
