# fd1 — current behavior

## Purpose
fd1 is a Garmin ConnectIQ watch app (Monkey C, targets instinct2s, instinct2x, fenix6pro) for freediving pool training. The diver alternates DIVE and REST intervals; the app shows a hold/rest timer, heart rate, session totals and per-dive length/distance/speed, gives vibration/tone notifications, and records the whole session as a FIT activity (generic sport, breathwork sub-sport) with one lap per dive. It is driven entirely by watch buttons (Select, Menu, Back, Up/Down) and by the pressure sensor and accelerometer polled once per second; there is no network or phone interface. User settings persist in on-device key-value storage.

## Scenarios

```gherkin
Scenario: App starts with no saved settings
  Given the app has never stored any settings
  When the app launches
  Then start mode is "manual", wait mode is "x2", notifications are "off", pool length is 25 m, and auto-start baseline pressure is 0
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
Scenario: Switching to auto start
  Given the user opens Menu, then Start Mode
  When the user picks "Auto Start"
  Then start mode becomes "auto" and the current ambient pressure (kPa) is captured as the baseline
  And the setting is saved and the pressure confirmation counter is reset
```

```gherkin
Scenario: Switching to manual start
  Given start mode is "auto"
  When the user picks "Manual Start" in the Start Mode menu
  Then start mode becomes "manual" and the baseline pressure is reset to 0 and saved
```

```gherkin
Scenario: Auto start detects a dive
  Given start mode is "auto", a baseline pressure is set, and the app is in REST mode
  When the ambient pressure stays at or above the baseline plus 5 kPa for 3 consecutive one-second polls
  Then the mode changes to DIVE exactly as if Select had been pressed (but without the start tone or vibration from the button handler)
  And the dive still starts on length 1, although its push-off happened about 3 s before the mode changed
```

```gherkin
Scenario: Auto start detects surfacing
  Given start mode is "auto" and the app is in DIVE mode
  When the ambient pressure is at or below the baseline plus 1 kPa for 3 consecutive polls
  Then the mode changes to REST as if Select had been pressed
```

```gherkin
Scenario: Pressure condition interrupted
  Given auto start has counted one or two qualifying polls
  When a poll does not meet the condition
  Then the consecutive counter resets to 0
```

```gherkin
Scenario: Baseline recaptured after restart in auto mode
  Given start mode is "auto" but the stored baseline is 0
  When the first valid pressure reading arrives
  Then that reading becomes the baseline and is saved, and no mode change is evaluated on that poll
```

```gherkin
Scenario: No pressure reading available or manual mode
  Given the ambient pressure is unavailable, or start mode is "manual"
  When the pressure poll runs
  Then no automatic mode change happens
  And if the pressure is unavailable the displayed pressure is 0
```

```gherkin
Scenario: Turn counted by the compass
  Given the app is in DIVE mode and the watch gives a compass heading with each one-second accelerometer batch
  And at least pool length x 2/3 seconds have passed since the dive started or since the last counted turn (25 m: 16 s, 50 m: 33 s)
  When the mean of the last 8 headings (as unit vectors, mean length at least 0.3) points more than 120 degrees away from the current length's heading
  Then the length count increases by one and distance is recomputed as lengths times pool length plus the correction
  And the next length's heading is the first clear 8-second mean after the next pool length x 2/3 seconds
  And push-off spikes are ignored while compass data is coming in, and a DNF stroke cycle (watch pointing back at the hips) averages out
  And the watch gives a light vibration (40 %, 300 ms) so the diver feels the turn was counted, a few seconds after the turn
```

```gherkin
Scenario: Turn counted by push-off spike without compass data
  Given the app is in DIVE mode and no compass heading has come in during this dive
  And at least pool length x 2/3 seconds have passed since the dive started or since the last counted turn
  When any sample in a one-second batch has an acceleration magnitude of at least 1800 milli-g
  Then the length count increases by one and distance is recomputed
  And spikes in the next pool length x 2/3 seconds are ignored: the touch, tumble and push-off of one turn, or a hard kick or stroke
  And the watch gives the same light vibration
```

```gherkin
Scenario: Per-second log for tuning turn detection
  Given the app is in DIVE mode
  When a one-second accelerometer batch arrives
  Then the compass heading in degrees (65535 when none) and the batch's peak acceleration in milli-g are written to the FIT record fields "heading" and "accel_peak"
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
      rows Start / Wait / Notify with the value right-aligned ("Manual", "x2", "CO2", "Off"), and "<now> / <baseline> kPa" for auto start
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
  And "heading" (deg) and "accel_peak" (mg) record fields log every second of a dive
```

```gherkin
Scenario: Pausing and resuming recording
  Given the FIT session is recording and a dive ends
  Then the session is stopped (paused)
  When the next dive starts
  Then the session starts again and a lap is added, except for the very first dive, which only starts the session
  And starting an already-recording session or stopping a non-recording one does nothing
```
