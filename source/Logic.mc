using Toybox.Lang;

//! Human solving logic: candidate bookkeeping, the two "singles" techniques,
//! and the hint that explains itself.
//!
//! Only the singles are implemented on the watch, and that is deliberate.
//! The generator's whole difficulty question is "can this be finished by
//! scanning alone?" - everything above that line is one bucket as far as the
//! tier table is concerned. The stronger techniques that prove a Hard puzzle
//! really is hard live in tools/sudoku_ref.py, where they run on a desktop
//! during `tools/verify.sh` instead of on a wrist.
module Logic {

    // What kind of step a hint found. The board view turns these into a
    // sentence, so a hint teaches instead of just filling a square.
    const HINT_NONE = 0;
    const HINT_WRONG = 1;     // an entry that contradicts the solution
    const HINT_NAKED = 2;     // this cell can only be one digit
    const HINT_HIDDEN = 3;    // this digit fits nowhere else in the unit
    const HINT_REVEAL = 4;    // nothing simple left; just show the digit

    //! Candidate masks for `grid`, or null if the grid contradicts itself.
    //! Filled cells get a mask of 0.
    function candidates(grid as Lang.Array<Lang.Number>) as Lang.Array<Lang.Number>? {
        var cand = new Lang.Array<Lang.Number>[Cells.N];
        for (var i = 0; i < Cells.N; i++) {
            cand[i] = (grid[i] == 0) ? Bits.ALL : 0;
        }
        for (var i = 0; i < Cells.N; i++) {
            var v = grid[i];
            if (v == 0) { continue; }
            var b = ~Bits.of(v);
            var r = Cells.row(i);
            var c = Cells.col(i);
            var bx = Cells.box(i);
            for (var k = 0; k < 9; k++) {
                cand[r * 9 + k] &= b;
                cand[c + k * 9] &= b;
                cand[Cells.unitCell(18 + bx, k)] &= b;
            }
        }
        for (var i = 0; i < Cells.N; i++) {
            if (grid[i] == 0 && cand[i] == 0) { return null; }
        }
        return cand;
    }

    //! Place `d` at `i` and strike it from the cell's three units. Returns
    //! false when that leaves a peer with nothing to be, which is how the
    //! caller learns the grid has become unsolvable.
    // NB: `hidden` is a class modifier - at module scope the compiler
    // rejects it with a message about extraneous input, which is not a hint
    // about visibility at all. Module functions are all public.
    function assign(grid as Lang.Array<Lang.Number>, cand as Lang.Array<Lang.Number>, i as Lang.Number, d as Lang.Number) as Lang.Boolean {
        grid[i] = d;
        cand[i] = 0;
        var b = ~Bits.of(d);
        var r = Cells.row(i);
        var c = Cells.col(i);
        var bx = Cells.box(i);
        for (var k = 0; k < 9; k++) {
            var a = r * 9 + k;
            var bb = c + k * 9;
            var cc = Cells.unitCell(18 + bx, k);
            if (a != i) {
                if (grid[a] == d) { return false; }
                cand[a] &= b;
                if (grid[a] == 0 && cand[a] == 0) { return false; }
            }
            if (bb != i) {
                if (grid[bb] == d) { return false; }
                cand[bb] &= b;
                if (grid[bb] == 0 && cand[bb] == 0) { return false; }
            }
            if (cc != i) {
                if (grid[cc] == d) { return false; }
                cand[cc] &= b;
                if (grid[cc] == 0 && cand[cc] == 0) { return false; }
            }
        }
        return true;
    }

