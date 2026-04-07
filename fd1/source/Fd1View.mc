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
        mFdState.updatePressure();  
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

        //heatrate area
        dc.fillCircle(x+57, y-57, 30);
        dc.drawBitmap(x+30,y-60, Ui.loadResource( Rez.Drawables.Heart));

        //mode area
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

        //clock
        var myTime = System.getClockTime();
        var formatedTime = myTime.hour.format("%02d") + ":" +
                            myTime.min.format("%02d") ;
        dc.drawText(margin, y - y * 2 / 4, Gfx.FONT_SMALL, formatedTime, Gfx.TEXT_JUSTIFY_LEFT);
        //session data
        dc.drawText(margin, y - y * 3 / 4, Gfx.FONT_SMALL, mFdState.sessionCycle+"/"+Fd1Util.formatSecundes(mFdState.sessionTime), Gfx.TEXT_JUSTIFY_LEFT);

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
        dc.drawText(margin, y - 30, Gfx.FONT_SMALL, "Start:" + mFdState.startMode, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(margin, y - 50, Gfx.FONT_SMALL, "Wait:" + mFdState.waitMode, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(margin, y - 70, Gfx.FONT_SMALL, "Notify:" + mFdState.notification_option_label, Gfx.TEXT_JUSTIFY_LEFT);
    }


}
