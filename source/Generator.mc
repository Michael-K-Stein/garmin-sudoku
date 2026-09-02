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

    // Cells processed per step(). One cell is up to eight bounded solver
    // runs; two keeps a callback well under a frame while still finishing a
    // dig in about forty steps.
    static const CELLS_PER_STEP = 2;

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

    //! Whether the puzzle stays uniquely solvable with cell `i` emptied.
    //! `i` is already 0 in `puzzle`, and the original value is `v`.
    //!
    //! Cheaper than counting solutions from scratch: the puzzle was unique a
    //! moment ago, so it can only have gained solutions through this one
    //! cell. If no other digit fits there, nothing was gained.
    hidden function stillUnique(i as Lang.Number, v as Lang.Number) as Lang.Boolean {
        for (var d = 1; d <= 9; d++) {
            if (d == v) { continue; }
            puzzle[i] = d;
            var found = solver.count(puzzle, 1);
            puzzle[i] = 0;
            if (found > 0) { return false; }
        }
        return true;
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
            for (var n = 0; n < CELLS_PER_STEP && cursor < Cells.N; n++) {
                var i = order[cursor];
                cursor++;
                work++;
                var v = puzzle[i];
                if (v == 0) { continue; }
                puzzle[i] = 0;
                if (stillUnique(i, v)) {
                    clues--;
                } else {
                    puzzle[i] = v;
                }
            }
            if (cursor >= Cells.N) { phase = P_JUDGE; }

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
