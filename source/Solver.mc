using Toybox.Lang;

//! Counting backtracking solver over row/column/box bitmasks.
//!
//! The search is iterative rather than recursive on purpose. It goes 60+ cells
//! deep on a near-minimal puzzle, and a watch's interpreter stack is not a
//! place to find out empirically how deep is too deep. An explicit trail costs
//! three 82-element arrays, allocated once per Solver and reused by every
//! call, which also keeps the generator from churning the heap.
//!
//! `count(grid, limit)` stops the moment `limit` solutions have been seen.
//! The generator only ever asks for one, which is what makes the uniqueness
//! test in `Generator` affordable.
class Solver {

    hidden var work as Lang.Array<Lang.Number>;          // the grid being searched
    hidden var rows as Lang.Array<Lang.Number>;
    hidden var cols as Lang.Array<Lang.Number>;
    hidden var boxes as Lang.Array<Lang.Number>;
    hidden var trailCell as Lang.Array<Lang.Number>;     // search trail: which cell each depth owns
    hidden var trailLeft as Lang.Array<Lang.Number>;     // candidates not yet tried at that depth
    hidden var trailPut as Lang.Array<Lang.Number>;      // digit currently placed there, 0 for none

    var solution as Lang.Array<Lang.Number>?;            // the first solution found, or null
    var nodes as Lang.Number;          // placements tried; used to pace generation

    function initialize() {
        work = new Lang.Array<Lang.Number>[Cells.N];
        rows = new Lang.Array<Lang.Number>[9];
        cols = new Lang.Array<Lang.Number>[9];
        boxes = new Lang.Array<Lang.Number>[9];
        trailCell = new Lang.Array<Lang.Number>[Cells.N + 1];
        trailLeft = new Lang.Array<Lang.Number>[Cells.N + 1];
        trailPut = new Lang.Array<Lang.Number>[Cells.N + 1];
        solution = null;
        nodes = 0;
    }

    hidden function maskAt(i as Lang.Number) as Lang.Number {
        return Bits.ALL & ~(rows[Cells.row(i)] | cols[Cells.col(i)] | boxes[Cells.box(i)]);
    }

    hidden function place(i as Lang.Number, d as Lang.Number) as Void {
        var b = Bits.of(d);
        work[i] = d;
        rows[Cells.row(i)] |= b;
        cols[Cells.col(i)] |= b;
        boxes[Cells.box(i)] |= b;
    }

    hidden function unplace(i as Lang.Number, d as Lang.Number) as Void {
        var b = ~Bits.of(d);
        work[i] = 0;
        rows[Cells.row(i)] &= b;
        cols[Cells.col(i)] &= b;
        boxes[Cells.box(i)] &= b;
    }

    //! The most constrained empty cell: -1 when the grid is full, -2 when
    //! some empty cell has no candidate left and the branch is dead.
    hidden function choose() as Lang.Number {
        var best = -1;
        var bestSize = 10;
        for (var i = 0; i < Cells.N; i++) {
            if (work[i] != 0) { continue; }
            var m = maskAt(i);
            if (m == 0) { return -2; }
            var s = Bits.count(m);
            if (s < bestSize) {
                bestSize = s;
                best = i;
                if (s == 1) { return i; }   // nothing can beat a forced cell
            }
        }
        return best;
    }

    //! How many solutions `grid` has, counted up to `limit`. Returns 0 for a
    //! grid whose givens already contradict each other.
    function count(grid as Lang.Array<Lang.Number>, limit as Lang.Number) as Lang.Number {
        for (var u = 0; u < 9; u++) {
            rows[u] = 0;
            cols[u] = 0;
            boxes[u] = 0;
        }
        for (var i = 0; i < Cells.N; i++) {
            work[i] = grid[i];
            var v = grid[i];
            if (v == 0) { continue; }
            var b = Bits.of(v);
            if ((rows[Cells.row(i)] & b) != 0
                || (cols[Cells.col(i)] & b) != 0
                || (boxes[Cells.box(i)] & b) != 0) {
                solution = null;
                return 0;
            }
            rows[Cells.row(i)] |= b;
            cols[Cells.col(i)] |= b;
            boxes[Cells.box(i)] |= b;
        }

        solution = null;
        nodes = 0;

        var first = choose();
        if (first == -2) { return 0; }
        if (first == -1) {
            solution = Cells.copy(work);
            return 1;
        }

        var found = 0;
        var depth = 0;
        trailCell[0] = first;
        trailLeft[0] = maskAt(first);
        trailPut[0] = 0;

        while (depth >= 0) {
            var cell = trailCell[depth];
            if (trailPut[depth] != 0) {
                unplace(cell, trailPut[depth]);
                trailPut[depth] = 0;
            }
            if (trailLeft[depth] == 0) {
                depth--;                       // out of digits here; step back
                continue;
            }

            var d = Bits.lowest(trailLeft[depth]);
            trailLeft[depth] &= ~Bits.of(d);
            place(cell, d);
            trailPut[depth] = d;
            nodes++;

            var next = choose();
            if (next == -2) { continue; }      // dead end; next digit
            if (next == -1) {
                found++;
                if (solution == null) { solution = Cells.copy(work); }
                if (found >= limit) { return found; }
                continue;                      // keep looking for another
            }
            depth++;
            trailCell[depth] = next;
            trailLeft[depth] = maskAt(next);
            trailPut[depth] = 0;
        }
        return found;
    }

    //! The first solution of `grid`, or null if it has none.
    function solveFirst(grid as Lang.Array<Lang.Number>) as Lang.Array<Lang.Number>? {
        count(grid, 1);
        return solution;
    }

    //! True when `grid` has exactly one solution.
    function isUnique(grid as Lang.Array<Lang.Number>) as Lang.Boolean {
        return count(grid, 2) == 1;
    }
}
