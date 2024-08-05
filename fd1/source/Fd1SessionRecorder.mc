using Toybox.Timer;
using Toybox.FitContributor;
using Toybox.ActivityRecording;
using Toybox.Sensor;
using Toybox.System as Sys;
using  Toybox.FitContributor;


module Fd1SessionRecorder {
    class Fd1SessionSpec {
		private static const SUB_SPORT_BREATHWORKS = 62;
		
	
		static function createFdSession(sessionName) {
			return {
                 :name => sessionName,                              
                 :sport => ActivityRecording.SPORT_GENERIC,      
                 :subSport => SUB_SPORT_BREATHWORKS
            };
		}
	}

    class Fd1Activity {
        private var _FitSession;		
	    private const _RefreshActivityInterval = 1000;	
	    private var _RefreshActivityTimer;

        private const MinHrFieldId = 0;
		private var mMinHrField;
		private var mMinHr;
		private var mHRHistory = [];
        
        function onBeforeStart(fitSession) {
		}

		public function startLap() as Void {
			_FitSession.addLap();
            
        }

        private function createMinHrDataField() as Void{
			me.mMinHrField = me._FitSession.createField(
	            "min_hr",
	            me.MinHrFieldId,
	            FitContributor.DATA_TYPE_UINT16,
	            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :units=> "bpm"}
	        );
			
	        me.mMinHrField.setData(0);
		}

        protected function onRefreshHrActivityStats(activityInfo, minHr) {
		}
        
        function refreshActivityStats() as Void{
            System.println("State updated");
			
		    var activityInfo = Activity.getActivityInfo();
		    if (activityInfo == null) {
				return;
			}

			if (me._FitSession.isRecording()) {

				if (activityInfo.currentHeartRate != null && (me.mMinHr == null || me.mMinHr > activityInfo.currentHeartRate)) {
					me.mMinHr = activityInfo.currentHeartRate;
				}

				mHRHistory.add(activityInfo.currentHeartRate);
			}

	    	 me.onRefreshHrActivityStats(activityInfo, me.mMinHr);
		}

        
		
        function initialize() {
             me._FitSession = ActivityRecording.createSession(Fd1SessionSpec.createFdSession("Freediving"));
			 me.createMinHrDataField();	
			 me.onBeforeStart(me._FitSession);
			 me._FitSession.start(); 
		     me._RefreshActivityTimer = new Timer.Timer();		
		     me._RefreshActivityTimer.start(method(:refreshActivityStats), _RefreshActivityInterval, true);
             System.println("Session started:" + me._FitSession);
        }

        function finish() {	
            me._FitSession.stop();	
			me._FitSession.save();
			me._FitSession = null;
		}

        function discard() {		
			me._FitSession.discard();
			me._FitSession = null;
		}
    }

}