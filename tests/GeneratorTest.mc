using Toybox.Test;
using Toybox.Lang;

//! The generator's contract, checked on the device it actually runs on.
//!
//! `tools/check_generator.py` proves the same properties over many more
//! puzzles on a desktop, where a thousand samples is seconds rather than
//! minutes. These tests are the on-watch half: they prove the Monkey C
//! implementation of that algorithm produces the same kind of puzzle, using
//! the real Solver and the real tier table.
module Gen {

    //! Run a generator to completion the way the progress bar does, but
    //! without the timer. Returns null if it somehow never finishes.
    function run(tier as Lang.Number) as Generator? {
        var g = new Generator(tier);
        // The dig visits 81 cells two at a time, plus add-back and up to
        // MAX_ATTEMPTS restarts; this bound is far above anything reachable.
        for (var i = 0; i < 20000; i++) {
            g.step();
            if (g.isDone()) { return g; }
        }
        return null;
    }

    function clues(g as Lang.Array<Lang.Number>) as Lang.Number {
        var n = 0;
        for (var i = 0; i < Cells.N; i++) {
            if (g[i] != 0) { n++; }
        }
        return n;
    }

    //! Everything that has to be true of any puzzle this app shows anyone.
    function isWellFormed(puzzle as Lang.Array<Lang.Number>,
                          solution as Lang.Array<Lang.Number>) as Lang.Boolean {
        for (var i = 0; i < Cells.N; i++) {
            if (puzzle[i] != 0 && puzzle[i] != solution[i]) { return false; }
            if (solution[i] < 1 || solution[i] > 9) { return false; }
        }
        // The solution has to be a real solution.
        for (var u = 0; u < Cells.UNITS; u++) {
            var mask = 0;
            for (var k = 0; k < 9; k++) { mask |= Bits.of(solution[Cells.unitCell(u, k)]); }
            if (mask != Bits.ALL) { return false; }
        }
        // A puzzle with two answers is not a puzzle.
        return new Solver().count(puzzle, 2) == 1;
    }
}

(:test)
function testBeginnerIsSolvableByScanning(logger as Test.Logger) as Lang.Boolean {
    var g = Gen.run(Difficulty.BEGINNER);
    if (g == null) { return false; }
    var puzzle = g.result();
    var solution = g.solution;
    if (puzzle == null || solution == null) { return false; }
    if (!Gen.isWellFormed(puzzle, solution)) { return false; }

    var n = Gen.clues(puzzle);
    logger.debug("BEGINNER clues: " + n.toString());
    return n >= Difficulty.targetClues(Difficulty.BEGINNER)
        && Logic.solvableBySingles(puzzle);
}

(:test)
function testEasyIsSolvableByScanning(logger as Test.Logger) as Lang.Boolean {
    var g = Gen.run(Difficulty.EASY);
    if (g == null) { return false; }
    var puzzle = g.result();
    var solution = g.solution;
    if (puzzle == null || solution == null) { return false; }
    if (!Gen.isWellFormed(puzzle, solution)) { return false; }

    var n = Gen.clues(puzzle);
    logger.debug("EASY clues: " + n.toString());
    return n >= Difficulty.targetClues(Difficulty.EASY)
        && n < Difficulty.targetClues(Difficulty.BEGINNER)
        && Logic.solvableBySingles(puzzle);
}

(:test)
function testMediumIsSparserThanEasy(logger as Test.Logger) as Lang.Boolean {
    var g = Gen.run(Difficulty.MEDIUM);
    if (g == null) { return false; }
    var puzzle = g.result();
    var solution = g.solution;
    if (puzzle == null || solution == null) { return false; }
    if (!Gen.isWellFormed(puzzle, solution)) { return false; }

    var n = Gen.clues(puzzle);
    logger.debug("MEDIUM clues: " + n.toString());
    return n >= Difficulty.targetClues(Difficulty.MEDIUM)
        && n < Difficulty.targetClues(Difficulty.EASY)
        && Logic.solvableBySingles(puzzle);
}

//! Hard and Expert make a promise that is worth testing rather than trusting:
//! scanning for singles is *not* enough. This is the assertion that would
//! catch the generator quietly falling back to an easy puzzle.
(:test)
function testHardDefeatsScanning(logger as Test.Logger) as Lang.Boolean {
    var g = Gen.run(Difficulty.HARD);
    if (g == null) { return false; }
    var puzzle = g.result();
    var solution = g.solution;
    if (puzzle == null || solution == null) { return false; }
    if (!Gen.isWellFormed(puzzle, solution)) { return false; }

    var n = Gen.clues(puzzle);
    logger.debug("HARD clues: " + n.toString());
    return n >= Difficulty.targetClues(Difficulty.HARD)
        && !Logic.solvableBySingles(puzzle);
}

(:test)
function testExpertIsMinimalAndDefeatsScanning(logger as Test.Logger) as Lang.Boolean {
    var g = Gen.run(Difficulty.EXPERT);
    if (g == null) { return false; }
    var puzzle = g.result();
    var solution = g.solution;
    if (puzzle == null || solution == null) { return false; }
    if (!Gen.isWellFormed(puzzle, solution)) { return false; }

    var n = Gen.clues(puzzle);
    logger.debug("EXPERT clues: " + n.toString());
    // No add-back at all, so it stays wherever the dig bottomed out. Below
    // 17 is mathematically impossible for a unique puzzle.
    return n >= 17
        && n <= Difficulty.targetClues(Difficulty.HARD)
        && !Logic.solvableBySingles(puzzle);
}

//! Two runs must not produce the same board. This is the test that catches an
//! unseeded or badly seeded Math.rand, which would ship every player the same
//! first puzzle.
(:test)
function testPuzzlesDiffer(logger as Test.Logger) as Lang.Boolean {
    var a = Gen.run(Difficulty.BEGINNER);
    var b = Gen.run(Difficulty.BEGINNER);
    if (a == null || b == null) { return false; }
    var pa = a.result();
    var pb = b.result();
    if (pa == null || pb == null) { return false; }
    for (var i = 0; i < Cells.N; i++) {
        if (pa[i] != pb[i]) { return true; }
    }
    return false;
}
