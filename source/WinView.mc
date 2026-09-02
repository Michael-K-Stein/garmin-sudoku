using Toybox.Graphics;
using Toybox.WatchUi;

//! The payoff screen.
//!
//! Three stars, and they are not decoration: they are the only place the app
//! says whether the puzzle was solved *well*. Time alone would reward hint
//! spamming, so a clean board is worth more than a fast one.
class WinView extends WatchUi.View {

    hidden var layout;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        layout = new Layout(dc);
    }

    //! Three stars for no mistakes and no hints, two for a blemish or two,
    //! one for anything finished at all. Finishing always earns something -
    //! an Expert board dragged over the line with help is still an Expert
    //! board that got finished.
    hidden function stars(s) {
        var cost = s.mistakes + s.hints * 2;
        if (cost == 0) { return 3; }
        if (cost <= 3) { return 2; }
        return 1;
    }

    function onUpdate(dc) {
        var s = $.gSession;
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        if (s == null) { return; }

        var cx = layout.cx;
        var h = layout.h;
        var earned = stars(s);

        Theme.ring(dc, cx, layout.cy, layout.ringR, 1.0, Theme.DIM, Theme.GOOD);

        Theme.heading(dc, Theme.GOOD, cx, h * 17 / 100, Graphics.FONT_XTINY,
                      Difficulty.name(s.tier) + " SOLVED");

        var r = layout.radius * 9 / 100;
        var gap = r * 5 / 2;
        for (var i = 0; i < 3; i++) {
            Glyphs.star(dc, i < earned ? Theme.GOLD : Theme.DIM,
                        cx + (i - 1) * gap, h * 30 / 100, r, i < earned);
        }

        // The time is the headline, so it gets a numeric face - which is safe
        // here precisely because a clock string is only digits and a colon.
        var clock = Fmt.clock(s.elapsed);
        var f = Theme.fitFont(dc,
            [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
             Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE],
            clock, layout.w * 3 / 4, layout.h / 4);
        Theme.heading(dc, Theme.TEXT, cx, h * 47 / 100, f, clock);

        if (Stats.lastWasBest) {
            Theme.heading(dc, Theme.GOLD, cx, h * 61 / 100, Graphics.FONT_XTINY,
                          "PERSONAL BEST");
        }

        var line = "";
        if (s.mistakes == 0 && s.hints == 0) {
            line = "no mistakes, no hints";
        } else {
            line = s.mistakes.toString() + " wrong, "
                 + s.hints.toString() + " hints";
        }
        Theme.heading(dc, Theme.MUTED, cx, h * 70 / 100, Graphics.FONT_XTINY, line);

        Theme.pill(dc, Theme.SURFACE, layout.barX, layout.barY,
                   layout.barW, layout.barH);
        Theme.heading(dc, Theme.ACCENT, cx, layout.barY + layout.barH / 2,
                      Graphics.FONT_XTINY, "ANOTHER");
    }

    function getLayout() {
        return layout;
    }
}

//! Anything but Back starts the next puzzle at the same difficulty, because
//! that is what a player who just finished one wants. Back returns to the
//! menu, and either way the finished board is dropped from the stack - it
//! cannot be played any further.
class WinDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    hidden function leave() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);      // this screen
        WatchUi.popView(WatchUi.SLIDE_RIGHT);     // the solved board
    }

    function onBack() {
        leave();
        return true;
    }

    function onSelect() {
        again();
        return true;
    }

    function onTap(evt) {
        again();
        return true;
    }

    hidden function again() {
        var s = $.gSession;
        var tier = (s != null) ? s.tier : Difficulty.EASY;
        leave();
        Generation.begin(tier);
    }
}
