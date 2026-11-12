import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;
import Fd1Util;

// Records what Fd1State sends to the FIT recorder.
(:test)
class StubSession {
    var lastDistance = null;
    var lastSpeed = null;
    var lastHeading = null;
    var lastPeak = null;
    var lastDepthPa = null;

    function initialize() {
    }

    function startSession() {
    }

    function stopSession() {
    }

    function updateDiveMetrics(distance, speed) {
        lastDistance = distance;
        lastSpeed = speed;
    }

    function logSample(heading, peak, depthPa) {
        lastHeading = heading;
        lastPeak = peak;
        lastDepthPa = depthPa;
    }
}

// Helpers live in a class so the runner does not call them as tests.
(:test)
class Sim {
    // One second of 25 Hz accelerometer samples (milli-g). Gravity on z wobbles
    // 0.5 g..1.5 g like a dolphin kick, staying under the 1.8 g turn threshold.
    // spikeAt >= 0 puts a 2.5 g wall push-off on that sample.
    static function batch(spikeAt as Number) as Array<Array<Number>> {
        var xs = new Array<Number>[25];
        var ys = new Array<Number>[25];
        var zs = new Array<Number>[25];
        for (var i = 0; i < 25; i++) {
            xs[i] = 0;
            ys[i] = 0;
            zs[i] = (i / 5) % 2 == 0 ? 1500 : 500;
        }
        if (spikeAt >= 0) {
            xs[spikeAt] = 2500;
        }
        return [xs, ys, zs];
    }

    // Manual dive: Select, `seconds` of swimming (one sensor batch and one timer
    // tick per second), Select. spikes maps second -> sample index of a push-off.
    static function dive(state, session, seconds as Number, spikes as Dictionary) as Void {
        diveCourse(state, session, seconds, spikes, null);   // no compass: push-off spikes count turns
    }

    // As dive(), with a compass heading per second (radians; null array = no compass).
    static function diveCourse(state, session, seconds as Number, spikes as Dictionary, headings) as Void {
        state.changeMode(session);
        for (var s = 0; s < seconds; s++) {
            var b = batch(spikes.hasKey(s) ? spikes[s] : -1);
            state.onAccelSamples(b[0], b[1], b[2], headings == null ? null : headings[s]);
            state.updateTimer();
        }
        state.changeMode(session);
    }

    // Heading per second: 0.3 rad, flipped by pi after each turn second, with +/-0.2 rad jitter.
    // dnf: the watch points back at the hips 2 s of every 6 s stroke cycle.
    static function course(seconds as Number, turns as Array<Number>, dnf as Boolean) as Array {
        var h = new [seconds];
        var flips = 0;
        for (var s = 0; s < seconds; s++) {
            if (turns.indexOf(s) >= 0) {
                flips = flips + 1;
            }
            var a = 0.3 + (s % 3 - 1) * 0.2 + (flips % 2) * Math.PI;
            if (dnf && s % 6 >= 4) {
                a = a + Math.PI;
            }
            h[s] = a;
        }
        return h;
    }

    static function near(a, b) as Boolean {
        return (a - b).abs() < 0.001;
    }

    static function autoState(session, pool as Number) {
        var state = new Fd1Util.Fd1State(session);
        state.startMode = "auto";
        state.poolLength = pool;
        return state;
    }

    // One second with the wrist `level` kPa under Wednesday's 100.56 kPa surface (~10 kPa per
    // metre): pressure poll, sensor batch, clock tick.
    static function tick(state, level as Float, heading) as Void {
        state.onPressure(100.56 + level);
        var b = batch(-1);
        state.onAccelSamples(b[0], b[1], b[2], heading);
        state.updateTimer();
    }

    static function hold(state, level as Float, seconds as Number) as Void {
        for (var s = 0; s < seconds; s++) {
            tick(state, level, null);
        }
    }

    static function trace(state, levels as Array) as Void {
        for (var s = 0; s < levels.size(); s++) {
            tick(state, levels[s], null);
        }
    }
}

// --- simulated dives -------------------------------------------------------

