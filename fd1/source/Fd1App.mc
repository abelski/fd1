import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Fd1Util;
import Fd1SessionRecorder;


class Fd1App extends Application.AppBase {
  private var _session;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        System.println("finished");
        _session.finish();
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
         _session = new Fd1SessionRecorder.Fd1Activity();

        var fd1State = new Fd1Util.Fd1State(2, _session);
        
        var fd1Viev = new Fd1View();
        fd1Viev.setvarfd1State(fd1State);
        
        var fd1delegate = new Fd1Delegate();
        fd1delegate.setvarfd1State(fd1State);
        fd1delegate.setSession(_session);
        return [fd1Viev , fd1delegate];
    }

}

function getApp() as Fd1App {
    return Application.getApp() as Fd1App;
}