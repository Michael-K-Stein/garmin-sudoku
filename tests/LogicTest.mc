using Toybox.Test;
using Toybox.Lang;

//! Fixtures and tests for the parts of the app that are pure computation.
//! These run in the simulator via `tools/test.sh`, which is the only place
//! anything in `source/` is actually executed rather than merely compiled.
module Fixture {

    //! An 81-character board, '.' or '0' for a blank.
    function parse(s as Lang.String) as Lang.Array<Lang.Number> {
        var chars = s.toCharArray();
        var g = Cells.blank();
        for (var i = 0; i < Cells.N; i++) {
            var c = chars[i];
            g[i] = (c == '.' || c == '0') ? 0 : (c.toNumber() - 48);
        }
        return g;
    }

    // A newspaper "easy": 30 clues, and singles alone finish it.
    const EASY =
        "530070000600195000098000060800060003400803001700020006060000280000419005000080079";

    // Arto Inkala's 2012 puzzle, published as the hardest he could construct.
    // 21 clues, uniquely solvable, and no amount of scanning cracks it.
    const EXTREME =
        "800000000003600000070090200050007000000045700000100030001000068008500010090000400";

    // The same easy board with one clue removed, which leaves it with more
    // than one solution.
    const AMBIGUOUS =
        "530070000600195000098000060800060003400803001700020006060000280000419005000080070";
}

(:test)
function testBitsRoundTrip(logger as Test.Logger) as Lang.Boolean {
    var m = 0;
    for (var d = 1; d <= 9; d++) { m |= Bits.of(d); }
    return m == Bits.ALL
        && Bits.count(Bits.ALL) == 9
        && Bits.count(0) == 0
        && Bits.lowest(0) == 0
        && Bits.lowest(Bits.of(7)) == 7
        && Bits.lowest(Bits.of(3) | Bits.of(8)) == 3;
}

(:test)
function testCellGeometry(logger as Test.Logger) as Lang.Boolean {
    if (Cells.row(0) != 0 || Cells.col(0) != 0 || Cells.box(0) != 0) { return false; }
    if (Cells.row(80) != 8 || Cells.col(80) != 8 || Cells.box(80) != 8) { return false; }
    if (Cells.box(30) != 4) { return false; }        // row 3, col 3
    if (!Cells.peers(0, 8) || !Cells.peers(0, 72) || !Cells.peers(0, 10)) { return false; }
    if (Cells.peers(0, 0) || Cells.peers(0, 40)) { return false; }
    return true;
}

//! Every unit has to be a permutation of nine distinct cells, and every cell
//! has to appear in exactly three units. An off-by-one in unitCell's box
//! arithmetic would still look plausible on screen but would quietly break
//! both the solver and the hint finder.
(:test)
function testUnitsCoverEveryCell(logger as Test.Logger) as Lang.Boolean {
    var seen = new Lang.Array<Lang.Number>[Cells.N];
    for (var i = 0; i < Cells.N; i++) { seen[i] = 0; }

    for (var u = 0; u < Cells.UNITS; u++) {
        var inUnit = new Lang.Array<Lang.Number>[Cells.N];
        for (var i = 0; i < Cells.N; i++) { inUnit[i] = 0; }
        for (var k = 0; k < 9; k++) {
            var i = Cells.unitCell(u, k);
            if (i < 0 || i >= Cells.N) { return false; }
            if (inUnit[i] != 0) { return false; }      // a repeat within a unit
            inUnit[i] = 1;
            seen[i]++;
        }
    }
    for (var i = 0; i < Cells.N; i++) {
        if (seen[i] != 3) { return false; }            // row, column and box
    }
    return true;
}

