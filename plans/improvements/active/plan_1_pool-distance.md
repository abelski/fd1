---
kind: feature
status: draft
iteration: 0
max_iterations: 30
suggested_model: sonnet
suggested_effort: medium
confirmed_model: null
confirmed_effort: null
---

# Plan #1 — Pool lengths, distance and speed per dive

### Context
Idea: `plans/ideas/idea_1_pool-distance.md`

- Most of the feature was built before this plan existed. It sits uncommitted on branch `feat/1-pool-distance`.
  Items 1–9 below describe that existing code and are checked. Items 10–12 are open.
- Build evidence: `fd1/bin/fd1_instinct2s.prg` was built 13 s after the last source edit, and it contains the
  strings `dive_distance` and `poolLength`. So the current code compiled for instinct2s once. The `fenix6pro` and
  `instinct2x` builds predate the last edits.
- Toolchain gap (checked 2026-11-12):
  - No ConnectIQ SDK under `~/Library/Application Support/Garmin/ConnectIQ/Sdks/`.
  - No Garmin VS Code extension.
  - No Java on PATH. Homebrew `openjdk` is in `/opt/homebrew/opt/openjdk` but is keg-only.
  - So nothing can be built or tested until the user reinstalls the SDK. That needs their Garmin login.
- Existing patterns: sub-menu delegates take state in their constructor (`fd1/source/Fd1MenuDelegate.mc:59-133`).
  Settings setters call `saveSettings()` (`fd1/source/Fd1Util.mc:81-91`). Pressure and accelerometer share one
  timer (`fd1/source/Fd1View.mc:27-32`).
- Model: `sonnet`/`medium`. What remains is small and follows existing patterns. The accelerometer listener (item
  11) is new API use, but it is small.

### Goals
- The diver sets the pool length, and it persists.
- Lengths are counted per dive, automatically and by manual correction.
- Page 1 shows distance and speed.
- Each dive's FIT lap carries the distance and speed.

### Non-Goals
- Stroke or swim-style detection, yard pools, other pool lengths.
- Session totals of distance.
- Any change to the REST/DIVE timing, the wait modes or the auto-start logic.

### Decisions
- [user:high] Make idea and plan for the in-progress feature, on its own branch → done; this file.
- [user:high] Should a length correction made in REST update speed and the FIT lap? → yes (item 10).
- [user:high] Which device comes first? → Instinct (instinct2s, instinct2x). The user said "optimize for the
  Instincts for now". `fenix6pro` stays in `manifest.xml`, but it is not built or checked in this plan.
- [user:high] Should the accelerometer move to `registerSensorDataListener` at 25 Hz? → yes, "do everything" (item 11).
- [user:high] What step does the correction screen use? → 10 m (item 14).
- [stand-in:medium] The long row does not fit beside the subscreen. What goes? → the length count (item 15).
  Screenshots show `12L 300m* 1.2m/s` running under the circle on both Instincts.
- [user:high] How is the first length counted, so auto start does not lose it? → every dive starts on length 1
  (item 17).
- [user:high] What is the real diver pace? → 50 m in about 40–60 s, with a whole pool length (25–50 m) between the
  start and each turn. This sets the turn window to pool length × 2/3 s (item 18).
- [user:high] What does the pool menu offer for static holds? → an item labelled "STA" (pool length 0, no distance)
  (item 20).
- [user:high] Which pool lengths stay? → only 25 and 50 m; 33 m is dropped (item 21).
- [user:high] How is the distance corrected? → the diver surfaces, for example at 50 m after one turn in a 25 m
  pool after swimming 35 m, and presses −10 several times to keep 30 m. So the correction is a screen that
  stays open between presses (item 22).
- [user:high] Must settings survive a restart? → yes, all of them, in device storage (item 23).
- [user:high] Check every flow in the simulator, button presses included → done (items 24–27, Validation).
- [user:high] Fix the four issues that predate plan 1 and were found in the simulator → items 28–30.
- [user:high] What is a turn? → not only a push-off from the wall, but the direction of motion flipping to
  roughly the opposite. Count it from the compass, in DYN and in DNF, with the push-off spike as a fallback, and
  log raw data to FIT to tune it in the pool (items 31–32).
- [user:high] Install the new version on my watch → done (item 33). The watch turned out to be an Instinct 2
  Solar (`instinct2`), which was not in the manifest.
- [user:high] Correction of the flow, in the user's words:
  - The diver sets things up, dives and swims, and feels a light vibration at each turn.
  - After surfacing, the distance screen with the estimated distance opens by itself, to confirm or fix.
  - Then the diver rests and dives again.
  - Laps carry the distance like they carry heart rate and time; speed is the average while moving.
  - In STA there is no distance screen and no speed.
  - The bottom row should be centred, and the UP screen should look better.
  → items 34–38.

