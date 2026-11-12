import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.Math;
import Toybox.Sensor;

module Fd1Util {
    function formatSecundes(sec)as String {
       var minutes = sec / 60;
       var secundes = sec % 60;
       return minutes + ":" + secundes.format("%02d");   // "1:03", never "1:3" (reads as 1:30)
    }

    // Distance in meters, e.g. "125m"
    function formatDistance(meters as Float) as String {
        return meters.toNumber() + "m";
    }

    // Speed as "1.2m/s"; kept compact so it fits alongside distance on one
    // row on the smallest target screen (instinct2s, 163px wide).
    function formatSpeed(mps as Float) as String {
        if (mps <= 0) {
            return "--m/s";
        }
        return mps.format("%.1f") + "m/s";
    }

    class Fd1State {
        public var _session;

        public var mode = "REST";
        public var holdTime = 0;
        public var heartRate = 0;
        public var sessionCycle = 0;
        public var sessionTime = 0;
        
        public var startMode; //will be loaded from storage
        public var autoStartPressure = 0;

        public var waitMode; //will be loaded from storage

        public var notification_option_label; //will be loaded from storage
        private var needNotify1min = false;
        private var needNotify30sec = false;
        private var needNotifyStart = false;


        public var pressureNow = 0;
        private var _needBeep = false;

        private const PRESSURE_DIVE_THRESHOLD = 5.0;    // kPa ≈ 0.5 m depth
        private const PRESSURE_SURFACE_THRESHOLD = 1.0; // kPa deadband at surface
        private const PRESSURE_CONFIRM_TICKS = 3;        // consecutive ticks before trigger
        private var _pressureCount = 0;

        public var poolLength = 25;         // meters, loaded from storage; 0 = STA (static, no distance)
        public var currentLengths = 0;      // accelerometer-counted lengths for the current/most recent dive
        public var distanceOffset = 0;      // meters, sum of the diver's +/-10 m corrections this dive
        public var currentDistance = 0.0;   // meters, currentLengths * poolLength + distanceOffset
        public var currentSpeed = 0.0;      // m/s, set at dive end and again on a distance fix during REST
        public var manualOverrideActive = false; // true once user has used Adjust Distance this dive
        public var lastDiveTime = 0;        // seconds of the most recent dive; holdTime is reused for the rest countdown

        private const ACCEL_TURN_THRESHOLD_MILLIG = 1800; // magnitude spike; needs pool tuning
        private const ACCEL_SAMPLE_RATE_HZ = 25;           // a push-off spike is shorter than the gap of a 1 Hz poll
        private var _accelRefractoryCounter = 0;

        // A turn is the swim direction flipping (~180 deg), read from the compass once a second.
        // Headings are averaged as unit vectors over HEADING_WINDOW s: in DNF the watch points
        // forward, then back at the hips on every stroke, and a stroke cycle averages out.
        // All three values are guesses: tune them in the pool from the FIT "heading" log.
        private const HEADING_WINDOW = 8;            // s, longer than a DNF stroke cycle
        private const HEADING_TURN_COS = -0.5;       // a flip is > 120 deg away from the length's heading
        private const HEADING_CONFIDENCE = 0.3;      // mean vector shorter than this = no clear direction
        private var _hx as Array<Float> = new Array<Float>[HEADING_WINDOW];   // ring buffers of the last headings as unit vectors
        private var _hy as Array<Float> = new Array<Float>[HEADING_WINDOW];
        private var _hCount = 0;
        private var _refX = 0.0;                     // this length's heading, set when its window has passed
        private var _refY = 0.0;
        private var _refSet = false;
        private var _headingSeen = false;            // no compass data this dive -> count push-off spikes instead

        //setings for main screen UI showing 
        public var showPage = 1; //1- main


        public function initialize(  session ) {
            _session = session;
            resetHeading();
        }

        function setSession(session){
             _session = session;
        }

    // Function to save settings
    public function saveSettings() as Void {
        Storage.setValue("startMode", startMode);
        Storage.setValue("autoStartPressure", autoStartPressure);
        Storage.setValue("waitMode", waitMode);
        Storage.setValue("poolLength", poolLength);

        Storage.setValue("notification_option_label", notification_option_label);
        Storage.setValue("needNotify1min", needNotify1min);
        Storage.setValue("needNotify30sec", needNotify30sec);
        Storage.setValue("needNotifyStart", needNotifyStart);
    }

