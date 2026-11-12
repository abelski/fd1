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

    function logSample(heading, peak) {
        lastHeading = heading;
        lastPeak = peak;
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
    // 50 m pool, one length in 50 s; a hard kick/stroke spike at 20 s is not a wall
    var session = new StubSession();
    var state = new Fd1Util.Fd1State(session);
    state.poolLength = 50;
    Sim.dive(state, session, 50, {1 => 5, 20 => 12});
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
    return state.currentDistance == 0.0 && session.lastDistance == 0.0 && session.lastSpeed == 0.0;
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
    // one 25 m length, hard kicks after the 16 s window; the direction never flips
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
    state.mode = "DIVE";
    var b = Sim.batch(12);
    state.onAccelSamples(b[0], b[1], b[2], 1.0);
    return session.lastHeading == 1.0 && session.lastPeak >= 2500;
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
function testTurnsAreAtLeastTwoThirdsOfAPoolLengthApart(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.mode = "DIVE";
    var xs = [0, 1900, 1900];   // two spike samples in one batch
    var ys = [0, 0, 0];
    var zs = [1000, 1000, 1000];
    state.onAccelSamples(xs, ys, zs, null);   // counts 1
    for (var i = 0; i < 16; i++) {
        state.onAccelSamples(xs, ys, zs, null);   // 25 m pool: the next 16 s are the same wall
    }
    var held = state.currentLengths == 1;
    state.onAccelSamples(xs, ys, zs, null);   // 17 s later: a new wall
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
    state.setStartMode("start_mode_auto");
    state.setWaitingMode("wait_mode_co2");
    state.setNotificationOption("notification_mode_30sec");
    state.setPoolLength("pool_length_50");
    var reloaded = new Fd1Util.Fd1State(new StubSession());
    reloaded.loadSettings();
    var ok = "auto".equals(reloaded.startMode) && "co2".equals(reloaded.waitMode)
        && "30sec".equals(reloaded.notification_option_label) && reloaded.poolLength == 50;
    // leave the simulator's storage at the defaults
    state.setStartMode("start_mode_manual");
    state.setWaitingMode("wait_mode_x2");
    state.setNotificationOption("notification_mode_off");
    state.setPoolLength("pool_length_25");
    return ok;
}

// The menu delegates pass item.toString(); the setters only work if a menu
// symbol turns into its resource id string on the device.
(:test)
function testMenuSymbolsReachTheSetters(logger as Logger) as Boolean {
    var state = new Fd1Util.Fd1State(new StubSession());
    state.loadSettings();
    var sta = :pool_length_sta;
    var co2 = :wait_mode_co2;
    logger.debug("symbol toString: " + sta.toString());
    state.setPoolLength(sta.toString());
    state.setWaitingMode(co2.toString());
    var ok = state.poolLength == 0 && "co2".equals(state.waitMode);
    state.setPoolLength("pool_length_25");   // leave the simulator's storage at the defaults
    state.setWaitingMode("wait_mode_x2");
    return ok;
}
