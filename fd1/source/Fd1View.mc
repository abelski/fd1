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
        drawUI(dc, x, y);
        drawValues(dc, x, y);
        

        
    }

    function clearValues(dc as Dc) as Void{
        dc.clear();
    }
    function drawUI(dc as Dc,x,y) as Void{
        //heatrate area
        dc.fillCircle(x+57, y-57, 30);
        dc.drawBitmap(x+30,y-60, Ui.loadResource( Rez.Drawables.Heart));

        //mode area
        dc.fillRectangle(0, y-5, 200, 40);
        dc.drawBitmap(10,y-15, Ui.loadResource( Rez.Drawables.DivingMask));
        //dc.drawText(x-30, y, Gfx.FONT_LARGE, "Mode:", Gfx.TEXT_JUSTIFY_CENTER);

        
        //time area
        //dc.drawText(x-20, y + 34, Gfx.FONT_GLANCE, "time: ", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawBitmap(30,y + 44, Ui.loadResource( Rez.Drawables.Clock));
    }
    function drawValues(dc as Dc,x,y) {
        //white values
        //-------------------------------------
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        
        dc.drawText(105, y + 44, Gfx.FONT_LARGE,  Fd1Util.formatSecundes(mFdState.holdTime), Gfx.TEXT_JUSTIFY_CENTER);
        
        dc.drawText(5, y - 30, Gfx.FONT_SMALL,mFdState.startMode+"/"+mFdState.pressureNow.format("%.2f"), Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(5, y - 50, Gfx.FONT_SMALL, mFdState.waitMode, Gfx.TEXT_JUSTIFY_LEFT);

        //clock
        var myTime = System.getClockTime();
        var formatedTime = myTime.hour.format("%02d") + ":" +
                            myTime.min.format("%02d") ;
        dc.drawText(x - 15, y - 90, Gfx.FONT_SMALL, formatedTime, Gfx.TEXT_JUSTIFY_CENTER);
        //session data
        dc.drawText(x - 10, y - 70, Gfx.FONT_SMALL,mFdState.sessionCycle+"/"+Fd1Util.formatSecundes(mFdState.sessionTime), Gfx.TEXT_JUSTIFY_RIGHT);

        //black values
        //-------------------------------------
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
        dc.drawText(x + 60, y - 70 , Gfx.FONT_SYSTEM_MEDIUM, mFdState.heartRate, Gfx.TEXT_JUSTIFY_CENTER);  
        dc.drawText(x+30, y, Gfx.FONT_LARGE, mFdState.mode, Gfx.TEXT_JUSTIFY_CENTER);
    }
    


}