// Timings follow real divers: 50 m in 40-60 s (0.8-1.25 m/s), so a 25 m length takes 20-30 s.
(:test)
function testSimulated50mDiveIn25mPool(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    // push-off at 1 s (the start length); turn at 25 m: wall touch at 24 s, push-off at 26 s
    Sim.dive(state, session, 50, {1 => 5, 24 => 20, 26 => 5});
    logger.debug("lengths=" + state.currentLengths + " dist=" + state.currentDistance + " speed=" + state.currentSpeed);
    return state.currentLengths == 2 && state.currentDistance == 50.0
        && Sim.near(state.currentSpeed, 1.0) && session.lastDistance == 50.0 && Sim.near(session.lastSpeed, 1.0);
}

(:test)
function testSimulated150mDiveIn50mPoolTurnAcrossBatches(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.poolLength = 50;
    // turn 1 at ~50 s: one spike split over the last sample of second 49 and the first of 50;
    // turn 2 at ~100 s: touch at 99 s, push-off at 101 s; surfaced at the wall after 150 s
    Sim.dive(state, session, 150, {0 => 3, 49 => 24, 50 => 0, 99 => 20, 101 => 5});
    logger.debug("lengths=" + state.currentLengths + " dist=" + state.currentDistance + " speed=" + state.currentSpeed);
    return state.currentLengths == 3 && state.currentDistance == 150.0 && Sim.near(session.lastSpeed, 1.0);
}

(:test)
function testSimulatedMidLengthSpikeIn50mPoolIgnored(logger as Logger) as Boolean {
    // 50 m pool, one length in 50 s; a hard kick/stroke spike at 15 s is not a wall. Without a
    // compass, spikes after the 20 s window would count; the Instincts always give a heading.
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.poolLength = 50;
    Sim.dive(state, session, 50, {1 => 5, 15 => 12});
    return state.currentLengths == 1 && session.lastDistance == 50.0 && Sim.near(session.lastSpeed, 1.0);
}

(:test)
function testSimulatedKickingAddsNoTurns(logger as Logger) as Boolean {
    // no wall touched: the dive stays on its first length
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 30, {});
    return state.currentLengths == 1 && session.lastDistance == 25.0 && Sim.near(session.lastSpeed, 25.0 / 30);
}

(:test)
function testSimulatedPushOffIsTheFirstLengthNotASecond(logger as Logger) as Boolean {
    // manual start: a spike from pressing Select, then the push-off 5 s later -> still 1 length
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 15, {0 => 20, 5 => 4});
    return state.currentLengths == 1 && session.lastDistance == 25.0;
}

(:test)
function testSimulatedDiveThenSurfaceFixMinus10(logger as Logger) as Boolean {
    // diver surfaced at 40 m: auto count says 2 lengths (50 m), fix by -10 m in REST
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 40, {0 => 2, 20 => 10});
    state.adjustDistance(-10);
    return state.currentDistance == 40.0 && session.lastDistance == 40.0 && Sim.near(session.lastSpeed, 1.0);
}

(:test)
function testSimulatedTurnedThenSurfacedAt35mSaves30(logger as Logger) as Boolean {
    // the user's example: 25 m pool, one turn -> watch shows 50 m; the diver swam 35 m
    // and presses -10 twice to keep 30 m as the result
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 35, {1 => 5, 24 => 20, 26 => 5});
    var shown = state.currentDistance == 50.0;
    state.adjustDistance(-10);
    state.adjustDistance(-10);
    return shown && state.currentDistance == 30.0 && session.lastDistance == 30.0 && Sim.near(session.lastSpeed, 30.0 / 35);
}

(:test)
function testNewDiveLapDoesNotKeepLastDiveDistance(logger as Logger) as Boolean {
    // exit in the middle of dive 2 must not save dive 1's 50 m into dive 2's lap
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 50, {1 => 5, 24 => 20});
    state.changeMode(session);   // dive 2 starts
    return session.lastDistance == 25.0 && session.lastSpeed == 0.0;
}

(:test)
function testSimulatedSecondDiveStartsClean(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 40, {0 => 2, 20 => 10});
    state.adjustDistance(10);
    Sim.dive(state, session, 20, {0 => 2});
    return state.currentLengths == 1 && state.currentDistance == 25.0 && !state.manualOverrideActive;
}

(:test)
function testSimulatedStaHoldRecordsNoDistance(logger as Logger) as Boolean {
    // STA: a 2-minute static hold; no listener is registered, but stop still runs at the end
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.poolLength = 0;
    Sim.dive(state, session, 120, {});
    return state.currentDistance == 0.0 && session.lastDistance == 0.0 && session.lastSpeed == 0.0
        && !state.distanceToConfirm;   // no distance screen in STA
}