(:test)
function testSolverSolvesAndCounts(logger as Test.Logger) as Lang.Boolean {
    var solver = new Solver();
    var easy = Fixture.parse(Fixture.EASY);

    var solved = solver.solveFirst(easy);
    if (solved == null) { return false; }
    for (var i = 0; i < Cells.N; i++) {
        if (solved[i] < 1 || solved[i] > 9) { return false; }
        if (easy[i] != 0 && solved[i] != easy[i]) { return false; }
    }
    // A complete grid must have no repeat in any unit.
    for (var u = 0; u < Cells.UNITS; u++) {
        var mask = 0;
        for (var k = 0; k < 9; k++) { mask |= Bits.of(solved[Cells.unitCell(u, k)]); }
        if (mask != Bits.ALL) { return false; }
    }
    return solver.count(easy, 2, Solver.NO_BUDGET) == 1;
}

(:test)
function testSolverRejectsAndDetectsAmbiguity(logger as Test.Logger) as Lang.Boolean {
    var solver = new Solver();

    // Two 5s in the first row: no solution at all, and the initial scan
    // should say so without searching.
    var broken = Fixture.parse(Fixture.EASY);
    broken[1] = 5;
    if (solver.count(broken, 2, Solver.NO_BUDGET) != 0) { return false; }

    // One clue short of the real board leaves more than one answer.
    return solver.count(Fixture.parse(Fixture.AMBIGUOUS), 2, Solver.NO_BUDGET) == 2;
}

(:test)
function testSolverHandlesTheHardestBoard(logger as Test.Logger) as Lang.Boolean {
    // 21 clues. If the iterative trail is wrong at any depth this is where it
    // shows, because this board makes the search go deep.
    return new Solver().count(Fixture.parse(Fixture.EXTREME), 2, Solver.NO_BUDGET) == 1;
}

//! The single question the whole tier table rests on.
(:test)
function testSinglesSeparatesEasyFromExtreme(logger as Test.Logger) as Lang.Boolean {
    return Logic.solvableBySingles(Fixture.parse(Fixture.EASY))
        && !Logic.solvableBySingles(Fixture.parse(Fixture.EXTREME));
}

(:test)
function testConflictsFindBothCulprits(logger as Test.Logger) as Lang.Boolean {
    var g = Cells.blank();
    g[0] = 4;
    g[5] = 4;          // same row
    g[40] = 7;
    var bad = Logic.conflicts(g);
    return bad[0] && bad[5] && !bad[40] && !bad[1];
}

(:test)
function testHintFindsAWrongEntryFirst(logger as Test.Logger) as Lang.Boolean {
    var solver = new Solver();
    var puzzle = Fixture.parse(Fixture.EASY);
    var solution = solver.solveFirst(puzzle);
    if (solution == null) { return false; }

    var entries = Cells.copy(puzzle);
    // Put a digit that is legal against its peers but is not the answer.
    var target = -1;
    for (var i = 0; i < Cells.N; i++) {
        if (entries[i] == 0) {
            entries[i] = (solution[i] % 9) + 1;
            target = i;
            break;
        }
    }
    var hint = Logic.nextHint(entries, solution);
    return hint.get(:kind) == Logic.HINT_WRONG && hint.get(:cell) == target;
}

(:test)
function testHintFindsALogicalStep(logger as Test.Logger) as Lang.Boolean {
    var solver = new Solver();
    var puzzle = Fixture.parse(Fixture.EASY);
    var solution = solver.solveFirst(puzzle);
    if (solution == null) { return false; }

    var hint = Logic.nextHint(puzzle, solution);
    var kind = hint.get(:kind);
    if (kind != Logic.HINT_NAKED && kind != Logic.HINT_HIDDEN) { return false; }

    // Whatever it claims, it has to be the truth.
    var cell = hint.get(:cell) as Lang.Number;
    return puzzle[cell] == 0 && hint.get(:digit) == solution[cell];
}

(:test)
function testFormatClock(logger as Test.Logger) as Lang.Boolean {
    return Fmt.clock(0).equals("0:00")
        && Fmt.clock(9).equals("0:09")
        && Fmt.clock(61).equals("1:01")
        && Fmt.clock(600).equals("10:00")
        && Fmt.clock(3599).equals("59:59")
        && Fmt.clock(3600).equals("1:00:00")
        && Fmt.clock(3661).equals("1:01:01")
        && Fmt.clockOrDash(0).equals("-");
}
