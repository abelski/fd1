import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Fd1Util;
using Toybox.Graphics as Gfx;

// Shown once after every dive (not in STA): the counted distance, which the diver
// confirms or fixes before resting. E.g. a turn in a 25 m pool shows 50 m but the
// diver swam 35 m: DOWN twice keeps 30 m. UP +10 m, DOWN -10 m, GPS (or BACK) confirms.
function showDistanceConfirmIfDue(state) as Void {
    if (state.distanceToConfirm) {
        state.distanceToConfirm = false;
        WatchUi.pushView(new AdjustDistanceView(state), new AdjustDistanceDelegate(state), WatchUi.SLIDE_UP);
    }
}

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

        // "OK" in the subscreen circle, next to the GPS button that confirms
        dc.fillCircle(x + 57, y - 57, 30);
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
        dc.drawText(x + 57, y - 57, Gfx.FONT_SMALL, "OK", Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
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

    // GPS: confirm; BACK pops the view by default
    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