### Requirements
- Pool Length menu: 25 m, 50 m and STA (stored as 0). Default 25. Persisted under the `poolLength` key.
- Adjust Distance opens a correction screen: UP +10 m, DOWN −10 m, any number of presses; GPS or BACK returns to
  the main screen.
- All settings (start mode, wait mode, notification option, pool length) persist in device storage.
- Distance = lengths × pool length + the manual correction (±10 m steps, total never below 0). Speed = distance ÷
  dive hold time, and 0 when the hold time is 0.
- Page 1 row: `<distance>m[*] <speed>m/s`, with `--m/s` when speed is 0. `300m* 1.2m/s` must fit beside the
  subscreen on instinct2s and instinct2x.
- FIT lap fields: `dive_distance` (id 1, FLOAT, m) and `dive_speed` (id 2, FLOAT, m/s). They are set before the
  next lap boundary.

#### Standing constraints
From `CLAUDE.md`:
- "`static var` on View/Delegate classes is used as a workaround for passing state … this is intentional."
- "The `formatSecundes` function (note the typo — keep it consistent)."
- Builds and tests: "Run App", "Run Tests" and "Monkey C: Build" in VS Code. The CLI equivalents are in
  `.claude/skills/feature-creator/SKILL.md:16-17`.

## Implementation

- [x] 1. `fd1/resources/menus/pool_length_menu.xml`, `fd1/resources/menus/adjust_lengths_menu.xml`,
  `fd1/resources/menus/main_menu.xml`, `fd1/resources/strings/strings.xml` — add the Pool Length and Adjust Lengths
  menus and their strings.
- [x] 2. `fd1/source/Fd1MenuDelegate.mc` — add `PoolLengthMenuDelegate` and `AdjustLengthsMenuDelegate`, wired
  from `onMenuItem`.
- [x] 3. `fd1/source/Fd1Util.mc` — add `poolLength` with `setPoolLength`, and save and load it in Storage.
- [x] 4. `fd1/source/Fd1Util.mc` — add the per-dive counters (`currentLengths`, `currentDistance`, `currentSpeed`,
  `manualOverrideActive`), plus `adjustLengths` (clamped at 0), `setLengths` and `recomputeDistance`.
- [x] 5. `fd1/source/Fd1Util.mc` — `updateAccel`: magnitude ≥ 1800 milli-g counts +1, with a 1-tick refractory
  period. `changeMode` turns sensor events on for DIVE and off for REST.
- [x] 6. `fd1/source/Fd1Util.mc` — `changeMode` at DIVE→REST computes speed and calls `session.updateDiveMetrics`.
- [x] 7. `fd1/source/Fd1SessionRecorder.mc` — add the `dive_distance` and `dive_speed` lap fields and
  `updateDiveMetrics`.
- [x] 8. `fd1/source/Fd1View.mc` — add the page 1 metrics row. `pressureCallback` also calls `updateAccel`.
- [x] 9. `fd1/source/Fd1Util.mc` — add `formatDistance` and `formatSpeed`.
- [x] 10. `fd1/source/Fd1Util.mc` — a correction made in REST updates speed and the FIT lap:
  - `changeMode` stores the dive's hold time in `lastDiveTime` before the rest countdown overwrites `holdTime`.
  - `finalizeDiveMetrics(session)` computes speed and calls `updateDiveMetrics`.
  - `adjustLengths` and `setLengths` call `applyLengthCorrection()`. In REST after at least one dive, that calls
    `finalizeDiveMetrics`.
  - This is in time, because the lap is cut at the next `addLap()` (`fd1/source/Fd1SessionRecorder.mc:95-96`).
  - `specs/fd1.md` has the new scenario "Correcting lengths after surfacing".
  - Not compiled yet (no SDK).
- [x] 11. `fd1/source/Fd1Util.mc`, `fd1/source/Fd1View.mc` — the accelerometer moves to a 25 Hz listener. This
  replaces the 1 Hz `updateAccel` poll from items 5 and 8.
  - `startAccel()` registers `Sensor.registerSensorDataListener` (`:accelerometer`, 25 Hz, `:period => 1`) on
    DIVE. `stopAccel()` unregisters it on REST. Both are guarded with `has`.
  - `onSensorData` passes the arrays to `onAccelSamples`, which counts at most one length per batch. The check
    compares squared magnitude against the squared threshold, so there is no sqrt.
  - Removed: `updateAccel`, `onAccelSensorNoop`, the `enableSensorEvents` calls, `import Toybox.Math`, and the
    `updateAccel` call in `pressureCallback`.
  - Added 3 tests.
  - Not compiled yet.
