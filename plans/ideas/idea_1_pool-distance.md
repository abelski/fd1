---
number: 1
slug: pool-distance
status: draft
---

# Idea #1 — Pool lengths, distance and speed per dive

This idea was reconstructed from the code. The work was built before the moonlight setup, and no record of the
original discussion survives. The code is uncommitted on `feat/1-pool-distance`. Everything below comes from that
code, so the Decisions are what the code does, not answers from grilling.

## Problem
A freediver doing dynamic apnea (a horizontal swim in a pool) cares about distance and pace, not only hold time.
Before this change the app tracked only hold time and rest. The diver had to count lengths in their head, and the
FIT file had no distance for each dive.

## Desired outcome
- Page 1 shows the distance and speed of the current or most recent dive, for example `100m* 1.1m/s`. There is no
  length count, because `4L 100m* 1.1m/s` does not fit beside the Instinct subscreen.
- The app counts lengths from wall-turn spikes on the accelerometer.
- The diver can fix the distance on a correction screen (Menu → Adjust Distance): UP +10 m, DOWN −10 m, pressed as
  often as needed. For example, one turn in a 25 m pool shows 50 m; the diver swam 35 m and presses DOWN twice to
  keep 30 m. A `*` marks a distance that was corrected by hand.
- The diver sets the pool length (25 m, 50 m, or STA for static holds without distance). Like every setting, it
  persists in device storage.
- Each dive's FIT lap carries `dive_distance` (m) and `dive_speed` (m/s), so Garmin Connect has the data after the
  session.

## Proposed spec
In the form of `specs/fd1.md`.

```gherkin
# New
Scenario: Choosing pool length
  Given the user opens Menu, then Pool Length (25m, 33m, 50m)
  When the user selects an item
  Then the pool length is stored, saved to storage and the menu closes
```

```gherkin
# New
Scenario: Wall touch counted by accelerometer
  Given the app is in DIVE mode, with accelerometer samples arriving in one-second batches at 25 Hz
  When any sample in a batch has a magnitude of at least 1800 milli-g
  And at least pool length x 2/3 seconds have passed since the dive start or the last counted turn
  Then the length count increases by one and distance is recomputed
  And spikes in the next pool length x 2/3 seconds are ignored (touch, tumble, push-off of one turn)
```

```gherkin
# New
Scenario: Manually adjusting the distance
  Given the user opens Menu, then Adjust Distance
  When the user picks "+10m" or "-10m"
  Then the distance changes by 10 m (never below 0) and the menu closes
  And on page 1 an asterisk follows the distance until the next dive starts
```

```gherkin
# Changed
Scenario: Ending a dive
  Given the app is in DIVE mode with a hold time of 45 seconds and 2 lengths counted on a 25 m pool
  When the dive ends
  Then distance is 50 m and speed is distance divided by hold time
  And distance and speed are written to the lap fields of the FIT session
```

```gherkin
# New (proposed, not built yet; see Open questions)
Scenario: Correcting lengths after surfacing
  Given a dive has ended and the app is in REST mode
  When the user adjusts the distance
  Then speed is recomputed from the last dive's hold time
  And the corrected distance and speed are written to that dive's FIT lap
```

## Scope
- In: the pool length setting, automatic length counting, manual distance correction in 10 m steps, distance and speed on page 1, and FIT lap
  fields.
- Out (non-goals):
  - Stroke counting and turn detection by swim style.
  - Yard pools.
  - Pool lengths other than 25 and 50 m.
  - Showing distance and speed on page 2.
  - Session totals of distance.

## Decisions
Reconstructed from the code:
- **Q** Which pool lengths? — 25 and 50 m, plus STA, all chosen by the user. 33 m was dropped.
- **Q** How do static holds avoid recording distance? — the pool item "STA" (stored as 0): no accelerometer
  listener, distance 0, and page 1 shows `STA`.
- **Q** What does the correction look like? — a screen that stays open between presses, not a menu that closes
  after each pick.
- **Q** How is a length detected? — any sample of at least 1800 milli-g in a 1 s batch of 25 Hz accelerometer
  samples. At first this was polled at 1 Hz on the pressure timer; the user changed it in plan item 11.
- **Q** How is double counting avoided? — after the dive start or a counted turn, spikes are ignored for pool length × 2/3 s
  (25 m: 16 s, 50 m: 33 s). Source: the user said a diver swims 50 m in about 40–60 s, with a whole pool length
  (25–50 m) between the start and each turn. 2/3 s per metre is 1.5 m/s, a margin above the fastest pace.
- **Q** What is a turn? — the direction of motion flipping to roughly the opposite, not only a push-off (the user).
  It is counted from the compass, the mean heading of the last 8 s turning more than 120°. This works in DYN and in
  DNF. The push-off spike is only a fallback when there is no compass data. Raw heading and peak acceleration go to
  FIT every second for tuning in the pool.
- **Q** How is the first length counted? — every dive, manual or auto, starts on length 1. Chosen by the user: auto
  start fires about 3 s after submerging and would always miss the push-off spike.
- **Q** When is speed computed? — once, when the dive ends: distance divided by hold time (`fd1/source/Fd1Util.mc:264-269`).
- **Q** What step does the manual fix use? — 10 m, set by the user on 2026-11-12. Before that it was ±1 length.
- **Q** How is a manual fix shown? — a `*` after the distance until the next dive (`fd1/source/Fd1View.mc:124`).
- **Q** Where does the data go? — FIT lap fields `dive_distance` and `dive_speed`, as FLOAT
  (`fd1/source/Fd1SessionRecorder.mc:77-93`).

## Precedents
- None. This is the first moonlight plan in this repo.

## Success check
- In the simulator, a dive with one counted length and a `+10m` press on a 25 m pool shows `35m*` and a speed.
- The saved FIT file has `dive_distance` = 50 on that lap.
- In a real pool, 4 wall turns are counted as 4 lengths (±0) on the main target watch.

## Open questions
- Settled by the user: a correction made in REST now updates speed and the FIT lap. Before, speed was set only at
  dive end and the correction never reached FIT. This is plan item 10.
- Settled by the user: the accelerometer now uses `registerSensorDataListener` at 25 Hz with 1 s batches. Garmin
  docs say `Sensor.Info.accel` can stay null on some devices without that listener. Also, a 1 Hz poll can miss a
  short push-off spike (inferred). This is plan item 11.
- The 1800 milli-g threshold is untuned. The code says "needs pool tuning" (`fd1/source/Fd1Util.mc:64`).
- Settled by the user: static holds use the pool item "STA", which records no distance (plan item 20).
