using Toybox.Lang;

//! Candidate sets are one Number per cell: bit 0 stands for digit 1, bit 8
//! for digit 9. Every "can this unit still take d?" question is then a single
//! AND, which matters because the generator asks it tens of thousands of
//! times per puzzle.
module Bits {
    const ALL = 0x1FF;

    function of(d) {
        return 1 << (d - 1);
    }

    function count(m) {
        var n = 0;
        while (m != 0) {
            m = m & (m - 1);
            n++;
        }
        return n;
    }

    //! The digit of the lowest set bit, or 0 for the empty set.
    function lowest(m) {
        for (var d = 1; d <= 9; d++) {
            if ((m & (1 << (d - 1))) != 0) { return d; }
        }
        return 0;
    }
}

//! Grid geometry, all of it arithmetic rather than lookup tables. A peer
//! table would be 81x20 Numbers held for the life of the app; recomputing
//! row/column/box indices costs a few divisions and no memory, and the
//! elimination loops below are idempotent so the three units overlapping at
//! the cell itself do no harm.
module Cells {
    const N = 81;
    const UNITS = 27;

    function row(i) { return i / 9; }
    function col(i) { return i % 9; }
    function box(i) { return (i / 27) * 3 + (i % 9) / 3; }

    //! The k-th cell of unit u: 0-8 are rows, 9-17 columns, 18-26 boxes.
    function unitCell(u, k) {
        if (u < 9) { return u * 9 + k; }
        if (u < 18) { return (u - 9) + k * 9; }
        var b = u - 18;
        return (b / 3) * 27 + (b % 3) * 3 + (k / 3) * 9 + (k % 3);
    }

    //! True if a and b share a row, a column or a box.
    function peers(a, b) {
        if (a == b) { return false; }
        return row(a) == row(b) || col(a) == col(b) || box(a) == box(b);
    }

    function blank() as Lang.Array<Lang.Number> {
        var g = new Lang.Array<Lang.Number>[N];
        for (var i = 0; i < N; i++) { g[i] = 0; }
        return g;
    }

    function copy(g as Lang.Array<Lang.Number>) as Lang.Array<Lang.Number> {
        var out = new Lang.Array<Lang.Number>[N];
        for (var i = 0; i < N; i++) { out[i] = g[i]; }
        return out;
    }
}