- [x] 12. `fd1/source/test_Fd1Util.mc` — 8 `(:test)` unit tests with a `StubSession`:
  - `adjustLengths(-1)` at 0 stays at 0.
  - Distance for a 33 m pool.
  - Distance and speed at dive end, and speed 0 for a hold time of 0.
  - A REST correction updates the lap and the speed.
  - A correction before the first dive does not touch FIT.
  - `formatDistance` and `formatSpeed`.
  - `setPoolLength` round-trips through `loadSettings`.
  - Written but not run yet (no SDK).

- [x] 13. `fd1/source/Fd1View.mc` — on instinct2x the third info row pushed the top row (`cycles/total time`) into
  the screen's cut top-left corner, and its first digit was clipped.
  - Square screens now indent that row by half a margin.
  - A circle-chord indent was tried first. It pushed the row into the heart-rate circle, so it was dropped.
  - Checked by eye in the simulator: `tmp/crop_2x_indent.png` (2X) and `tmp/crop_2s.png` (2S, unchanged).
- [x] 14. Correction in 10 m steps. This replaces the ±1 length correction from items 1, 2, 4 and 10.
  - The Adjust Lengths menu becomes Adjust Distance: `adjust_distance_menu.xml`, strings `+10m`, `-10m` and
    `Reset to 0`, and `AdjustDistanceMenuDelegate`.
  - `Fd1Util.mc`: `adjustDistance(deltaMeters)` adds to `distanceOffset`, clamped so the total is never below 0.
    `resetDistance()` replaces `setLengths(0)`. `recomputeDistance` adds the offset, and auto turns still add
    lengths after a correction. The offset is cleared when a dive starts.
- [x] 15. `fd1/source/Fd1View.mc` — the page 1 row drops the length count. On instinct2x it starts at half a margin,
  so the column follows the round edge.
  - Checked with seeded worst-case values (15 cycles, 59:59, 300 m*, 1.2 m/s). The seed was removed afterwards.
  - Screenshots: `tmp/crop_instinct2s_long_values_v3.png` and `tmp/crop_instinct2x_long_values_v3.png`.
- [x] 16. `fd1/source/test_Fd1Util.mc` — now 16 tests. 5 of them simulate whole dives with `Sim.dive`: a 25 Hz signal
  with a dolphin-kick wobble from 0.5 g to 1.5 g, and 2.5 g push-off spikes.
  - 50 m in a 25 m pool over 45 s.
  - 99 m in a 33 m pool, with one turn split across two batches.
  - Kicking only, which counts nothing.
  - Surfacing at 40 m, then a `-10m` fix.
  - A second dive that starts clean.
- [x] 17. `fd1/source/Fd1Util.mc` `changeMode` — a dive starts with `currentLengths = 1`, so distance starts at one
  pool length.
  - Auto start enters DIVE about 3 s after submerging (`PRESSURE_CONFIRM_TICKS`), so it never saw the push-off.
  - Side effect: a static hold, with no swimming, also records one pool length (see Open questions in the idea).
- [x] 18. `fd1/source/Fd1Util.mc` — `minLengthTicks()` = `poolLength * 2 / 3` (25 m: 16 s, 33 m: 22 s, 50 m: 33 s)
  replaces the 1 s refractory. It applies after the dive start and after each counted turn.
  - With only 1 s, a turn's touch and push-off spikes (1–3 s apart) would very likely count twice.
- [x] 19. `fd1/source/test_Fd1Util.mc` — 18 tests. The simulated dives use the real pace:
  - 50 m in 50 s, with the turn's touch and push-off 2 s apart.
  - 99 m in 100 s in a 33 m pool.
  - A mid-length spike in a 50 m pool, which is ignored.
  - A push-off 5 s after Select.
- [x] 20. STA: `pool_length_sta` ("STA") in `pool_length_menu.xml` and strings; `setPoolLength` maps it to 0. A dive with
  pool 0 skips `startAccel()`. Page 1 shows `STA`. The test `testSimulatedStaHoldRecordsNoDistance` covers it.
- [x] 21. 33 m removed from the menu, the strings and `setPoolLength`. The 99 m / 33 m simulation became 150 m in
  a 50 m pool.