    // Function to load settings
    public function loadSettings() as Void {
        startMode = Storage.getValue("startMode");
        if (startMode == null) {
            startMode = "manual";
        }
        autoStartPressure = Storage.getValue("autoStartPressure");
        if (autoStartPressure == null) {
            autoStartPressure = 0;
        }
        waitMode = Storage.getValue("waitMode");
        if (waitMode == null) {
            waitMode = "x2";
        }
        poolLength = Storage.getValue("poolLength");
        if (poolLength == null) {
            poolLength = 25;
        }
        notification_option_label = Storage.getValue("notification_option_label");
        if (notification_option_label == null) {
            notification_option_label = "off";
        }  
        needNotify1min = Storage.getValue("needNotify1min");
        if (needNotify1min == null) {
            needNotify1min = false;
        }
        needNotify30sec = Storage.getValue("needNotify30sec");
        if (needNotify30sec == null) {
            needNotify30sec = false;
        }
        needNotifyStart = Storage.getValue("needNotifyStart");
        if (needNotifyStart == null) {
            needNotifyStart = false;
        }
    }
    
        public function setNotificationOption(str) as Void {            
            if ("notification_mode_off".equals(str)) {
                notification_option_label="off";
                needNotifyStart = false;
                needNotify1min = false;
                needNotify30sec = false;
            } else if ("notification_mode_1min".equals(str)) {
                notification_option_label="1min";
                needNotify1min = true;
                needNotify30sec = false;
                needNotifyStart = true;
            } else if ("notification_mode_30sec".equals(str)) {
                notification_option_label="30sec";
                needNotify1min = true;
                needNotify30sec = true;
                needNotifyStart = true;
            }
            saveSettings();
        }

        public function setWaitingMode(str) as Void {
            if ("wait_mode_30sec".equals(str)) {
                waitMode = "30sec";
            } else if ("wait_mode_1min".equals(str)) {
                waitMode = "1min";
            }else if ("wait_mode_co2".equals(str)) {
                waitMode = "co2";
            }else if ("wait_mode_x2".equals(str)) {
                waitMode = "x2";
            }
            saveSettings();

        }
        public function setPoolLength(str) as Void {
            if ("pool_length_25".equals(str)) {
                poolLength = 25;
            } else if ("pool_length_50".equals(str)) {
                poolLength = 50;
            } else if ("pool_length_sta".equals(str)) {
                poolLength = 0;
            }
            saveSettings();
        }

        public function adjustDistance(deltaMeters as Number) as Void {
            distanceOffset = distanceOffset + deltaMeters;
            var counted = currentLengths * poolLength;
            if (counted + distanceOffset < 0) {
                distanceOffset = -counted;
            }
            manualOverrideActive = true;
            applyDistanceCorrection();
        }

        private function recomputeDistance() as Void {
            currentDistance = currentLengths * poolLength.toFloat() + distanceOffset;
        }

        // A fix made after surfacing must still reach that dive's FIT lap, which is cut at the next addLap().
        private function applyDistanceCorrection() as Void {
            recomputeDistance();
            if ("REST".equals(mode) && sessionCycle > 0) {
                finalizeDiveMetrics(_session);
            }
        }

        private function finalizeDiveMetrics(session) as Void {
            if (lastDiveTime > 0) {
                currentSpeed = currentDistance / lastDiveTime;
            } else {
                currentSpeed = 0.0;
            }
            session.updateDiveMetrics(currentDistance, currentSpeed);
        }

        // Some devices leave the accelerometer off unless a data listener is registered (Sensor.Info.accel docs).
        private function startAccel() as Void {
            if (Sensor has :registerSensorDataListener) {
                Sensor.registerSensorDataListener(method(:onSensorData), {
                    :period => 1,
                    :accelerometer => {:enabled => true, :sampleRate => ACCEL_SAMPLE_RATE_HZ}
                });
            }
        }

        private function stopAccel() as Void {
            if (Sensor has :unregisterSensorDataListener) {
                Sensor.unregisterSensorDataListener();
            }
        }

        public function onSensorData(sensorData as Sensor.SensorData) as Void {
            var accel = sensorData.accelerometerData;
            if (accel != null && accel.x != null && accel.y != null && accel.z != null) {
                var info = Activity.getActivityInfo();
                onAccelSamples(accel.x, accel.y, accel.z, info != null ? info.currentHeading : null);
            }
        }

