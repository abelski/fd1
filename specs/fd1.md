# fd1 — current behavior

## Purpose
fd1 is a Garmin ConnectIQ watch app (Monkey C, targets instinct2, instinct2s, instinct2x, fenix6pro) for freediving pool training. The diver alternates DIVE and REST intervals; the app shows a hold/rest timer, heart rate, session totals and per-dive length/distance/speed, gives vibration/tone notifications, and records the whole session as a FIT activity (generic sport, breathwork sub-sport) with one lap per dive. It is driven entirely by watch buttons (Select, Menu, Back, Up/Down) and by the pressure sensor and accelerometer polled once per second; there is no network or phone interface. User settings persist in on-device key-value storage.

## Scenarios

```gherkin
Scenario: App starts with no saved settings
  Given the app has never stored any settings
  When the app launches
  Then start mode is "manual", wait mode is "x2", notifications are "off", pool length is 25 m, and the surface pressure is 0 until the first reading
  And the app begins in REST mode with the timer showing "0:00" on page 1 (times are M:SS)
  And a FIT activity session named "Freediving" is created but not yet started
```

```gherkin
Scenario: App starts with saved settings
  Given start mode, wait mode, pool length and notification flags were saved earlier
  When the app launches
  Then those stored values are restored and shown on page 2
```

```gherkin
Scenario: Starting a dive manually
  Given the app is in REST mode
  When the user presses Select
  Then the FIT session starts (or resumes, with a new lap added for every dive after the first)
  And the hold time, distance correction, speed and manual-override flag are reset
  And the length count starts at 1, the length the diver pushes off on, so distance starts at one pool length
  And unless the pool length is STA the 25 Hz accelerometer listener is registered, and the mode becomes DIVE
  And the new FIT lap gets this dive's starting distance and speed 0, so leaving mid-dive never saves the previous dive's values
  And a start tone plus a 2-second full-strength vibration is played
```

```gherkin
Scenario: Hold time counts up during a dive
  Given the app is in DIVE mode
  When the one-second UI refresh runs
  Then the hold time increases by one second
```

```gherkin
Scenario: Ending a dive with the "x2" wait mode
  Given the app is in DIVE mode with a hold time of 45 seconds and 2 lengths counted on a 25 m pool
  And the wait mode is "x2"
  When the user presses Select
  Then distance is 50 m and speed is distance divided by hold time
  And distance and speed are written to the lap fields of the FIT session
  And the session is paused, the cycle count increases by one and total session time increases by 45 seconds
  And the mode becomes REST with the countdown set to 90 seconds
```

```gherkin
Scenario: Rest durations for other wait modes
  Given a dive has just ended
  When the wait mode is "30sec" then the rest countdown is 30 seconds
  Or the wait mode is "1min" then the rest countdown is 60 seconds
  Or the wait mode is "co2" then the rest countdown is 120 seconds minus 15 seconds per completed cycle, never below 30 seconds
```

```gherkin
Scenario: Dive of zero length
  Given the app is in DIVE mode with a hold time of 0
  When the user presses Select
  Then speed is recorded as 0 (no division by zero)
```

```gherkin
Scenario: Rest countdown with start notifications enabled
  Given the app is in REST mode with the notification option "1min" or "30sec"
  When the countdown is 10 seconds or less and still running
  Then each second a short, 500 ms, low-intensity vibration is played
```

```gherkin
Scenario: Rest countdown with notifications off
  Given the app is in REST mode with the notification option "off"
  When the countdown runs down
  Then there is no per-second vibration
```

```gherkin
Scenario: Rest finished, ready to dive again
  Given the app is in REST mode, a dive has occurred since the last beep, and the countdown has reached 0
  When the next refresh runs
  Then a loud beep and a 2-second vibration are played once
  And the timer stays at 0 and no further beeps occur until another dive has been entered
```

```gherkin
Scenario: Periodic vibration during a dive
  Given the app is in DIVE mode and notification option "1min"
  When the hold time is a multiple of 60 seconds (including 0)
  Then a 100 ms vibration is played
  And with option "30sec" the same happens at every multiple of 30 seconds
  And with option "off" no vibration is played
```

```gherkin
Scenario: Choosing a notification option
  Given the user opens Menu, then Notification Options
  When the user picks "Off"
  Then the start, 1-minute and 30-second notification flags are all cleared
  When the user picks "1min"
  Then the start and 1-minute flags are set and the 30-second flag is cleared
  When the user picks "30sec"
  Then all three flags are set
  And the choice is saved to storage and the menu closes
```

```gherkin
Scenario: Choosing wait mode or pool length
  Given the user opens Menu, then Wait Mode (x2, 1min, 30sec, CO2) or Pool Length (25m, 50m, STA)
  When the user selects an item
  Then the corresponding setting is stored, saved to storage and the menu closes
```

