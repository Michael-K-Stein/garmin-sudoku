using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

//! The board.
//!
//! Everything the player needs to know is on this one screen, and the round
//! glass has room for exactly three bands: a two-row header, the grid, and a
//! four-zone action bar. Anything that does not earn a place in those bands
//! lives behind the menu button.
//!
//! Colour carries state here, so the rules are worth stating once:
//!   background  which squares relate to the selection
//!   ink         white for a given, blue for an entry, red for a mistake
//!   dots        pencil marks, positioned by digit (see drawNotes)
class BoardView extends WatchUi.View {

    static const FRAME_MS = 200;
    static const FLASH_FRAMES = 5;      // ~1s of highlight after a hint

    hidden var layout;
    hidden var timer;
    hidden var digitFont;
    hidden var noteFont;
    hidden var labelFont;
    hidden var clockFont;
    hidden var conflicts as Lang.Array<Lang.Boolean>?;

    hidden var flashCell = -1;
    hidden var flashLife = 0;
    hidden var message = null;          // one line of hint explanation
    hidden var messageLife = 0;

    function initialize() {
        View.initialize();
        conflicts = null;
    }

    function onLayout(dc) {
        layout = new Layout(dc);

        // FONT_NUMBER_* faces carry digits and almost nothing else, which
        // makes them a trap for any string with a letter in it - and exactly
        // the right choice here, where every cell is one digit.
        digitFont = Theme.fitFont(dc,
            [Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL,
             Graphics.FONT_TINY, Graphics.FONT_XTINY],
            "8", layout.cell - 2, layout.cell - 2);

        noteFont = Graphics.FONT_XTINY;
        labelFont = Graphics.FONT_XTINY;

        var band = layout.headerBottom();
        clockFont = Theme.fitFont(dc,
            [Graphics.FONT_TINY, Graphics.FONT_XTINY],
            "1:04:37", layout.w / 2, band - dc.getFontHeight(labelFont) - 2);
    }

    function onShow() {
        var s = $.gSession;
        if (s != null) { s.resumeClock(); }
        refresh();
        if (timer == null) {
            timer = new Timer.Timer();
            timer.start(method(:onFrame), FRAME_MS, true);
        }
    }

    function onHide() {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
        var s = $.gSession;
        if (s != null) {
            s.pauseClock();
            s.save();
        }
    }

    function onFrame() as Void {
        var s = $.gSession;
        if (s == null) { return; }
        var dirty = s.tickClock();
        if (flashLife > 0) {
            flashLife--;
            if (flashLife == 0) { flashCell = -1; }
            dirty = true;
        }
        if (messageLife > 0) {
            messageLife--;
            if (messageLife == 0) { message = null; }
            dirty = true;
        }
        if (dirty) { WatchUi.requestUpdate(); }
    }

    //! Recompute what the board says about itself. Called by the delegate
    //! after every move rather than every frame - the clash scan walks all 27
    //! units, which is cheap once per tap and wasteful five times a second.
    function refresh() {
        var s = $.gSession;
        if (s != null && s.entries != null) {
            conflicts = Logic.conflicts(s.entries);
        }
        WatchUi.requestUpdate();
    }

    function highlight(cell, note) {
        flashCell = cell;
        flashLife = FLASH_FRAMES;
        message = note;
        messageLife = FLASH_FRAMES * 2;
        WatchUi.requestUpdate();
    }

    function getLayout() {
        return layout;
    }

    // --- drawing ---------------------------------------------------------

    function onUpdate(dc) {
        var s = $.gSession;
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        if (s == null || s.entries == null) { return; }
        if (conflicts == null) { conflicts = Logic.conflicts(s.entries); }

        drawRing(dc, s);
        drawHeader(dc, s);
        drawCells(dc, s);
        drawGrid(dc);
        drawBar(dc, s);
        if (message != null) { drawMessage(dc); }
    }

    hidden function drawRing(dc as Graphics.Dc, s as Session) as Void {
        var filled = s.filledCount();
        Theme.ring(dc, layout.cx, layout.cy, layout.ringR,
                   filled.toDouble() / Cells.N, Theme.DIM, Theme.ACCENT);
    }

