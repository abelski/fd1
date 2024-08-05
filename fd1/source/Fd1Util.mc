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
        protected var _timeCoef;
        public var mode = "REST";
        public var holdTime = 0;
        public var heartRate = 0;
        public var sessionCycle = 0;
        public var sessionTime = 0;
        private var _needBeep = false;


        public function initialize( timeCoef ) {
            _timeCoef = timeCoef;
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
            holdTime = holdTime + 1;
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