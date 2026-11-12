import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Fd1Util;
using Toybox.Graphics as Gfx;

// Distance fix after surfacing: UP adds 10 m, DOWN takes 10 m off, GPS or BACK
// returns. E.g. a turn in a 25 m pool shows 50 m but the diver swam 35 m:
// DOWN twice saves 30 m as the result. The screen stays open between presses.
class AdjustDistanceView extends WatchUi.View {
    private var _state;

    function initialize(state) {
        View.initialize();
        _state = state;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
        dc.clear();
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;
        var margin = dc.getWidth() / 10;
        dc.drawText(margin, y - 50, Gfx.FONT_XTINY, "Distance", Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x, y - 20, Gfx.FONT_LARGE, Fd1Util.formatDistance(_state.currentDistance), Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(x, y + 30, Gfx.FONT_XTINY, "UP +10  DOWN -10", Gfx.TEXT_JUSTIFY_CENTER);
    }
}

class AdjustDistanceDelegate extends WatchUi.BehaviorDelegate {
    private var _state;

    function initialize(state) {
        BehaviorDelegate.initialize();
        _state = state;
    }

    // UP
    function onPreviousPage() as Boolean {
        _state.adjustDistance(10);
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN
    function onNextPage() as Boolean {
        _state.adjustDistance(-10);
        WatchUi.requestUpdate();
        return true;
    }

    // GPS: done; BACK pops the view by default
    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
