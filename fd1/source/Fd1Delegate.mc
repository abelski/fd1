import Toybox.Lang;
import Toybox.WatchUi;

class Fd1Delegate extends WatchUi.BehaviorDelegate {
    static var _FdState;
    static var _session;

    function setvarfd1State(fd1State){
        _FdState = fd1State;
    }

    function setSession(session){
        _session = session;
    }
    function initialize() {
        BehaviorDelegate.initialize();
    
    }

    function onSelect()  as Boolean  {
        
        _FdState.changeMode(_session);
        _FdState.informNotice();
         return true;
    }

    function onMenu() as Boolean {
        var menuDelegate = new Fd1MenuDelegate();
        menuDelegate.setvarfd1State(_FdState);
         WatchUi.pushView(new Rez.Menus.MainMenu(), menuDelegate, WatchUi.SLIDE_UP);
        return true;
    }
}