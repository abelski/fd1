import Toybox.Graphics;
import Toybox.WatchUi;
import Fd1Util;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Timer;


class Fd1View extends WatchUi.View {
    static var mFdState;

    function initialize(){
        View.initialize();
    }

    function setvarfd1State(fd1State){
        mFdState = fd1State;
    }
    function timerCallback() as Void{
         Ui.requestUpdate();
    }


    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));

        var myTimer = new Timer.Timer();
        myTimer.start(method(:timerCallback), 1000, true);
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
        mFdState.updateTimer();
        mFdState.updateHeartrate();
        
        
        // Determine the position on the screen (centered)
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;
        drawUI(dc, x, y);
        drawValues(dc, x, y);
        

        
    }

    function clearValues(dc as Dc) as Void{
        dc.clear();
    }
    function drawUI(dc as Dc,x,y) as Void{
        dc.drawText(x-30, y, Gfx.FONT_LARGE, "Mode:", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(x-20, y + 30, Gfx.FONT_GLANCE, "time: ", Gfx.TEXT_JUSTIFY_CENTER);
    }
    function drawValues(dc as Dc,x,y) {
        dc.drawText(x+30, y, Gfx.FONT_LARGE, mFdState.mode, Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(x+20, y + 30, Gfx.FONT_GLANCE,  Fd1Util.formatSecundes(mFdState.holdTime), Gfx.TEXT_JUSTIFY_CENTER);
        

        var myTime = System.getClockTime();
        var formatedTime = myTime.hour.format("%02d") + ":" +
                            myTime.min.format("%02d") ;
        dc.drawText(x - 15, y - 90, Gfx.FONT_SMALL, formatedTime, Gfx.TEXT_JUSTIFY_CENTER);
        
        dc.drawText(x - 55, y - 70, Gfx.FONT_SMALL,mFdState.sessionCycle+"/"+Fd1Util.formatSecundes(mFdState.sessionTime), Gfx.TEXT_JUSTIFY_CENTER);

        dc.drawText(x + 60, y - 80 , Gfx.FONT_SYSTEM_NUMBER_MEDIUM, mFdState.heartRate, Gfx.TEXT_JUSTIFY_CENTER);  
    }
    


}
