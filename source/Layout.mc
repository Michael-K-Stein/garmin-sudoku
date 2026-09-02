using Toybox.Graphics;
using Toybox.Lang;

//! Where everything on the board screen goes.
//!
//! Two rules drive all of it. First, the screen is a circle - the corners of
//! a 9x9 grid are the furthest points from the centre, so the grid can only
//! be as large as the circle's inscribed square allows, and the action bar
//! below it has to be a pill rather than a rectangle or its corners hang off
//! the glass. Second, the cell size is a whole number of pixels: a grid whose
//! lines land on fractional coordinates shimmers, and 9 cells of 30px look
//! sharper than a 272px board divided nine ways.
//!
//! Every fraction here is mirrored in tools/check_layout.py, which replays
//! the arithmetic at 416px, 390px, 360px and 260px and asserts nothing leaves
//! the circle. Change a number here and run tools/verify.sh.
class Layout {

    var w;
    var h;
    var cx;
    var cy;
    var radius;

    var cell;          // one square, in whole pixels
    var board;         // the grid, cell * 9
    var boardX;
    var boardY;

    var ringR;         // the completion ring, just inside the bezel

    var barX;          // the action bar: one pill split into four zones
    var barY;
    var barW;
    var barH;
    var zoneW;

    static const ZONES = 4;

    function initialize(dc) {
        w = dc.getWidth();
        h = dc.getHeight();
        var size = (w < h) ? w : h;
        cx = w / 2;
        cy = h / 2;
        radius = size / 2;

        cell = size * 13 / 180;
        board = cell * 9;

        // The board sits slightly above centre. The action bar needs more
        // room below than the two status rows need above, and the circle is
        // widest across the middle, so giving the grid the wider half is what
        // lets the cells stay 30px on a Venu 2 instead of 27px.
        var boardCY = size * 191 / 416;
        boardX = cx - board / 2;
        boardY = boardCY - board / 2;

        ringR = radius - size * 6 / 416;

        barH = size * 46 / 416;
        barW = size * 236 / 416;
        barX = cx - barW / 2;
        barY = cy + size * 152 / 416 - barH / 2;
        zoneW = barW / ZONES;
    }

    //! Top-left corner of cell `i`.
    function cellX(i) { return boardX + Cells.col(i) * cell; }
    function cellY(i) { return boardY + Cells.row(i) * cell; }

    //! The cell under a touch, or -1 outside the grid.
    function cellAt(x, y) {
        if (x < boardX || y < boardY) { return -1; }
        var c = (x - boardX) / cell;
        var r = (y - boardY) / cell;
        if (c > 8 || r > 8) { return -1; }
        return r * 9 + c;
    }

    //! Which action-bar zone a touch landed in, or -1. The hit area is taller
    //! than the drawn pill: the bar sits at the bottom of a round screen where
    //! a thumb arrives at an angle, and a press that looks on-target should
    //! not be thrown away for three pixels.
    function zoneAt(x, y) {
        var slack = barH / 2;
        if (y < barY - slack || y > barY + barH + slack) { return -1; }
        if (x < barX || x >= barX + barW) { return -1; }
        var z = (x - barX) / zoneW;
        return (z >= ZONES) ? ZONES - 1 : z;
    }

    function zoneX(z) { return barX + z * zoneW; }

    //! The vertical band above the board, which the two status rows share.
    function headerBottom() { return boardY; }
}
