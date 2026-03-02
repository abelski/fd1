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
        var menu = new WatchUi.Menu();
        menu.setTitle("Wait mode");
        menu.addItem(WatchUi.loadResource(Rez.Strings.wait_mode_x2), :wait_mode_x2);
        menu.addItem(WatchUi.loadResource(Rez.Strings.wait_mode_1min), :wait_mode_1min);
        menu.addItem(WatchUi.loadResource(Rez.Strings.wait_mode_30sec), :wait_mode_30sec);
        menu.addItem(WatchUi.loadResource(Rez.Strings.wait_mode_co2), :wait_mode_co2);

        WatchUi.pushView(menu, new WaitModeMenuDelegate(_FdState), WatchUi.SLIDE_IMMEDIATE);
    }

    function showSelectModeMenu() {
        System.println("Показать меню выбора режима");
        var menu = new WatchUi.Menu();
        menu.setTitle("Mode");
        menu.addItem(WatchUi.loadResource(Rez.Strings.start_mode_auto), :start_mode_auto);
        menu.addItem(WatchUi.loadResource(Rez.Strings.start_mode_manual), :start_mode_manual);

        WatchUi.pushView(menu, new StartModeMenuDelegate(_FdState), WatchUi.SLIDE_IMMEDIATE);
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