- [x] 22. `fd1/source/Fd1AdjustDistanceView.mc` (new) — `AdjustDistanceView` and `AdjustDistanceDelegate`.
  - UP calls `adjustDistance(10)` and DOWN calls `adjustDistance(-10)`; the screen redraws and stays open.
  - GPS pops the view, and BACK pops it by default.
  - `Fd1MenuDelegate` opens it with `switchToView`. With `pushView`, the main menu stayed underneath (seen in the
    simulator).
  - Removed: the three-item `adjust_distance_menu.xml`, its strings, `AdjustDistanceMenuDelegate` and
    `resetDistance()`.
  - The test `testSimulatedTurnedThenSurfacedAt35mSaves30` is the user's example.
- [x] 23. Settings persistence: already saved by `saveSettings()`. The new test `testAllSettingsPersist` sets all
  four, reloads and restores the defaults. `testMenuSymbolsReachTheSetters` proves that `item.toString()` gives
  the resource id on the device.
- [x] 24. `fd1/source/Fd1View.mc` — the dive and rest clock ticks in the 1 s `timerCallback`, not in `onUpdate`.
  - The simulator showed the clock frozen while a menu was open: 6 s counted over about 12 s.
  - The timers are created once (guard in `onLayout`).
  - This bug predates plan 1.
- [x] 25. `Fd1Util.formatSecundes` pads the seconds: `1:03`, not `1:3`, which reads as 1:30. This bug predates
  plan 1, although CLAUDE.md already described the format as M:SS.
- [x] 26. `fd1/source/Fd1Delegate.mc` — "Save & exit" → Confirm now calls `System.exit()`.
  - Popping the main view from `onResponse` crashed the simulator (SIGSEGV) before `onStop`. The FIT was left
    unclosed, with data size 0.
  - The committed HEAD build crashes the same way, so the bug predates plan 1.
  - `Fd1SessionRecorder.finish()` also stops its 1 s timer before nulling the session.
- [x] 27. `changeMode` writes the new dive's starting distance and speed 0 to the FIT fields. An exit mid-dive
  saved the previous dive's distance into the new lap. The test is `testNewDiveLapDoesNotKeepLastDiveDistance`.
- [x] 28. `Fd1View.drawPage2Values` — on square screens (instinct2x), page 2 rows start at `y - 26`, below the
  subscreen. `Start:manual` was clipped to `Start:manu`; instinct2s is unchanged.
  - The pressure row was checked with a seeded 101.3 / 101.3 on both Instincts. `P:101.3 Base:101.3` fits, so
    the pressure row needed no change.
- [x] 29. `strings.xml` — "Notification Options" becomes "Notifications". It now fits when focused. The row
  above the focused one is always partly under the subscreen; that is how the system menu draws on the
  Instinct.
- [x] 30. `Fd1SessionRecorder.refreshActivityStats` — the `min_hr` session field is set on each new minimum. It
  was always 0.
  - Checked with Simulation → Activity Data → ▶ (simulated HR): the FIT session has `min_hr=151`.
  - Without simulated data, the simulator gives no `currentHeartRate` (FIT records show HR 255), so `min_hr`
    stays unset there.
- [x] 31. `Fd1Util` — turns from the compass.
  - Each 1 s batch carries `Activity.Info.currentHeading`.
  - The last 8 headings are averaged as unit vectors (`_hx`/`_hy` ring buffers). 8 s rather than the 3 s first
    proposed, because in DNF the watch points back at the hips on every stroke and a cycle must average out.
  - The length's heading is the first clear mean (vector length ≥ 0.3) after the 2/3-length window. A turn is a
    clear mean more than 120° away from it.
  - The push-off spike counts only when no heading came in during the dive.
  - All three values are guesses, to be tuned from the pool log.
  - Tests: soft DYN turns with no spike (3/3), kicks ignored, DNF with the watch at the hips 2 s of every 6 s (3/3).
- [x] 32. `Fd1SessionRecorder` — FIT record fields `heading` (deg, 65535 = none) and `accel_peak` (mg), written
  every second in a dive through `logSample`.
  - Checked in the simulator with Activity Data: 13 records for a 12 s dive, heading 354–46°, accel_peak 999,
    and `min_hr=130`.
