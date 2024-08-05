import Toybox.Lang;
import Toybox.WatchUi;

class Fd1Delegate extends WatchUi.BehaviorDelegate {
    static var mFdState;

    function setvarfd1State(fd1State){
        mFdState = fd1State;
    }
    function initialize() {
        BehaviorDelegate.initialize();
    
    }

    function onSelect()  as Boolean  {
        mFdState.changeMode();
         return true;
    }

    function onMenu() as Boolean {
        // WatchUi.pushView(new Rez.Menus.MainMenu(), new Fd1MenuDelegate(), WatchUi.SLIDE_UP);
        
        return true;
    }
}