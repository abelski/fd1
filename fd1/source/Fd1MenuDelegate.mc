import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class Fd1MenuDelegate extends WatchUi.MenuInputDelegate {
    static var _FdState;
    
    function setvarfd1State(fd1State){
        _FdState = fd1State;

    }
    
    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :set_surface) {
            System.println("set_surface 1");
            _FdState.setsurface();
        } else if (item == :set_deep) {
            System.println("set_deep 2");
            _FdState.setdeep();
        }
    }

}