(:test)
function testDiveEndAsksToConfirmDistance(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.dive(state, session, 30, {});
    var asked = state.distanceToConfirm;
    state.changeMode(session);   // next dive starts before the screen was shown
    return asked && !state.distanceToConfirm;
}

// --- compass: a turn is the direction flipping ------------------------------

(:test)
function testCompassCountsSoftTurnsWithoutPushOff(logger as Logger) as Boolean {
    // DYN, 75 m in 75 s in a 25 m pool; turns at 25 s and 50 s with no push-off spike at all
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.diveCourse(state, session, 75, {}, Sim.course(75, [25, 50], false));
    logger.debug("compass DYN lengths=" + state.currentLengths);
    return state.currentLengths == 3 && session.lastDistance == 75.0;
}

(:test)
function testCompassIgnoresKickSpikes(logger as Logger) as Boolean {
    // one 25 m length, hard kicks after the 10 s window; the direction never flips
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.diveCourse(state, session, 28, {18 => 12, 22 => 12}, Sim.course(28, [], false));
    return state.currentLengths == 1 && session.lastDistance == 25.0;
}

(:test)
function testCompassCountsTurnsInDnf(logger as Logger) as Boolean {
    // DNF: the watch points back at the hips 2 s of every 6 s, yet only real turns count
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.diveCourse(state, session, 75, {}, Sim.course(75, [25, 50], true));
    logger.debug("compass DNF lengths=" + state.currentLengths);
    return state.currentLengths == 3 && session.lastDistance == 75.0;
}

(:test)
function testEverySecondIsLoggedForTuning(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.onPressure(101.0);   // REST: the surface
    state.mode = "DIVE";
    state.onPressure(101.5);   // 0.5 kPa under it
    var b = Sim.batch(12);
    state.onAccelSamples(b[0], b[1], b[2], 1.0);
    return session.lastHeading == 1.0 && session.lastPeak >= 2500 && session.lastDepthPa == 500;
}

// --- auto start/stop on real wrist depths --------------------------------------
// Levels are kPa under the surface, taken from the logged sessions. Their FIT altitude stops at
// ~0.7 m (^ in the logs), so swimming deeper is played at 8 kPa.

(:test)
function testAutoStartCountsThePauseAtTheWall(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = Sim.autoState(session, 50);
    Sim.hold(state, 0.0, 5);   // resting, hand at the surface
    // Wednesday dive 5: under, a 25 s pause at the wall that comes back up to 0.2 m, then the push-off
    Sim.trace(state, [5.6, 5.9, 4.1, 5.3, 5.3, 5.3, 5.3, 5.2, 5.2, 4.6, 3.8, 2.9, 2.4, 2.1,
        2.0, 2.0, 2.0, 2.0, 2.0, 2.1, 2.1, 2.1, 2.2, 2.2, 2.2, 4.0, 6.3]);
    var inDive = "DIVE".equals(state.mode);
    Sim.hold(state, 8.0, 49);       // the 50 m swim
    Sim.trace(state, [2.5, 1.5]);   // surfaced, the hand still in the water
    logger.debug("dive " + state.lastDiveTime + " s");
    // logged by hand as 81 s: 5 s at the surface before going under, then 1 s to confirm each end
    return inDive && "REST".equals(state.mode) && state.sessionCycle == 1 && state.lastDiveTime == 76;
}

(:test)
function testHandInTheWaterDuringRestWaitsForTheCountdown(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = Sim.autoState(session, 25);
    state.waitMode = "x2";
    Sim.hold(state, 0.0, 3);
    Sim.hold(state, 8.0, 30);       // a 30 s dive
    Sim.trace(state, [2.5, 2.0]);   // surfaced: 60 s rest
    Sim.hold(state, 3.0, 40);       // hanging at the wall, hand 0.3 m under water
    var rested = "REST".equals(state.mode) && state.sessionCycle == 1;
    // the countdown is over: that hand now starts the next dive at once (known limit)
    Sim.hold(state, 3.0, 21);
    return rested && "DIVE".equals(state.mode);
}

