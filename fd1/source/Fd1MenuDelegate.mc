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
        if (item == :set_mode) {
             showSelectModeMenu();
            
        }
        if (item == :wait_mode) {
            showSelectWaitModeMenu(); 
        }
        
    }

    function showSelectWaitModeMenu() {
        System.println("Показать меню выбора режима ожидания");
        WatchUi.pushView(new Rez.Menus.WaitModeMenu(), new WaitModeMenuDelegate(_FdState), WatchUi.SLIDE_IMMEDIATE);
    }

    function showSelectModeMenu() {
        System.println("Показать меню выбора режима");
        WatchUi.pushView(new Rez.Menus.StartModeMenu(), new StartModeMenuDelegate(_FdState), WatchUi.SLIDE_IMMEDIATE);
    }

}

class WaitModeMenuDelegate extends WatchUi.MenuInputDelegate {
    var _FdState;

    function initialize(fdState) {
        _FdState = fdState;
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        _FdState.setWaitingMode(item.toString());
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // назад
    }
}

class StartModeMenuDelegate extends WatchUi.MenuInputDelegate {
    var _FdState;

    function initialize(fdState) {
        _FdState = fdState;
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        _FdState.setStartMode(item.toString());
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // назад
    }
}