        // Batches (1 s each) to ignore after the dive start or a counted turn. Divers
        // swim 50 m in ~40-60 s (0.8-1.25 m/s), so a whole pool length lies between
        // walls; at a generous 1.5 m/s that is poolLength * 2/3 s (25 m pool: 16 s, 50 m pool: 33 s).
        // Inside it, spikes are the same wall (touch, tumble, push-off) or a kick/stroke.
        private function minLengthTicks() as Number {
            return poolLength * 2 / 3;
        }

        // One 1 s batch while diving: log it to FIT, then look for at most one turn.
        // heading: compass radians, or null when the watch gives none.
        public function onAccelSamples(xs as Array<Number>, ys as Array<Number>, zs as Array<Number>, heading) as Void {
            if (!"DIVE".equals(mode)) {
                return;
            }
            var peakSq = 0;
            for (var i = 0; i < xs.size(); i++) {
                var sq = xs[i] * xs[i] + ys[i] * ys[i] + zs[i] * zs[i];
                if (sq > peakSq) {
                    peakSq = sq;
                }
            }
            _session.logSample(heading, Math.sqrt(peakSq).toNumber());
            if (heading != null) {
                _headingSeen = true;
                var slot = _hCount % HEADING_WINDOW;
                _hx[slot] = Math.cos(heading);
                _hy[slot] = Math.sin(heading);
                _hCount = _hCount + 1;
            }
            if (_accelRefractoryCounter > 0) {
                _accelRefractoryCounter = _accelRefractoryCounter - 1;
                return;
            }
            var turned = _headingSeen ? headingFlipped()
                : peakSq >= ACCEL_TURN_THRESHOLD_MILLIG * ACCEL_TURN_THRESHOLD_MILLIG;
            if (turned) {
                currentLengths = currentLengths + 1;
                recomputeDistance();
                _accelRefractoryCounter = minLengthTicks();
                _refSet = false;
            }
        }

        private function resetHeading() as Void {
            _hx = new Array<Float>[HEADING_WINDOW];
            _hy = new Array<Float>[HEADING_WINDOW];
            _hCount = 0;
            _refSet = false;
            _headingSeen = false;
        }

        // Mean of the last HEADING_WINDOW headings. The first clear mean after a length's
        // window becomes that length's heading; later ones report whether it flipped.
        private function headingFlipped() as Boolean {
            if (_hCount < HEADING_WINDOW) {
                return false;
            }
            var mx = 0.0;
            var my = 0.0;
            for (var i = 0; i < HEADING_WINDOW; i++) {
                mx = mx + _hx[i];
                my = my + _hy[i];
            }
            var norm = Math.sqrt(mx * mx + my * my);
            if (norm / HEADING_WINDOW < HEADING_CONFIDENCE) {
                return false;
            }
            if (!_refSet) {
                _refX = mx / norm;
                _refY = my / norm;
                _refSet = true;
                return false;
            }
            return (mx * _refX + my * _refY) / norm <= HEADING_TURN_COS;
        }

        public function setStartMode(str) as Void {
            if ("start_mode_auto".equals(str)) {
                startMode = "auto";
                autoStartPressure = pressureNow.toFloat();
            } else {
                startMode = "manual";
                autoStartPressure = 0;
            }
            _pressureCount = 0;
            saveSettings();
        }

        

        public function informNotice() as Void{
            Attention.playTone(Attention.TONE_START);
                        var vibeData =  [
                                            new Attention.VibeProfile(100, 2000) // On for two seconds
                                        ];            
            Attention.vibrate(vibeData);
        }
        // helper that returns 120 s − 15 s×cycles, floor 30 s
        private function getCo2Rest() as Number {
            var base = 120;                   // two minutes
            var dec = 15 * sessionCycle;
            var r = base - dec;          
            if(r < 30) {
                return 30;
            }else{
                return r;
            }
        }