    //! True when naked and hidden singles alone finish `grid`. This is the
    //! single question the tier table is built on: everything a Beginner,
    //! Easy or Medium puzzle needs is here, and everything Hard and Expert
    //! need is, by construction, not.
    function solvableBySingles(grid as Lang.Array<Lang.Number>) as Lang.Boolean {
        var g = Cells.copy(grid);
        var cand = candidates(g);
        if (cand == null) { return false; }

        var empty = 0;
        for (var i = 0; i < Cells.N; i++) {
            if (g[i] == 0) { empty++; }
        }

        while (empty > 0) {
            var moved = false;

            for (var i = 0; i < Cells.N; i++) {
                if (g[i] == 0 && Bits.count(cand[i]) == 1) {
                    if (!assign(g, cand, i, Bits.lowest(cand[i]))) { return false; }
                    empty--;
                    moved = true;
                }
            }
            if (moved) { continue; }

            for (var u = 0; u < Cells.UNITS && !moved; u++) {
                for (var d = 1; d <= 9 && !moved; d++) {
                    var b = Bits.of(d);
                    var spot = -1;
                    var seen = 0;
                    for (var k = 0; k < 9; k++) {
                        var i = Cells.unitCell(u, k);
                        if (g[i] == d) { seen = 99; break; }
                        if ((cand[i] & b) != 0) {
                            seen++;
                            spot = i;
                        }
                    }
                    if (seen == 0) { return false; }   // d has nowhere to go
                    if (seen == 1) {
                        if (!assign(g, cand, spot, d)) { return false; }
                        empty--;
                        moved = true;
                    }
                }
            }
            if (!moved) { return false; }
        }
        return true;
    }

    //! The next step a player could reasonably find, as
    //! {:kind, :cell, :digit, :unit}. Checks the board for a wrong entry
    //! first: a hint that fills another square while a mistake sits three
    //! rows up is worse than useless, because every candidate it reasons
    //! from is already poisoned.
    function nextHint(entries as Lang.Array<Lang.Number>, solution as Lang.Array<Lang.Number>) as Lang.Dictionary {
        for (var i = 0; i < Cells.N; i++) {
            if (entries[i] != 0 && entries[i] != solution[i]) {
                return {:kind => HINT_WRONG, :cell => i, :digit => entries[i], :unit => -1};
            }
        }

        var cand = candidates(entries);
        if (cand != null) {
            for (var i = 0; i < Cells.N; i++) {
                if (entries[i] == 0 && Bits.count(cand[i]) == 1) {
                    return {:kind => HINT_NAKED, :cell => i,
                            :digit => Bits.lowest(cand[i]), :unit => -1};
                }
            }
            for (var u = 0; u < Cells.UNITS; u++) {
                for (var d = 1; d <= 9; d++) {
                    var b = Bits.of(d);
                    var spot = -1;
                    var seen = 0;
                    for (var k = 0; k < 9; k++) {
                        var i = Cells.unitCell(u, k);
                        if (entries[i] == d) { seen = 99; break; }
                        if ((cand[i] & b) != 0) {
                            seen++;
                            spot = i;
                        }
                    }
                    if (seen == 1) {
                        return {:kind => HINT_HIDDEN, :cell => spot, :digit => d, :unit => u};
                    }
                }
            }
        }

        for (var i = 0; i < Cells.N; i++) {
            if (entries[i] == 0) {
                return {:kind => HINT_REVEAL, :cell => i, :digit => solution[i], :unit => -1};
            }
        }
        return {:kind => HINT_NONE, :cell => -1, :digit => 0, :unit => -1};
    }

    //! Cells whose value repeats inside one of their units, as a bit-per-cell
    //! flag array. Used to paint a clash red the moment it appears.
    function conflicts(entries as Lang.Array<Lang.Number>) as Lang.Array<Lang.Boolean> {
        var bad = new Lang.Array<Lang.Boolean>[Cells.N];
        for (var i = 0; i < Cells.N; i++) { bad[i] = false; }
        for (var u = 0; u < Cells.UNITS; u++) {
            for (var k = 0; k < 9; k++) {
                var a = Cells.unitCell(u, k);
                if (entries[a] == 0) { continue; }
                for (var m = k + 1; m < 9; m++) {
                    var b = Cells.unitCell(u, m);
                    if (entries[a] == entries[b]) {
                        bad[a] = true;
                        bad[b] = true;
                    }
                }
            }
        }
        return bad;
    }
}