```gherkin
Scenario: STA (static apnea) pool setting
  Given the pool length is STA
  Then page 1 shows "STA" instead of distance and speed
  When a dive starts
  Then no accelerometer listener is registered and the distance stays 0
  And each dive's FIT lap records 0 m and 0 m/s
  And no distance screen opens after a dive
```

```gherkin
Scenario: Dive and rest clock under menus
  Given a dive or a rest countdown is running
  When a menu or the correction screen covers the main screen
  Then the clock keeps ticking once per second, so dive time, speed and rest length stay true
```

```gherkin
Scenario: Switching start mode
  Given the user opens Menu, then Start Mode
  When the user picks "Auto Start" or "Manual Start"
  Then start mode becomes "auto" or "manual" and is saved
```

```gherkin
Scenario: Surface pressure
  Given the app is running, in either start mode
  When an ambient pressure reading (kPa, polled once a second) comes in outside a dive
  Then the lowest such reading since the app started is the surface pressure
  And it is never stored, so each session starts from its own surface (the weather moves it by kPa between days)
```

```gherkin
Scenario: Auto start when going under
  Given start mode is "auto", the app is in REST mode and the rest countdown has reached 0:00
  When the pressure is 2 kPa (about 0.2 m) or more over the surface for 2 consecutive polls
  Then the mode changes to DIVE as if Select had been pressed (without the button's tone and vibration)
  And a pause at the wall before swimming is part of the dive, and the dive starts on length 1
```

```gherkin
Scenario: No auto start while the rest countdown runs
  Given start mode is "auto", the app is in REST mode and the rest countdown is above 0:00
  When the hand is under water, for example hanging at the wall
  Then no dive starts; Select still starts one
```

```gherkin
Scenario: Auto stop after the swim
  Given start mode is "auto", the app is in DIVE mode, and the pressure has been 6 kPa (about 0.6 m) or more over the surface for 2 consecutive polls in this dive
  When the pressure is 3.5 kPa (about 0.35 m) or less over the surface for 2 consecutive polls
  Then the mode changes to REST as if Select had been pressed
```

```gherkin
Scenario: Auto stop without a swim
  Given start mode is "auto", the app is in DIVE mode, and this dive has been 2 kPa or more under for 2 polls but never 6 kPa (STA, a shallow pool, or a pause before the swim)
  When the pressure is 1 kPa or less over the surface for 5 consecutive polls (the hand out of the water)
  Then the mode changes to REST
  And a wrist that comes back up to 0.2 m during a pause, or stays in the water after an STA, does not stop the dive
```

```gherkin
Scenario: Select starts a dive in auto mode
  Given start mode is "auto" and Select started the dive with the hand out of the water
  When the hand stays out of the water
  Then the dive does not stop by itself until it has been 2 kPa under for 2 polls
```

```gherkin
Scenario: The swim restarts the turn window
  Given a dive in either start mode was under water before swimming, for example a pause facing the wall
  When the pressure first reaches 6 kPa over the surface for 2 consecutive polls in this dive
  Then the turn window (pool length x 2/5 s) and the length's heading start again from that poll
```

```gherkin
Scenario: No pressure reading available or manual mode
  Given the ambient pressure is unavailable, or start mode is "manual"
  When the pressure poll runs
  Then no automatic mode change happens
  And if the pressure is unavailable the displayed pressure is 0 and the counters keep their values
```

```gherkin
Scenario: Turn counted by the compass
  Given the app is in DIVE mode and the watch gives a compass heading with each one-second accelerometer batch
  And at least pool length x 2/5 seconds have passed since the dive started or since the last counted turn (25 m: 10 s, 50 m: 20 s), so a fast 25 m of 15 s still counts
  When the mean of the last 8 headings (as unit vectors, mean length at least 0.3) points more than 120 degrees away from the current length's heading
  Then the length count increases by one and distance is recomputed as lengths times pool length plus the correction
  And the next length's heading is the first clear 8-second mean after the next pool length x 2/5 seconds
  And push-off spikes are ignored while compass data is coming in, and a DNF stroke cycle (watch pointing back at the hips) averages out
  And the watch gives a light vibration (40 %, 300 ms) and a loud beep so the diver knows the turn was counted, a few seconds after the turn
```

```gherkin
Scenario: Turn counted by push-off spike without compass data
  Given the app is in DIVE mode and no compass heading has come in during this dive
  And at least pool length x 2/5 seconds have passed since the dive started or since the last counted turn
  When any sample in a one-second batch has an acceleration magnitude of at least 1800 milli-g
  Then the length count increases by one and distance is recomputed
  And spikes in the next pool length x 2/5 seconds are ignored: the touch, tumble and push-off of one turn, or a hard kick or stroke
  And the watch gives the same vibration and beep
```