    hidden function drawHeader(dc as Graphics.Dc, s as Session) as Void {
        var band = layout.headerBottom();
        var labelH = dc.getFontHeight(labelFont);
        var clockH = Prefs.showTimer ? dc.getFontHeight(clockFont) : 0;
        var top = (band - labelH - clockH) / 2;
        var labelY = top + labelH / 2;

        Theme.heading(dc, Theme.MUTED, layout.cx, labelY, labelFont,
                      Difficulty.name(s.tier));

        // The two counters flank the label, pinned to the chord at their own
        // height so they never drift off a small round screen.
        var half = Theme.chordHalfWidth(layout.radius - 4, labelY - layout.cy);
        var left = Cells.N - s.filledCount();
        Theme.text(dc, Theme.MUTED, layout.cx - half + 2, labelY, labelFont,
                   left.toString(),
                   Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (s.mistakes > 0) {
            Theme.text(dc, Theme.BAD, layout.cx + half - 2, labelY, labelFont,
                       s.mistakes.toString(),
                       Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (Prefs.showTimer) {
            Theme.heading(dc, Theme.TEXT, layout.cx, top + labelH + clockH / 2,
                          clockFont, Fmt.clock(s.elapsed));
        }
    }

    hidden function drawCells(dc as Graphics.Dc, s as Session) as Void {
        var entries = s.entries;
        var notes = s.notes;
        var solution = s.solution;
        var bad = conflicts;
        if (entries == null || notes == null || solution == null || bad == null) {
            return;
        }

        var sel = s.selected;
        var selDigit = (sel >= 0) ? entries[sel] : 0;

        for (var i = 0; i < Cells.N; i++) {
            var x = layout.cellX(i);
            var y = layout.cellY(i);
            var fill = Theme.SURFACE;

            if (Prefs.highlightPeers && sel >= 0) {
                if (selDigit != 0 && entries[i] == selDigit) { fill = Theme.SAME_FILL; }
                else if (Cells.peers(i, sel)) { fill = Theme.PEER_FILL; }
            }
            if (i == flashCell && flashLife > 0) { fill = Theme.HINT_FILL; }
            if (i == sel) { fill = Theme.SEL_FILL; }

            Theme.fill(dc, fill, x, y, layout.cell, layout.cell);

            var v = entries[i];
            if (v != 0) {
                var colour = Theme.ENTRY;
                if (s.isGiven(i)) {
                    colour = Theme.GIVEN;
                } else if (bad[i]
                           || (Prefs.showMistakes && v != solution[i])) {
                    colour = Theme.BAD;
                }
                Theme.text(dc, colour, x + layout.cell / 2, y + layout.cell / 2,
                           digitFont, v.toString(),
                           Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else if (notes[i] != 0) {
                drawNotes(dc, notes[i], x, y);
            }
        }
    }

    //! Pencil marks as a 3x3 lattice of dots, where the dot's position *is*
    //! the digit - top-left is 1, bottom-right is 9.
    //!
    //! Nine digits will not fit legibly in a 30px cell: the smallest font on
    //! a Venu 2 is 21px tall, so a 3x3 block of them would need 63px. Dots
    //! read at a glance, and after one puzzle the positions are as fast to
    //! scan as numerals would have been.
    hidden function drawNotes(dc, mask, x, y) {
        var step = layout.cell / 3;
        var r = step / 5;
        if (r < 1) { r = 1; }
        dc.setColor(Theme.NOTE, Graphics.COLOR_TRANSPARENT);
        for (var d = 1; d <= 9; d++) {
            if ((mask & Bits.of(d)) == 0) { continue; }
            var k = d - 1;
            dc.fillCircle(x + (k % 3) * step + step / 2,
                          y + (k / 3) * step + step / 2, r);
        }
    }

    hidden function drawGrid(dc) {
        var x0 = layout.boardX;
        var y0 = layout.boardY;
        var side = layout.board;

        dc.setColor(Theme.GRID_MINOR, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var k = 1; k < 9; k++) {
            if (k % 3 == 0) { continue; }
            var o = k * layout.cell;
            dc.drawLine(x0 + o, y0, x0 + o, y0 + side);
            dc.drawLine(x0, y0 + o, x0 + side, y0 + o);
        }

        // Box separators are the structure of the puzzle, so they get real
        // weight - without them a 9x9 grid reads as 81 unrelated squares.
        dc.setColor(Theme.GRID_MAJOR, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(layout.cell >= 26 ? 3 : 2);
        for (var k = 3; k < 9; k += 3) {
            var o = k * layout.cell;
            dc.drawLine(x0 + o, y0, x0 + o, y0 + side);
            dc.drawLine(x0, y0 + o, x0 + side, y0 + o);
        }
        dc.drawRectangle(x0, y0, side + 1, side + 1);
        dc.setPenWidth(1);
    }

    hidden function drawBar(dc as Graphics.Dc, s as Session) as Void {
        Theme.pill(dc, Theme.SURFACE, layout.barX, layout.barY,
                   layout.barW, layout.barH);

        var cy = layout.barY + layout.barH / 2;
        var r = layout.barH * 3 / 10;

        // Notes mode is a mode, so it gets a lit background rather than just
        // a brighter icon - a colour change alone is too easy to miss and too
        // easy to misread outdoors.
        if (s.noteMode) {
            Theme.pill(dc, Theme.SEL_FILL, layout.zoneX(0) + 2, layout.barY + 2,
                       layout.zoneW - 4, layout.barH - 4);
        }

        Glyphs.pencil(dc, s.noteMode ? Theme.GIVEN : Theme.TEXT,
                      layout.zoneX(0) + layout.zoneW / 2, cy, r);
        Glyphs.eraser(dc, canEdit(s) ? Theme.TEXT : Theme.DIM,
                      layout.zoneX(1) + layout.zoneW / 2, cy, r);
        Glyphs.undo(dc, s.canUndo() ? Theme.TEXT : Theme.DIM,
                    layout.zoneX(2) + layout.zoneW / 2, cy, r);
        Glyphs.bulb(dc, Theme.GOLD, layout.zoneX(3) + layout.zoneW / 2, cy, r);

        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        for (var z = 1; z < Layout.ZONES; z++) {
            var x = layout.zoneX(z);
            dc.drawLine(x, layout.barY + layout.barH / 4,
                        x, layout.barY + layout.barH * 3 / 4);
        }
    }

    hidden function canEdit(s as Session) as Lang.Boolean {
        return s.selected >= 0 && !s.isGiven(s.selected);
    }

    //! A hint's explanation, over the top of the grid where the eye already
    //! is. It replaces nothing permanently - it fades on its own.
    hidden function drawMessage(dc) {
        var h = dc.getFontHeight(labelFont) + 8;
        var y = layout.boardY + layout.board / 2 - h / 2;
        var half = Theme.chordHalfWidth(layout.radius - 4, y + h / 2 - layout.cy);
        var w = dc.getTextWidthInPixels(message, labelFont) + 16;
        if (w > half * 2) { w = half * 2; }
        Theme.pill(dc, Theme.BG, layout.cx - w / 2, y, w, h);
        dc.setColor(Theme.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(layout.cx - w / 2, y, w, h, h / 2);
        Theme.heading(dc, Theme.GOLD, layout.cx, y + h / 2, labelFont, message);
    }
}
