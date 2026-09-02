using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

//! Palette and the drawing primitives shared by every screen.
//!
//! The palette is built for a transflective watch display in daylight, where
//! contrast survives and subtlety does not. Backgrounds carry state (which
//! cells relate to the selection); ink carries meaning (given, entered,
//! wrong). Nothing depends on hue alone, so the board still reads with the
//! backlight off.
module Theme {

    const BG          = 0x000000;
    const SURFACE     = 0x111111;   // the board's own ground
    const GRID_MINOR  = 0x3B3B3B;   // cell separators
    const GRID_MAJOR  = 0x8A8A8A;   // box separators and the outer frame

    const PEER_FILL   = 0x1C1C1C;   // shares a row, column or box with the selection
    const SAME_FILL   = 0x00304D;   // holds the same digit as the selection
    const SEL_FILL    = 0x0067A8;   // the selection itself
    const HINT_FILL   = 0x4A3A00;   // the square a hint is pointing at

    const GIVEN       = 0xFFFFFF;   // clues; never editable
    const ENTRY       = 0x55CCFF;   // what the player typed
    const BAD         = 0xFF5555;   // clashes with a peer, or contradicts the solution
    const NOTE        = 0x00AAAA;   // pencil marks

    const ACCENT      = 0x00AAFF;
    const GOLD        = 0xFFAA00;
    const GOOD        = 0x00FF55;
    const TEXT        = 0xDDDDDD;
    const MUTED       = 0x666666;
    const DIM         = 0x333333;

    //! Half the width of the display at `dy` pixels above or below its
    //! centre. The screen is a circle: a row near the rim has far less usable
    //! width than one across the middle, and guessing at that is how text
    //! ends up clipped on the small Venu but not the large one.
    function chordHalfWidth(radius, dy) {
        var d = (dy < 0) ? -dy : dy;
        if (d >= radius) { return 0; }
        return Math.sqrt((radius * radius - d * d).toDouble()).toNumber();
    }

    //! The largest of `fonts` whose line height fits `maxHeight` and whose
    //! `sample` fits `maxWidth`. Row heights come from the device, never from
    //! a guessed constant - the same layout has to serve a 416px Venu 2 and a
    //! 260px Venu Sq 2.
    function fitFont(dc as Graphics.Dc, fonts as Lang.Array<Graphics.FontDefinition>,
                     sample as Lang.String, maxWidth as Lang.Number,
                     maxHeight as Lang.Number) as Graphics.FontDefinition {
        for (var i = 0; i < fonts.size(); i++) {
            var f = fonts[i];
            if (dc.getFontHeight(f) <= maxHeight
                && dc.getTextWidthInPixels(sample, f) <= maxWidth) {
                return f;
            }
        }
        return fonts[fonts.size() - 1];
    }

    function fill(dc, colour, x, y, w, h) {
        dc.setColor(colour, colour);
        dc.fillRectangle(x, y, w, h);
    }

    function pill(dc, colour, x, y, w, h) {
        dc.setColor(colour, colour);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
    }

    function text(dc, colour, x, y, font, s, justify) {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, justify);
    }

    //! A centred label in small caps spacing - used for the difficulty name
    //! and the section headings, where the word is the decoration.
    function heading(dc, colour, cx, y, font, s) {
        text(dc, colour, cx, y, font, s,
             Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The progress ring that hugs the bezel. `fraction` is 0.0-1.0 and the
    //! arc grows clockwise from twelve o'clock, so a nearly-finished board is
    //! legible from the corner of an eye without reading anything.
    function ring(dc, cx, cy, radius, fraction, trackColour, fillColour) {
        dc.setPenWidth(4);
        dc.setColor(trackColour, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);
        if (fraction <= 0.0) {
            dc.setPenWidth(1);
            return;
        }
        var sweep = (fraction >= 1.0) ? 360 : (fraction * 360.0).toNumber();
        dc.setColor(fillColour, Graphics.COLOR_TRANSPARENT);
        if (sweep >= 360) {
            dc.drawCircle(cx, cy, radius);
        } else {
            // drawArc counts degrees from three o'clock; the ring is wanted
            // clockwise from twelve, and the end angle has to be wrapped
            // back into 0-360 or the arc comes out empty.
            var end = 90 - sweep;
            if (end < 0) { end += 360; }
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, end);
        }
        dc.setPenWidth(1);
    }
}
