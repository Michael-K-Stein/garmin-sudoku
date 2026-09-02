using Toybox.Graphics;
using Toybox.Math;

//! The action-bar icons, drawn as vectors rather than shipped as bitmaps.
//!
//! Four devices with three screen sizes would otherwise need three sets of
//! PNGs each, and every one of them would be a slightly wrong size on some
//! watch. These take a centre and a radius and look right at 36px and at
//! 18px, which is the whole argument.
//!
//! Each glyph is drawn inside a box of side 2*r centred on (cx, cy). Keep new
//! ones to that contract or the action bar's spacing stops meaning anything.
module Glyphs {

    //! A pencil on the diagonal: barrel, tip, and a nib to sell the point.
    function pencil(dc, colour, cx, cy, r) {
        var s = r * 100 / 100;
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var x0 = cx - s;
        var y0 = cy + s;
        var x1 = cx + s * 6 / 10;
        var y1 = cy - s * 6 / 10;
        var wide = s * 4 / 10;
        if (wide < 2) { wide = 2; }

        // The barrel, as a quad along the diagonal.
        dc.fillPolygon([
            [x0 + wide, y0],
            [x1 + wide, y1],
            [x1, y1 - wide],
            [x0, y0 - wide]
        ]);
        // The tip.
        dc.fillPolygon([
            [x1, y1 - wide],
            [x1 + wide, y1],
            [cx + s, cy - s]
        ]);
        // The line it is writing on.
        dc.setPenWidth(2);
        dc.drawLine(cx - s, cy + s, cx + s * 3 / 10, cy + s);
        dc.setPenWidth(1);
    }

    //! A backspace arrow: the usual pentagon with a cross knocked out.
    function eraser(dc, colour, cx, cy, r) {
        var s = r;
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx - s, cy],
            [cx - s * 3 / 10, cy - s * 7 / 10],
            [cx + s, cy - s * 7 / 10],
            [cx + s, cy + s * 7 / 10],
            [cx - s * 3 / 10, cy + s * 7 / 10]
        ]);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var k = s * 3 / 10;
        dc.drawLine(cx + s * 1 / 10 - k, cy - k, cx + s * 1 / 10 + k, cy + k);
        dc.drawLine(cx + s * 1 / 10 - k, cy + k, cx + s * 1 / 10 + k, cy - k);
        dc.setPenWidth(1);
    }

    //! An arrow curling anticlockwise back on itself.
    function undo(dc, colour, cx, cy, r) {
        var s = r;
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        // Three quarters of a circle, open at the top left.
        dc.drawArc(cx, cy + s / 5, s * 7 / 10, Graphics.ARC_CLOCKWISE, 160, 340);
        dc.setPenWidth(1);
        // The head, at the open end.
        var hx = cx - s * 7 / 10;
        var hy = cy + s / 5;
        var k = s * 4 / 10;
        dc.fillPolygon([
            [hx, hy - k],
            [hx - k * 8 / 10, hy + k / 5],
            [hx + k * 8 / 10, hy + k / 5]
        ]);
    }

    //! A lightbulb: glass, filament and a base.
    function bulb(dc, colour, cx, cy, r) {
        var s = r;
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var glass = s * 6 / 10;
        dc.fillCircle(cx, cy - s * 2 / 10, glass);
        // The neck, joining glass to base.
        dc.fillRectangle(cx - glass * 5 / 10, cy - s * 2 / 10,
                         glass, s * 6 / 10);
        // Two contact rings.
        var bw = glass * 9 / 10;
        dc.fillRectangle(cx - bw / 2, cy + s * 4 / 10, bw, s * 2 / 10);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - bw / 2, cy + s * 5 / 10, cx + bw / 2, cy + s * 5 / 10);
    }

    //! A tick, for the "solved" badge.
    function tick(dc, colour, cx, cy, r) {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(r * 3 / 10 < 3 ? 3 : r * 3 / 10);
        dc.drawLine(cx - r * 7 / 10, cy, cx - r / 10, cy + r * 6 / 10);
        dc.drawLine(cx - r / 10, cy + r * 6 / 10, cx + r * 7 / 10, cy - r * 6 / 10);
        dc.setPenWidth(1);
    }

    //! A five-pointed star, filled or hollow - the win screen's rating.
    function star(dc, colour, cx, cy, r, filled) {
        var pts = new [10];
        for (var i = 0; i < 10; i++) {
            var rad = (i % 2 == 0) ? r : r * 42 / 100;
            // -90 degrees puts the first point straight up.
            var a = (i * 36 - 90) * Math.PI / 180.0;
            pts[i] = [cx + (rad * Math.cos(a)).toNumber(),
                      cy + (rad * Math.sin(a)).toNumber()];
        }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        if (filled) {
            dc.fillPolygon(pts);
        } else {
            dc.setPenWidth(2);
            for (var i = 0; i < 10; i++) {
                var j = (i + 1) % 10;
                dc.drawLine(pts[i][0], pts[i][1], pts[j][0], pts[j][1]);
            }
            dc.setPenWidth(1);
        }
    }
}