- [x] 33. `fd1/manifest.xml` — `instinct2` added (the owner's watch: Instinct 2 Solar, part number 006-B3888-00).
  - Its screen and keys are identical to instinct2x, so all 2X layout work applies.
  - A release build `fd1/bin/release/fd1_instinct2.prg` passes 25/25 tests and the simulator smoke run.
  - It was copied over `GARMIN/APPS/fd1.prg` on the watch (USB drive), checked with `cmp`, and the watch was
    ejected. The old file is backed up in `tmp/watch_backup/fd1_watch_2026-03-05.prg`.
- [x] 34. Distance confirmation after every dive (not STA).
  - `changeMode` sets `distanceToConfirm` at DIVE→REST when pool > 0 and clears it at dive start.
  - `showDistanceConfirmIfDue` runs from `Fd1Delegate.onSelect` and from `Fd1View.timerCallback`, for a dive
    ended by auto start. It pushes `AdjustDistanceView`: "OK" in the circle next to GPS; GPS or BACK confirms.
  - The "Adjust Distance" menu item, its string and its menu handler are removed.
  - Tests: `testDiveEndAsksToConfirmDistance`, and the STA test checks that no screen is asked for.
  - Simulator: the screen opens by itself after a dive on instinct2 and on 2S, and not after an STA dive.
- [x] 35. A light vibration (40 %, 300 ms) on every counted turn (`onAccelSamples`). It runs in the compass tests;
  how it feels is to be checked in the pool.
- [x] 36. Page 1: the clock icon and the timer are centred together, using the measured text width.
- [x] 37. Page 2 redesigned:
  - "Settings" with a line under it, and the pool length in the white subscreen circle.
  - Rows Start / Wait / Notify, with the value right-aligned ("Manual", "x2", "CO2", "Off").
  - "<now> / <baseline> kPa" at the bottom.
  - Checked on instinct2 and 2S.
- [x] 38. FIT: `dive_distance` and `dive_speed` lap fields get `:nativeNum` 9 (lap total_distance) and 13 (lap
  avg_speed).
  - Checked in the simulator FIT: `field_description` has native_mesg_num 19 and native_field_num 9 and 13.
  - Not checked: whether Garmin Connect then shows them in its lap table. That needs a real upload.

## Validation

- [x] Build each target with no errors: `monkeyc -f fd1/monkey.jungle -y ~/Documents/src/developer_key -o fd1/bin/fd1_<device>.prg -d <device>`
  for `instinct2s` and `instinct2x`. `fenix6pro` is deferred (see Decisions).
  - 2026-11-12, SDK 9.3.0: instinct2s and instinct2x → BUILD SUCCESSFUL, with no new warnings.
- [x] Unit and simulation tests pass (2026-11-12, after items 14–38: 26 of 26 on instinct2, instinct2s and instinct2x):
  `monkeyc … -d instinct2s -t -o fd1/bin/fd1_test.prg`, then `monkeydo fd1/bin/fd1_test.prg instinct2s -t` with the
  simulator running.
- [x] Layout with worst-case values fits on both Instincts (item 15 screenshots).
- [x] Smoke by buttons in the simulator, on instinct2s and instinct2x (2026-11-12). The buttons were clicked with
  `tmp/simctl` and every screen was checked with screenshots (`tmp/sheet_*.png`).
  - Pages 1 and 2.
  - Every menu.
  - Manual dive start and end.
  - The correction screen, in DIVE and in REST.
  - The clock running under menus: 32 s real equals 32 s counted.
  - STA.
  - Every setting, before and after an app restart.
  - "Save & exit": Cancel and Confirm.
- [x] Edge cases, covered by tests:
  - `-10m` at 0 stays at 0.
  - Ending a dive right away gives speed 0, shown as `--m/s`.
  - The pool length survives a reload of the settings.
- [x] FIT, read with `tmp/fitdump.py`:
  - A dive of 45 m corrected to 25 m in REST saved `dive_distance=25.0` and `dive_speed=0.581` (25/43).
  - The session has `sub_sport=62`.
  - Exiting through Confirm saves a closed file.
  - An exit mid-dive saves that dive's own start values.
  - `min_hr=151` with simulated HR (item 30).
- [ ] Pool, done by the user on a real watch, in DYN and in DNF: 4 turns count 4 lengths.
  - Send the FIT file. Its `heading` and `accel_peak` records show what to tune: `HEADING_WINDOW`,
    `HEADING_CONFIDENCE`, `HEADING_TURN_COS`, and `ACCEL_TURN_THRESHOLD_MILLIG` for watches without compass data.

## Definition of Done

```bash
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"   # Homebrew openjdk is keg-only
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.3.0-2026-10-20-95888f262"
for d in instinct2s instinct2x; do "$SDK/bin/monkeyc" -f fd1/monkey.jungle -y ~/Documents/src/developer_key -o "fd1/bin/fd1_$d.prg" -d "$d" || exit 1; done
"$SDK/bin/monkeyc" -f fd1/monkey.jungle -y ~/Documents/src/developer_key -o fd1/bin/fd1_test.prg -d instinct2s -t
"$SDK/bin/monkeydo" fd1/bin/fd1_test.prg instinct2s -t
```
