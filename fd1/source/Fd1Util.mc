import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Application.Storage;

module Fd1Util {
    function formatSecundes(sec)as String {
       var minutes = sec / 60;
       var secundes = sec % 60;
       return minutes + ":" + secundes;
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

        public var pressureNow = 0;
        private var _needBeep = false;


        public function initialize(  session ) {
            _session = session;
        }

        function setSession(session){
             _session = session;
        }

    // Function to save settings
    public function saveSettings() as Void {
        Storage.setValue("startMode", startMode);
        Storage.setValue("waitMode", waitMode);
    }

    // Function to load settings
    public function loadSettings() as Void {
        startMode = Storage.getValue("startMode");
        if (startMode == null) {
            startMode = "manual";
        }
        waitMode = Storage.getValue("waitMode");
        if (waitMode == null) {
            waitMode = "x2";
        }
    }
    
        public function setWaitingMode() as Void {
            if ("x2".equals(waitMode)) {
                waitMode = "30sec";
            } else if ("30sec".equals(waitMode)) {
                waitMode = "1min";
            }else if ("1min".equals(waitMode)) {
                waitMode = "x2";
            }
            saveSettings();

        }
        public function setMode() as Void{
            if(autoStartPressure==0){
                startMode="auto";
                autoStartPressure=pressureNow.toFloat();

            }else{
                startMode="manual";
                autoStartPressure = 0;
            }
            saveSettings();
        }

        

        public function informNotice() as Void{
            Attention.playTone(Attention.TONE_START);
                        var vibeData =  [
                                            new Attention.VibeProfile(100, 2000) // On for two seconds
                                        ];            
            Attention.vibrate(vibeData);
        }
        public function changeMode(session) as Void {
            if ("REST".equals(mode)){
                session.startSession();
                holdTime = 0;
                mode = "DIVE";
            }else{
                session.stopSession();
                sessionCycle=sessionCycle + 1;
                sessionTime =sessionTime+holdTime;
                
                if ( "x2".equals(waitMode)) {
                    holdTime = holdTime * 2;
                } else if ("30sec".equals(waitMode)) {
                    holdTime = 30;
                } else if ("1min".equals(waitMode)) {
                    holdTime = 60;
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
                    if(holdTime<11){
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
            //vibrate every minute
            var holdSec = holdTime%60;
            if(holdSec==0){
                var vibeData =  [
                                     new Attention.VibeProfile(100, 100) 
                                 ];
                Attention.vibrate(vibeData);
            }

            holdTime = holdTime + 1;
        }
    }


        public function updatePressure() as Void {
            var currentPressure = Activity.getActivityInfo().ambientPressure;
            //var currentPressure = 97.7;
            
            if(currentPressure!=null){
                pressureNow = (currentPressure/1000);
                if("REST".equals(mode)){
                    if(autoStartPressure>0 && autoStartPressure<=pressureNow){
                        changeMode(_session);
                    }
                }else{
                    if(autoStartPressure>0 && autoStartPressure>pressureNow){
                        changeMode(_session);
                    }
                }
            
            }else{
                pressureNow = 0;
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