        public function changeMode(session) as Void {
            if ("REST".equals(mode)){
                session.startSession();
                holdTime = 0;
                // A dive starts on its first length: auto start fires ~3 s after
                // submerging, long after the push-off spike, so that spike can't be counted.
                currentLengths = 1;
                distanceOffset = 0;
                recomputeDistance();
                currentSpeed = 0.0;
                // the new lap starts with this dive's values, not the last dive's (an exit mid-dive saves them)
                session.updateDiveMetrics(currentDistance, currentSpeed);
                manualOverrideActive = false;
                _accelRefractoryCounter = minLengthTicks();
                resetHeading();
                if (poolLength > 0) {   // STA: nothing to count, spare the battery
                    startAccel();
                }
                mode = "DIVE";
            }else{
                recomputeDistance();
                lastDiveTime = holdTime;
                finalizeDiveMetrics(session);
                stopAccel();
                session.stopSession();
                sessionCycle=sessionCycle + 1;
                sessionTime =sessionTime+holdTime;

                if ( "x2".equals(waitMode)) {
                    holdTime = holdTime * 2;
                } else if ("30sec".equals(waitMode)) {
                    holdTime = 30;
                } else if ("1min".equals(waitMode)) {
                    holdTime = 60;
                } else if ("co2".equals(waitMode)) {
                    holdTime = getCo2Rest();    
                }else{
                    holdTime = 0;
                }
                mode = "REST";
            }
        }
    public function updateTimer() as Void {
        
        if ("REST".equals(mode)){
                
                if(holdTime>0){
                    holdTime = holdTime - 1;
                    //shortly vibrate last 10 sec before dive
                    if(holdTime<11 && needNotifyStart){
                            var vibeData =  [
                                            new Attention.VibeProfile(30, 500) 
                                        ];
                            Attention.vibrate(vibeData);
                    }
                }else{
                    if(_needBeep){
                        _needBeep = false;
                        Attention.playTone(Attention.TONE_LOUD_BEEP);
                        var vibeData =  [
                                            new Attention.VibeProfile(100, 2000) // On for two seconds
                                        ];
                        Attention.vibrate(vibeData);
                    }
                }
        }else{
            if(_needBeep == false){
                _needBeep = true;
            }
            //vibrate every minute or 30sec if particular option is on
            var divCoef = 60;
            if(needNotify30sec){
                divCoef = 30;
            }
            var holdSecMin = holdTime % divCoef;
            if(holdSecMin==0 && (needNotify1min || needNotify30sec)){
                var vibeData =  [
                                     new Attention.VibeProfile(100, 100) 
                                 ];
                Attention.vibrate(vibeData);
            }

            holdTime = holdTime + 1;
        }
    }


        public function updatePressure() as Void {
            var rawPressure;

            var ap = Activity.getActivityInfo().ambientPressure;
            if (ap == null) {
                pressureNow = 0;
                return;
            }
            rawPressure = ap / 1000.0;

            pressureNow = rawPressure;

            // Re-capture baseline on first valid reading after restart with auto mode
            if ("auto".equals(startMode) && autoStartPressure == 0 && rawPressure > 0) {
                autoStartPressure = rawPressure.toFloat();
                saveSettings();
                return;
            }

            if (autoStartPressure <= 0 || !"auto".equals(startMode)) {
                return;
            }

            var conditionMet = false;
            if ("REST".equals(mode)) {
                // diver went deep enough: pressure rose by at least PRESSURE_DIVE_THRESHOLD
                conditionMet = pressureNow >= autoStartPressure + PRESSURE_DIVE_THRESHOLD;
            } else {
                // diver surfaced: pressure returned within PRESSURE_SURFACE_THRESHOLD of baseline
                conditionMet = pressureNow <= autoStartPressure + PRESSURE_SURFACE_THRESHOLD;
            }

            if (conditionMet) {
                _pressureCount = _pressureCount + 1;
                if (_pressureCount >= PRESSURE_CONFIRM_TICKS) {
                    _pressureCount = 0;
                    changeMode(_session);
                }
            } else {
                _pressureCount = 0;
            }
        }

        public function updateHeartrate() as Void {
            var currentHeartRate = Activity.getActivityInfo().currentHeartRate;
            if(currentHeartRate!=null){
                heartRate = currentHeartRate;
            }else{
                var HRH=ActivityMonitor.getHeartRateHistory(1, true);
                var HRS=HRH.next();
                var HRSnow=HRS.heartRate;
                if(HRSnow!= ActivityMonitor.INVALID_HR_SAMPLE){
                    heartRate = HRSnow;
                }
            }    
        }
    }
}