(:test)
function testShallowEndSwimDoesNotStopTheDive(logger as Logger) as Boolean {
    // 2026-04-19 dive 21: pushed off deep, then swam the second half at ~0.5 m
    var state = Sim.autoState(new StubSession(), 25);
    Sim.hold(state, 0.2, 3);
    Sim.trace(state, [5.3, 8.0, 8.0, 4.9, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0, 8.0,
        5.4, 5.3, 5.2, 5.0, 5.0, 5.0, 4.9, 4.9, 4.9, 4.9, 4.9, 4.9, 4.9, 4.9, 4.8, 4.4]);
    var swimming = "DIVE".equals(state.mode);
    Sim.trace(state, [3.5, 3.0]);
    return swimming && "REST".equals(state.mode) && state.sessionCycle == 1;
}

(:test)
function testManualStartInAutoModeWaitsForTheWater(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = Sim.autoState(session, 50);
    Sim.hold(state, 0.0, 2);
    state.changeMode(session);      // Select at the wall, hand in the air
    Sim.hold(state, 0.0, 8);        // last breaths: not a surfacing
    var waited = "DIVE".equals(state.mode);
    Sim.hold(state, 8.0, 40);
    Sim.trace(state, [2.0, 1.5]);
    return waited && "REST".equals(state.mode) && state.lastDiveTime == 49;
}

(:test)
function testStaStopsWhenTheHandLeavesTheWater(logger as Logger) as Boolean {
    var state = Sim.autoState(new StubSession(), 0);
    Sim.hold(state, 0.0, 2);
    Sim.hold(state, 3.0, 120);      // static hold, wrist 0.3 m down
    Sim.hold(state, 2.0, 10);       // head up, hand still in the water: looks like a pause
    var holding = "DIVE".equals(state.mode);
    Sim.hold(state, 0.5, 5);        // hand on the edge
    return holding && "REST".equals(state.mode);
}

(:test)
function testSurfaceIsTheLowestRestReadingAndNotStored(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.onPressure(103.20);       // hand in the water
    state.onPressure(102.85);       // in the air: the surface on 2026-11-04
    state.onPressure(103.00);
    var restarted = new Fd1Util.Fd1State(new StubSession());
    restarted.loadSettings();       // the logged surfaces differ by up to 2.8 kPa between days
    return Sim.near(state.surfacePressure, 102.85) && restarted.surfacePressure == 0;
}

(:test)
function testPauseFacingTheWallIsNotATurn(logger as Logger) as Boolean {
    // manual 25 m dive: a 25 s pause facing the wall outlasts the 10 s turn window, then the push-off
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    Sim.hold(state, 0.0, 2);
    state.changeMode(session);
    for (var s = 0; s < 25; s++) {
        Sim.tick(state, 3.0, 0.3 + Math.PI);
    }
    for (var s = 0; s < 25; s++) {
        Sim.tick(state, 8.0, 0.3);
    }
    state.changeMode(session);
    return state.currentLengths == 1;
}

// --- distance correction -----------------------------------------------------

(:test)
function testDistanceStepIsTenMeters(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.mode = "DIVE";
    var b = Sim.batch(12);
    state.onAccelSamples(b[0], b[1], b[2], null);
    state.adjustDistance(10);
    var up = state.currentDistance == 35.0;
    state.adjustDistance(-10);
    state.adjustDistance(-10);
    return up && state.currentDistance == 15.0 && state.manualOverrideActive;
}

(:test)
function testDistanceNeverBelowZero(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.adjustDistance(-10);
    var zero = state.currentDistance == 0.0;
    state.adjustDistance(10);
    return zero && state.currentDistance == 10.0;
}


(:test)
function testZeroHoldTimeGivesZeroSpeed(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.changeMode(session);   // starts on length 1 = 25 m
    state.adjustDistance(10);
    state.changeMode(session);
    return session.lastSpeed == 0.0 && session.lastDistance == 35.0;
}

(:test)
function testRestCorrectionUpdatesLapAndSpeed(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.changeMode(session);
    state.holdTime = 50;
    state.changeMode(session);   // surfaced on the first length, 25 m
    for (var i = 0; i < 5; i++) {
        state.adjustDistance(10);
    }
    return session.lastDistance == 75.0 && session.lastSpeed == 1.5 && state.currentSpeed == 1.5;
}

(:test)
function testCorrectionBeforeFirstDiveSkipsFit(logger as Logger) as Boolean {
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.adjustDistance(10);
    return session.lastDistance == null;
}

