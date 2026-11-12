using Toybox.Timer;
using Toybox.FitContributor;
using Toybox.ActivityRecording;
using Toybox.Math;
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

		private const DiveDistanceFieldId = 1;
		private const DiveSpeedFieldId = 2;
		private var mDiveDistanceField;
		private var mDiveSpeedField;

		private const HeadingFieldId = 3;
		private const AccelPeakFieldId = 4;
		private var mHeadingField;
		private var mAccelPeakField;

		private var _isItFirstLap = true;
        
        function onBeforeStart(fitSession) {
		}

		public function startLap() as Void {
			if (me._FitSession.isRecording()){
				me._FitSession.addLap();
			}	   
        }

		public function startSession() {
			if (me._FitSession.isRecording()==false) {
				me._FitSession.start();
				if (_isItFirstLap==false){
					startLap();
				}else{
					_isItFirstLap = false;
				}
			}
		}

		public function stopSession() {
			if (me._FitSession.isRecording()) {
				me._FitSession.stop();
			}
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

		// :nativeNum marks them as the FIT lap's own total_distance (9) and avg_speed (13), so the lap
		// table can show them next to heart rate and time. Speed is the dive's average: distance / dive time.
		private function createDiveMetricFields() as Void{
			me.mDiveDistanceField = me._FitSession.createField(
	            "dive_distance",
	            me.DiveDistanceFieldId,
	            FitContributor.DATA_TYPE_FLOAT,
	            {:mesgType=>FitContributor.MESG_TYPE_LAP, :units=> "m", :nativeNum=> 9}
	        );
			me.mDiveDistanceField.setData(0.0);

			me.mDiveSpeedField = me._FitSession.createField(
	            "dive_speed",
	            me.DiveSpeedFieldId,
	            FitContributor.DATA_TYPE_FLOAT,
	            {:mesgType=>FitContributor.MESG_TYPE_LAP, :units=> "m/s", :nativeNum=> 13}
	        );
			me.mDiveSpeedField.setData(0.0);
		}

		// Raw per-second signals in the FIT records, to tune turn detection from a pool
		// session: compass heading (deg, 0xFFFF = none) and the second's peak acceleration (milli-g).
		private function createSampleFields() as Void {
			me.mHeadingField = me._FitSession.createField(
	            "heading",
	            me.HeadingFieldId,
	            FitContributor.DATA_TYPE_UINT16,
	            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=> "deg"}
	        );
			me.mAccelPeakField = me._FitSession.createField(
	            "accel_peak",
	            me.AccelPeakFieldId,
	            FitContributor.DATA_TYPE_UINT16,
	            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=> "mg"}
	        );
		}

		// Called once a second while diving, from Fd1State.onAccelSamples().
		public function logSample(heading, accelPeak) as Void {
			me.mHeadingField.setData(heading == null ? 0xFFFF : ((heading * 180.0 / Math.PI).toNumber() + 360) % 360);
			me.mAccelPeakField.setData(accelPeak > 0xFFFE ? 0xFFFE : accelPeak);
		}

		// Called from Fd1State.changeMode() at the DIVE->REST edge, before the
		// next startSession()/addLap() call snapshots the lap boundary.
		public function updateDiveMetrics(distance, speed) as Void {
			if (me.mDiveDistanceField != null) {
				me.mDiveDistanceField.setData(distance);
			}
			if (me.mDiveSpeedField != null) {
				me.mDiveSpeedField.setData(speed);
			}
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
					me.mMinHrField.setData(me.mMinHr);   // the session field kept its initial 0 before
				}

				mHRHistory.add(activityInfo.currentHeartRate);
			}

	    	 me.onRefreshHrActivityStats(activityInfo, me.mMinHr);
		}

        
		
        function initialize() {
             me._FitSession = ActivityRecording.createSession(Fd1SessionSpec.createFdSession("Freediving"));
			 me.createMinHrDataField();	
			 me.createDiveMetricFields();
			 me.createSampleFields();
			 me.onBeforeStart(me._FitSession);
			//  me._FitSession.start(); 
		     me._RefreshActivityTimer = new Timer.Timer();		
		     me._RefreshActivityTimer.start(method(:refreshActivityStats), _RefreshActivityInterval, true);
             System.println("Session started:" + me._FitSession);
        }

        function finish() {
			// the 1 s stats timer would otherwise call into the nulled session while the app exits
			me._RefreshActivityTimer.stop();
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