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
        dc.clear();
        
        // Set the font and justify settings
        var font = Gfx.FONT_LARGE;
        var justify = Gfx.TEXT_JUSTIFY_CENTER;

        // Determine the position on the screen (centered)
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;

        dc.drawText(x, y, font, "Mode:"+mFdState.mode, justify);

        var myTime = System.getClockTime();
        var formatedTime = myTime.hour.format("%02d") + ":" +
                            myTime.min.format("%02d") ;
        dc.drawText(x, y + 30, Gfx.FONT_GLANCE, "time: "+ Fd1Util.formatSecundes(mFdState.holdTime), justify);
        
        mFdState.updateTimer();
        mFdState.updateHeartrate();

        dc.drawText(x - 15, y - 90, Gfx.FONT_SMALL, formatedTime, justify);
        dc.drawText(x - 55, y - 70, Gfx.FONT_SMALL,mFdState.sessionCycle+"/"+Fd1Util.formatSecundes(mFdState.sessionTime), justify);

        dc.drawText(x + 60, y - 80 , Gfx.FONT_SYSTEM_NUMBER_MEDIUM, mFdState.heartRate, justify);  
    }

    


}
