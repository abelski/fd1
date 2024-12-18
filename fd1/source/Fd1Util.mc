import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Attention;
import Toybox.Lang;

module Fd1Util {
    function formatSecundes(sec)as String {
       var minutes = sec / 60;
       var secundes = sec % 60;
       return minutes + ":" + secundes;
    }
    
    class Fd1State {
        public var _session;

        protected var _timeCoef;
        public var mode = "REST";
        public var holdTime = 0;
        public var heartRate = 0;
        public var sessionCycle = 0;
        public var sessionTime = 0;
        public var autoStart = "m";
        public var autoStartPressure = 0;

        public var autoEnd = "m";
        public var autoEndPressure = 0;

        public var pressureNow = 0;
        private var _needBeep = false;


        public function initialize( timeCoef, session ) {
            _timeCoef = timeCoef;
            _session = session;
        }

        function setSession(session){
             _session = session;
        }

        public function setsurface() as Void {
            if(autoEndPressure==0){
                autoEnd="a";
                autoEndPressure = pressureNow.toFloat();
            }else{
                autoEnd="m";
                autoEndPressure = 0;
            }

        }

        public function setdeep() as Void {
            if(autoStartPressure==0){
                autoStart="a";
                autoStartPressure=pressureNow.toFloat();

            }else{
                autoStart="m";
                autoStartPressure = 0;
            }
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
                holdTime = holdTime * _timeCoef;
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
                                     new Attention.VibeProfile(30, 100) 
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
                    if(autoStartPressure>0 && autoStartPressure<pressureNow){
                        changeMode(_session);
                    }
                }else{
                    if(autoEndPressure>0 && autoEndPressure>pressureNow){
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