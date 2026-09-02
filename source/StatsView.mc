using Toybox.Graphics;
using Toybox.WatchUi;

//! The lifetime record: one row per difficulty.
//!
//! Rows are laid out from the measured font height, and each row's two
//! columns are pinned to the chord of the circle at that row's own height -
//! so the top and bottom rows tuck in as the glass narrows instead of running
//! off the edge.
class StatsView extends WatchUi.View {

    hidden var layout;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        layout = new Layout(dc);
    }

    function onUpdate(dc) {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        var font = Graphics.FONT_XTINY;
        var lineH = dc.getFontHeight(font);
        var rowH = lineH + lineH / 4;
        var titleH = lineH + lineH / 2;

        var block = titleH + rowH * Difficulty.COUNT;
        var top = layout.cy - block / 2;

        Theme.heading(dc, Theme.MUTED, layout.cx, top + titleH / 2, font, "RECORD");

        var any = false;
        for (var t = 0; t < Difficulty.COUNT; t++) {
            var a = Stats.forTier(t);
            var y = top + titleH + rowH * t + rowH / 2;
            var half = Theme.chordHalfWidth(layout.radius - 5, y - layout.cy);

            var won = a[Stats.WON];
            if (won > 0) { any = true; }

            Theme.text(dc, won > 0 ? Theme.TEXT : Theme.DIM,
                       layout.cx - half, y, font, Difficulty.name(t),
                       Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            var right = (won > 0)
                ? (won.toString() + "  " + Fmt.clock(a[Stats.BEST]))
                : "-";
            Theme.text(dc, won > 0 ? Theme.ACCENT : Theme.DIM,
                       layout.cx + half, y, font, right,
                       Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var footY = top + titleH + rowH * Difficulty.COUNT + lineH;
        if (!any) {
            Theme.heading(dc, Theme.MUTED, layout.cx, footY, font,
                          "no puzzles solved yet");
            return;
        }

        var streak = 0;
        for (var t = 0; t < Difficulty.COUNT; t++) {
            var a = Stats.forTier(t);
            if (a[Stats.BEST_STREAK] > streak) { streak = a[Stats.BEST_STREAK]; }
        }
        if (streak > 0) {
            Theme.heading(dc, Theme.GOLD, layout.cx, footY, font,
                          "best streak " + streak.toString());
        }
    }
}
