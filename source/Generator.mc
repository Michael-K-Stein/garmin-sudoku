using Toybox.Lang;
using Toybox.Math;

//! Builds a puzzle without blocking the UI.
//!
//! Generating a graded, uniquely-solvable Sudoku costs a few hundred solver
//! calls, which is far too much for one timer callback - the watch would drop
//! the frame and the user would watch a frozen screen. So the whole thing is
//! a state machine: `step()` does a bounded slice of work and returns, and
//! `GenerateDelegate` calls it from a timer behind a ProgressBar.
//!
//! The shape of the algorithm:
//!
//!   1. BUILD   a random complete grid.
//!   2. DIG     remove clues, one at a time, for as long as the puzzle stays
//!              uniquely solvable. This is the expensive phase and it runs
//!              with no difficulty checks at all - it just goes as far as it
//!              can, which lands around 24 clues.
//!   3. JUDGE   a tier that needs real deduction rejects a minimal puzzle
//!              that singles happen to crack, and starts over. Roughly half
//!              of them do, so this costs about two digs on average.
//!   4. ADDBACK put clues back from the solution until the tier's clue target
//!              is met. Adding a given can only make a puzzle easier and can
//!              never break uniqueness, so this walks the difficulty *down*
//!              to the tier instead of hunting for it - which is what makes
//!              the easy tiers reliable rather than a rejection lottery.
class Generator {

    static const P_BUILD = 0;
    static const P_DIG = 1;
    static const P_JUDGE = 2;
    static const P_ADDBACK = 3;
    static const P_DONE = 4;

    // A dig that keeps failing its tier is not stuck, just unlucky: about
    // half of all minimal puzzles turn out to be crackable by scanning, so
    // Hard and Expert need a second dig roughly half the time and a third
    // roughly a quarter of it.
    //
    // The cap exists because the player is watching a progress bar, and past
    // it the generator ships the puzzle in hand rather than spinning - which
    // means an Expert board that is quietly easier than advertised. At eight
    // attempts that happened once in 150 puzzles under
    // tools/check_generator.py, which is often enough to notice. Twelve puts
    // it near one in six thousand while leaving the *expected* cost - just
    // under two digs - completely unchanged.
    static const MAX_ATTEMPTS = 12;

    // Cells processed per step() in ADDBACK, which does no solver search at
    // all - just a placement plus a singles scan - so a whole cell per call
    // is cheap.
    static const CELLS_PER_STEP = 2;

    // Solver calls per step() in DIG. Checking one cell for stillUnique costs
    // up to eight of these, which used to run to completion inside a single
    // callback - fine on the simulator, but on-device each call is itself an
    // exhaustive backtracking search (Solver.NODE_BUDGET nodes), and eight of
    // them back-to-back tripped the watchdog. Bounding the *count of solver
    // calls* per callback, not just the size of each one, is what actually
    // keeps a single tick's total work constant regardless of how slow any
    // one call turns out to be - so stillUnique's per-cell digit loop is
    // itself part of the step() state machine now, resumed one digit's worth
    // of solving at a time.
    static const SOLVER_CALLS_PER_STEP = 2;

    var phase as Lang.Number;
    var puzzle as Lang.Array<Lang.Number>?;    // the grid the player will see
    var solution as Lang.Array<Lang.Number>?;  // its one solution
    var tier as Lang.Number;

    hidden var solver;
    hidden var order as Lang.Array<Lang.Number>;    // the order cells are visited in
    hidden var cursor;
    hidden var attempt;
    hidden var clues;
    hidden var work;           // work done, for a progress bar that only rises

    // stillUnique's state, carried across step() calls while digCell != -1.
    hidden var digCell;        // cell currently being tested, or -1 between cells
    hidden var digV;           // its original value
    hidden var digDigit;       // last digit tried there (0 before the first)
    hidden var digUnique;      // no alternate digit has worked so far

    function initialize(tierIndex as Lang.Number) {
        tier = tierIndex;
        solver = new Solver();
        phase = P_BUILD;
        attempt = 0;
        work = 0;
        puzzle = null;
        solution = null;
        order = new Lang.Array<Lang.Number>[Cells.N];
        cursor = 0;
        clues = Cells.N;
        digCell = -1;
    }

    hidden function shuffle(a as Lang.Array) as Void {
        for (var i = a.size() - 1; i > 0; i--) {
            var j = Math.rand() % (i + 1);
            var t = a[i];
            a[i] = a[j];
            a[j] = t;
        }
    }

    hidden function resetOrder() as Void {
        for (var i = 0; i < Cells.N; i++) { order[i] = i; }
        shuffle(order);
        cursor = 0;
    }

