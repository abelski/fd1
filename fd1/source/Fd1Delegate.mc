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

    function onBack() as Boolean{
        var dialog = new WatchUi.Confirmation("Save \n&exit?");
        WatchUi.pushView(dialog, new ConfirmationDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onMenu() as Boolean {
        var menuDelegate = new Fd1MenuDelegate();
        menuDelegate.setvarfd1State(_FdState);
         WatchUi.pushView(new Rez.Menus.MainMenu(), menuDelegate, WatchUi.SLIDE_UP);
        return true;
    }

    function onNextPage() as Boolean {
        _FdState.showPage = _FdState.showPage == 1 ? 2 : 1; // toggle between page 1 and page 2
        return true;
        
    }
    function onPreviousPage() as Boolean {
        _FdState.showPage = _FdState.showPage == 1 ? 2 : 1; // toggle between page 1 and page 2
        return true;
        
    }
}

class ConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            // User pressed Yes - exit or perform action
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            // User pressed No - stay on current view
        }
        return true;
    }
}