```gherkin
Scenario: Per-second log for tuning turn detection and auto start
  Given the app is in DIVE mode
  When a one-second accelerometer batch arrives
  Then the compass heading in degrees (65535 when none), the batch's peak acceleration in milli-g and the pressure over the surface in Pa (0 to 65534) are written to the FIT record fields "heading", "accel_peak" and "depth_pa"
```

```gherkin
Scenario: Accelerometer ignored outside a dive
  Given the app is in REST mode
  Then no accelerometer listener is registered (it is registered when a dive starts and removed when it ends)
  And a batch that still arrives does not change the length count
  When the device has no sensor data listener API or a batch has no accelerometer data
  Then the length count is unchanged
```

```gherkin
Scenario: Confirming the distance after a dive
  Given the pool length is 25 m or 50 m
  When a dive ends, by Select or by auto start detecting the surface
  Then the distance screen opens by itself, showing "Distance", the counted distance, "UP +10  DOWN -10" and "OK" in the white circle next to the GPS button
  When the user presses Up or Down, any number of times
  Then each press adds or removes 10 m (never below 0), sets the manual-override flag and redraws the screen, which stays open
  When the user presses Select (GPS) or Back
  Then the distance is confirmed and the main screen shows the rest countdown, which kept running meanwhile
  And on page 1 an asterisk follows a changed distance until the next dive starts
  When the next dive starts before the screen was shown
  Then the screen is not shown any more
```

```gherkin
Scenario: The confirmed distance goes into the dive's lap
  Given a dive has ended and its distance screen is open
  When the user changes the distance, for example from 50 m (one turn in a 25 m pool) down twice to 30 m
  Then speed is recomputed from that dive's hold time (0 when the hold time was 0)
  And the corrected distance and speed are written to the FIT lap fields, before the next dive closes the lap
```

```gherkin
Scenario: Heart rate display
  Given the activity info reports a current heart rate
  When the view refreshes
  Then that value is shown in the heart area
  When the current heart rate is unavailable
  Then the most recent valid sample from the heart-rate history is used, and the previous value is kept if that sample is invalid
```

```gherkin
Scenario: Page 1 layout
  Given page 1 is showing
  When the view refreshes each second
  Then it shows heart rate, the mode text (REST or DIVE), the timer as M:SS, clock time HH:MM, "cycles/total dive time", and "<distance>m[*] <speed>m/s" (speed shows "--m/s" when zero; no length count, so "300m* 1.2m/s" fits beside the subscreen; "STA" instead in STA)
  And the clock icon and the timer are centred together as one group on the bottom row
```

```gherkin
Scenario: Switching pages
  Given the user is on page 1 or page 2
  When the user presses Up or Down
  Then the other page is shown
  And page 2 shows "Settings" with a line under it, the pool length ("25m", "50m" or "STA") in the white subscreen circle,
      rows Start / Wait / Notify with the value right-aligned ("Manual", "x2", "CO2", "Off"), and "<now> / <surface> kPa" for auto start
```

```gherkin
Scenario: Opening the settings menu
  Given the main screen is showing
  When the user presses Menu
  Then a menu is shown with Wait Mode, Start Mode, Notifications and Pool Length
```

```gherkin
Scenario: Back button asks for confirmation
  Given the main screen is showing
  When the user presses Back
  Then a "Save & exit?" confirmation is shown
  When the user answers Yes
  Then the app exits through System.exit, and on stop the recorder's timer is stopped and the FIT session is stopped and saved
  When the user answers No
  Then nothing changes and the app keeps running
```

```gherkin
Scenario: Heart-rate tracking in the recorded session
  Given the FIT session is recording
  When the one-second recorder refresh runs
  Then the lowest observed heart rate is tracked and written to the session's "min_hr" FIT field, and each current heart rate is appended to an in-memory history
  And when the session is not recording nothing is tracked
```

```gherkin
Scenario: Custom FIT fields
  Given the recorder is created
  Then it registers a "min_hr" session field (bpm, initialised to 0) and "dive_distance" (m) and "dive_speed" (m/s) lap fields (initialised to 0)
  And the lap fields carry FIT native field numbers 9 (lap total_distance) and 13 (lap avg_speed), so they can stand in the lap table next to heart rate and time
  And "heading" (deg), "accel_peak" (mg) and "depth_pa" (Pa) record fields log every second of a dive
```

```gherkin
Scenario: Pausing and resuming recording
  Given the FIT session is recording and a dive ends
  Then the session is stopped (paused)
  When the next dive starts
  Then the session starts again and a lap is added, except for the very first dive, which only starts the session
  And starting an already-recording session or stopping a non-recording one does nothing
```