    //! A random complete grid. The three diagonal boxes share no row, column
    //! or box, so they can be filled with three independent shuffles and the
    //! solver finishes the other 54 cells almost without backtracking.
    hidden function buildSolved() as Lang.Array<Lang.Number>? {
        var g = Cells.blank();
        var digits = new Lang.Array<Lang.Number>[9];
        for (var b = 0; b < 3; b++) {
            for (var d = 0; d < 9; d++) { digits[d] = d + 1; }
            shuffle(digits);
            var unit = 18 + b * 4;              // boxes 0, 4 and 8
            for (var k = 0; k < 9; k++) {
                g[Cells.unitCell(unit, k)] = digits[k];
            }
        }
        return solver.solveFirst(g);
    }

    static const DIG_DONE = 0;      // digCell resolved - clue removed or restored
    static const DIG_SKIPPED = 1;   // one digit dismissed for free, no solver call
    static const DIG_SOLVED = 2;    // one bounded solver call happened

    //! One slice of the DIG phase's per-cell digit loop: tries the next
    //! digit at `digCell` (started by the caller), or skips it for free when
    //! it is the original clue or the cell is already known not-unique.
    hidden function stillUniqueStep() as Lang.Number {
        digDigit++;
        if (digDigit > 9) {
            if (digUnique) { clues--; } else { puzzle[digCell] = digV; }
            return DIG_DONE;
        }
        if (digDigit == digV || !digUnique) { return DIG_SKIPPED; }
        puzzle[digCell] = digDigit;
        var found = solver.count(puzzle, 1, Solver.NODE_BUDGET);
        puzzle[digCell] = 0;
        if (found > 0) { digUnique = false; }
        return DIG_SOLVED;
    }

    //! One slice of work. Returns the progress percentage, 0-100.
    function step() as Lang.Number {
        if (phase == P_BUILD) {
            attempt++;
            solution = buildSolved();
            puzzle = Cells.copy(solution);
            clues = Cells.N;
            resetOrder();
            phase = P_DIG;

        } else if (phase == P_DIG) {
            var calls = 0;
            while (calls < SOLVER_CALLS_PER_STEP) {
                if (digCell == -1) {
                    if (cursor >= Cells.N) { break; }
                    var i = order[cursor];
                    cursor++;
                    var v = puzzle[i];
                    if (v == 0) { continue; }      // already empty; no work here
                    work++;
                    puzzle[i] = 0;
                    digCell = i;
                    digV = v;
                    digDigit = 0;
                    digUnique = true;
                }
                var r = stillUniqueStep();
                if (r == DIG_DONE) { digCell = -1; }
                if (r == DIG_SOLVED) { calls++; }
            }
            if (cursor >= Cells.N && digCell == -1) { phase = P_JUDGE; }

        } else if (phase == P_JUDGE) {
            if (Difficulty.needsAdvanced(tier) && Logic.solvableBySingles(puzzle)) {
                // Too easy for this tier, and no amount of clue removal will
                // fix it - the dig is already at the bottom. Start over.
                if (attempt < MAX_ATTEMPTS) {
                    phase = P_BUILD;
                } else {
                    phase = P_ADDBACK;
                    resetOrder();
                }
            } else {
                phase = P_ADDBACK;
                resetOrder();
            }

        } else if (phase == P_ADDBACK) {
            var target = Difficulty.targetClues(tier);
            var advanced = Difficulty.needsAdvanced(tier);
            if (target == 0) {
                phase = P_DONE;
                return 100;
            }
            for (var n = 0; n < CELLS_PER_STEP && cursor < Cells.N; n++) {
                if (clues >= target && (advanced || Logic.solvableBySingles(puzzle))) {
                    phase = P_DONE;
                    return 100;
                }
                var i = order[cursor];
                cursor++;
                work++;
                if (puzzle[i] != 0) { continue; }
                puzzle[i] = solution[i];
                if (advanced && Logic.solvableBySingles(puzzle)) {
                    // This given hands the puzzle to plain scanning, which is
                    // exactly what this tier promises not to do. Try another.
                    puzzle[i] = 0;
                    continue;
                }
                clues++;
            }
            if (cursor >= Cells.N) { phase = P_DONE; return 100; }
        }

        if (phase == P_DONE) { return 100; }

        // Two digs is the expected cost, so scale against that and clamp: a
        // bar that stalls at 96 reads better than one that jumps backwards
        // every time an attempt restarts.
        var pct = work * 100 / (Cells.N * 2);
        return pct > 96 ? 96 : pct;
    }

    function isDone() as Lang.Boolean {
        return phase == P_DONE;
    }

    //! The finished puzzle. Every attempt ends holding a uniquely-solvable
    //! grid, so even the unlucky case where the tier was never satisfied
    //! hands back a real puzzle - just an easier one than advertised.
    function result() as Lang.Array<Lang.Number>? {
        return puzzle;
    }
}