// --- accelerometer -----------------------------------------------------------

// Mode is set directly so no real sensor listener is registered.
(:test)
function testTurnsAreAtLeastTwoFifthsOfAPoolLengthApart(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.mode = "DIVE";
    var xs = [0, 1900, 1900];   // two spike samples in one batch
    var ys = [0, 0, 0];
    var zs = [1000, 1000, 1000];
    state.onAccelSamples(xs, ys, zs, null);   // counts 1
    for (var i = 0; i < 10; i++) {
        state.onAccelSamples(xs, ys, zs, null);   // 25 m pool: the next 10 s are the same wall
    }
    var held = state.currentLengths == 1;
    state.onAccelSamples(xs, ys, zs, null);   // 11 s later: a new wall
    return held && state.currentLengths == 2 && state.currentDistance == 50.0;
}

(:test)
function testGravityAloneIsNotATurn(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.mode = "DIVE";
    state.onAccelSamples([0, 0], [0, 0], [1000, 1000], null);
    return state.currentLengths == 0;
}

(:test)
function testAccelIgnoredInRest(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.onAccelSamples([1900], [0], [1000], null);
    return state.currentLengths == 0;
}

// --- formatting and settings -------------------------------------------------

(:test)
function testFormatDistanceAndSpeed(logger as Logger) as Boolean {
    return Fd1Util.formatSecundes(0).equals("0:00") && Fd1Util.formatSecundes(63).equals("1:03")
        && Fd1Util.formatSecundes(3599).equals("59:59")
        && Fd1Util.formatDistance(125.0).equals("125m")
        && Fd1Util.formatSpeed(0.0).equals("--m/s")
        && Fd1Util.formatSpeed(1.16).equals("1.2m/s");
}

(:test)
function testAllSettingsPersist(logger as Logger) as Boolean {
    // every setting must survive an app restart (a fresh state loading from Storage)
    var state = new Fd1Util.Fd1State(new StubSession());
    state.loadSettings();
    state.setStartMode(:start_mode_auto);
    state.setWaitingMode(:wait_mode_co2);
    state.setNotificationOption(:notification_mode_30sec);
    state.setPoolLength(:pool_length_50);
    var reloaded = new Fd1Util.Fd1State(new StubSession());
    reloaded.loadSettings();
    var ok = "auto".equals(reloaded.startMode) && "co2".equals(reloaded.waitMode)
        && "30sec".equals(reloaded.notification_option_label) && reloaded.poolLength == 50;
    // leave the simulator's storage at the defaults
    state.setStartMode(:start_mode_manual);
    state.setWaitingMode(:wait_mode_x2);
    state.setNotificationOption(:notification_mode_off);
    state.setPoolLength(:pool_length_25);
    return ok;
}

// The menu delegates pass the item's id symbol as it is: a watch build keeps no symbol names,
// so the old item.toString() matched nothing there (the simulator's debug build hid that).
(:test)
function testEveryMenuItemSetsItsValue(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.loadSettings();
    var pools = [] as Array<Number>;
    var pick = [:pool_length_sta, :pool_length_50, :pool_length_25];
    for (var i = 0; i < pick.size(); i++) {
        state.setPoolLength(pick[i]);
        pools.add(state.poolLength);
    }
    var waits = "";
    pick = [:wait_mode_1min, :wait_mode_30sec, :wait_mode_co2, :wait_mode_x2];
    for (var i = 0; i < pick.size(); i++) {
        state.setWaitingMode(pick[i]);
        waits = waits + state.waitMode + " ";
    }
    var notes = "";
    pick = [:notification_mode_1min, :notification_mode_30sec, :notification_mode_off];
    for (var i = 0; i < pick.size(); i++) {
        state.setNotificationOption(pick[i]);
        notes = notes + state.notification_option_label + " ";
    }
    state.setStartMode(:start_mode_auto);
    var auto = state.startMode;
    state.setStartMode(:start_mode_manual);   // the rest already ended at the defaults
    logger.debug("pools " + pools + " waits " + waits + "notes " + notes + auto);
    return pools[0] == 0 && pools[1] == 50 && pools[2] == 25 && waits.equals("1min 30sec co2 x2 ")
        && notes.equals("1min 30sec off ") && "auto".equals(auto) && "manual".equals(state.startMode);
}
