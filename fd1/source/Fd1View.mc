import Toybox.Graphics;
import Toybox.Lang;
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
        showDistanceConfirmIfDue(mFdState);   // a dive ended by auto start (surfacing) has no button press
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
    }
    // Draw the values on the main screen Page 1 (main session info)
    function drawPage1Values(dc as Dc,x,y) {
        var margin = dc.getWidth() / 10;

        //white values
        //-------------------------------------
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);

        //time row: clock icon and timer centred together as one group
        var timeRowY = y + 44;
        var clock = Ui.loadResource(Rez.Drawables.Clock);
        var timeText = Fd1Util.formatSecundes(mFdState.holdTime);
        var gap = 6;
        var groupX = (dc.getWidth() - clock.getWidth() - gap - dc.getTextWidthInPixels(timeText, Gfx.FONT_LARGE)) / 2;
        dc.drawBitmap(groupX, timeRowY, clock);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);   //drawBitmap can leave the pen changed
        dc.drawText(groupX + clock.getWidth() + gap, timeRowY, Gfx.FONT_LARGE, timeText, Gfx.TEXT_JUSTIFY_LEFT);

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
    // Page 2 (UP/DOWN): the settings at a glance. The pool length sits in the white
    // subscreen circle like the heart rate on page 1; rows of label/value start below it.
    function drawPage2UI(dc as Dc,x,y) as Void{
        var w = dc.getWidth();
        var margin = w / 10;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.fillCircle(x+57, y-57, 30);
        dc.drawLine(margin, y - 24, w - margin, y - 24);   //under the title
    }
    function drawPage2Values(dc as Dc,x,y) as Void{
        var w = dc.getWidth();
        var margin = w / 10;
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
        var pool = mFdState.poolLength == 0 ? "STA" : mFdState.poolLength + "m";
        dc.drawText(x+57, y-57, Gfx.FONT_SMALL, pool, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.drawText(margin, y - 62, Gfx.FONT_SMALL, "Settings", Gfx.TEXT_JUSTIFY_LEFT);
        var labels = ["Start", "Wait", "Notify"];
        var wait = "co2".equals(mFdState.waitMode) ? "CO2" : mFdState.waitMode;
        var values = [capitalized(mFdState.startMode), wait, capitalized(mFdState.notification_option_label)];
        for (var i = 0; i < 3; i++) {
            var rowMid = y - 10 + i * 24;
            dc.drawText(margin, rowMid, Gfx.FONT_XTINY, labels[i], Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.drawText(w - margin, rowMid, Gfx.FONT_SMALL, values[i], Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
        }
        //auto start: pressure now / baseline
        dc.drawText(x, y + 54, Gfx.FONT_XTINY, mFdState.pressureNow.format("%.1f") + " / " + mFdState.autoStartPressure.format("%.1f") + " kPa", Gfx.TEXT_JUSTIFY_CENTER);
    }

    // "manual" -> "Manual", "off" -> "Off"; "1min", "30sec" stay as they are
    function capitalized(s) as String {
        return s.substring(0, 1).toUpper() + s.substring(1, s.length());
    }


}
