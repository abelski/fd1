import Toybox.Graphics;
import Toybox.WatchUi;
import Fd1Util;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Timer;


class Fd1View extends WatchUi.View {
    static var mFdState;
    private var _uiTimer;
    private var _pressureTimer;

    function initialize(){
        View.initialize();
    }

    function setvarfd1State(fd1State){
        mFdState = fd1State;
    }

    // The dive/rest clock ticks here, not in onUpdate: onUpdate stops while a menu
    // covers this view (the clock froze) and runs extra on redraws (extra ticks).
    function timerCallback() as Void {
        mFdState.updateTimer();
        Ui.requestUpdate();
    }

    function pressureCallback() as Void {
        mFdState.updatePressure();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));

        // one set of timers even if onLayout runs again: a second clock timer would double-tick
        if (_uiTimer == null) {
            _uiTimer = new Timer.Timer();
            _uiTimer.start(method(:timerCallback), 1000, true);

            _pressureTimer = new Timer.Timer();
            _pressureTimer.start(method(:pressureCallback), 1000, true);
        }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {  
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        clearValues(dc);
        mFdState.updateHeartrate();
        // Determine the position on the screen (centered)
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;
        if(mFdState.showPage == 1){
            drawPage1UI(dc, x, y);
            drawPage1Values(dc, x, y);
        }else{
            drawPage2UI(dc, x, y);
            drawPage2Values(dc, x, y);
        }   
    }

    function clearValues(dc as Dc) as Void{
        dc.clear();
    }

    // Draw the UI elements on the main screen Page 1 (main session info)
    function drawPage1UI(dc as Dc,x,y) as Void{
        if (mFdState.showPage == 1){}
        var margin = dc.getWidth() / 10;

        //fills below must not inherit whatever color the previous frame left
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);

        //heatrate area
        dc.fillCircle(x+57, y-57, 30);
        dc.drawBitmap(x+30,y-60, Ui.loadResource( Rez.Drawables.Heart));

        //mode area (re-assert color: drawBitmap can leave the pen in a
        //different state on some devices/simulator versions)
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.fillRectangle(0, y-10, dc.getWidth(), 51);
        dc.drawBitmap(margin, y-15 , Ui.loadResource( Rez.Drawables.DivingMask));

        //time area
        var timeRowY = y + 44;
        dc.drawBitmap(margin, timeRowY, Ui.loadResource( Rez.Drawables.Clock));
    }
    // Draw the values on the main screen Page 1 (main session info)
    function drawPage1Values(dc as Dc,x,y) {
        var margin = dc.getWidth() / 10;

        //white values
        //-------------------------------------
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);

        var timeRowY = y + 44;
        dc.drawText(x - margin / 2, timeRowY, Gfx.FONT_LARGE, Fd1Util.formatSecundes(mFdState.holdTime), Gfx.TEXT_JUSTIFY_CENTER);

        //top-left info column: three XTINY rows stacked upward from the mask
        //bitmap (drawn at y-15), so row bottoms can never reach the mode band.
        //FONT_SMALL rows don't fit: on instinct2s the column is only 43px tall.
        var rowH = dc.getFontHeight(Gfx.FONT_XTINY);
        var metricsY = (y - 15) - rowH;
        var clockY = metricsY - rowH;
        var sessionY = clockY - rowH;

        //clock
        var myTime = System.getClockTime();
        var formatedTime = myTime.hour.format("%02d") + ":" +
                            myTime.min.format("%02d") ;
        dc.drawText(margin, clockY, Gfx.FONT_XTINY, formatedTime, Gfx.TEXT_JUSTIFY_LEFT);
        //on instinct2x (176x176) the column follows the round edge: the top row
        //would lose its first digit in the cut top-left corner, while the bottom
        //row needs the left room so "300m* 1.2m/s" ends before the subscreen.
        //instinct2s (163x156) fits both at the plain margin.
        //shortcut: square screen = instinct2x, offsets tuned by eye there only; use per-device resources if more square targets are checked.
        var square = dc.getWidth() == dc.getHeight();
        var sessionX = square ? margin + margin / 2 : margin;
        var metricsX = square ? margin / 2 : margin;
        //session data
        dc.drawText(sessionX, sessionY, Gfx.FONT_XTINY, mFdState.sessionCycle+"/"+Fd1Util.formatSecundes(mFdState.sessionTime), Gfx.TEXT_JUSTIFY_LEFT);

        //dive distance/speed; no length count: "12L 300m* 1.2m/s" runs under the subscreen on both Instincts
        var overrideMark = mFdState.manualOverrideActive ? "*" : "";
        var metrics = mFdState.poolLength == 0 ? "STA" : Fd1Util.formatDistance(mFdState.currentDistance) + overrideMark + " " + Fd1Util.formatSpeed(mFdState.currentSpeed);
        dc.drawText(metricsX, metricsY, Gfx.FONT_XTINY, metrics, Gfx.TEXT_JUSTIFY_LEFT);

        //black values
        //-------------------------------------
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
        dc.drawText(x + 60, y - 70, Gfx.FONT_SYSTEM_MEDIUM, mFdState.heartRate, Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(x + 30, y, Gfx.FONT_LARGE, mFdState.mode, Gfx.TEXT_JUSTIFY_CENTER);
    }
    // Draw the UI elements on the main screen Page 2 (pressure info)
    function drawPage2UI(dc as Dc,x,y) as Void{
        
    }
    // Draw the values on the main screen Page 2 (pressure info)
    function drawPage2Values(dc as Dc,x,y) as Void{
        var margin = dc.getWidth() / 10;
        //instinct2x (176x176): rows from y-70 ran under the subscreen ("Start:manu"), so start below it
        //shortcut: square screen = instinct2x, tuned by eye there; use per-device resources if more square targets are checked.
        var top = dc.getWidth() == dc.getHeight() ? y - 26 : y - 70;
        dc.drawText(margin, top, Gfx.FONT_SMALL, "Start:" + mFdState.startMode, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(margin, top + 20, Gfx.FONT_SMALL, "Wait:" + mFdState.waitMode, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(margin, top + 40, Gfx.FONT_SMALL, "Notify:" + mFdState.notification_option_label, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(margin, top + 60, Gfx.FONT_SMALL, "P:" + mFdState.pressureNow.format("%.1f") + " Base:" + mFdState.autoStartPressure.format("%.1f"), Gfx.TEXT_JUSTIFY_LEFT);
    }


}
