using Toybox.Application.Storage;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;

//! The game in progress, its persistence, and the lifetime record.
//!
//! Views never write these fields directly. They call `place`, `erase`,
//! `toggleNote` and `undo`, so the rules that have to hold together - a given
//! is never overwritten, an entry clears the pencil marks under it, the
//! mistake counter and the undo trail move in step - live in one place.
class Session {

    // Bumped only when old saves genuinely cannot be read. Adding a key is
    // backward compatible because every reader below has a default, so a new
    // field is not a reason to throw away someone's half-finished Expert.
    static const SAVE_VERSION = 1;
    static const SAVE_KEY = "game.v";
    static const UNDO_DEPTH = 24;

    var puzzle as Lang.Array<Lang.Number>?;     // the givens; 0 where the player has to work
    var solution as Lang.Array<Lang.Number>?;   // the one solution
    var entries as Lang.Array<Lang.Number>?;    // what is on the board now, givens included
    var notes as Lang.Array<Lang.Number>?;      // pencil marks, one candidate bitmask per cell
    var tier;
    var elapsed;       // seconds of play, excluding time the app was closed
    var mistakes;
    var hints;
    var selected;      // 0-80, or -1 for nothing selected
    var noteMode;
    var complete;

    hidden var undoCell as Lang.Array<Lang.Number>;
    hidden var undoValue as Lang.Array<Lang.Number>;
    hidden var undoNotes as Lang.Array<Lang.Number>;
    hidden var undoCount;
    hidden var lastTick;      // System.getTimer() at the last accrue()

    function initialize() {
        // The undo trail is a fixed-size ring, so it is allocated once here
        // rather than in clear() - a new puzzle rewinds the cursor, it does
        // not need three new arrays.
        undoCell = new Lang.Array<Lang.Number>[UNDO_DEPTH];
        undoValue = new Lang.Array<Lang.Number>[UNDO_DEPTH];
        undoNotes = new Lang.Array<Lang.Number>[UNDO_DEPTH];
        clear();
    }

    hidden function clear() {
        puzzle = null;
        solution = null;
        entries = null;
        notes = null;
        tier = Difficulty.EASY;
        elapsed = 0;
        mistakes = 0;
        hints = 0;
        selected = -1;
        noteMode = false;
        complete = false;
        undoCount = 0;
        lastTick = null;
    }

    function start(tierIndex, newPuzzle, newSolution) {
        clear();
        tier = tierIndex;
        puzzle = newPuzzle;
        solution = newSolution;
        entries = Cells.copy(newPuzzle);
        notes = new Lang.Array<Lang.Number>[Cells.N];
        for (var i = 0; i < Cells.N; i++) { notes[i] = 0; }
        selected = firstEmpty();
        Stats.recordStart(tier);
        save();
    }

    function hasGame() {
        return puzzle != null && !complete;
    }

    function isGiven(i) {
        return puzzle != null && puzzle[i] != 0;
    }

    function firstEmpty() {
        for (var i = 0; i < Cells.N; i++) {
            if (entries[i] == 0) { return i; }
        }
        return 0;
    }

    function filledCount() {
        var n = 0;
        for (var i = 0; i < Cells.N; i++) {
            if (entries[i] != 0) { n++; }
        }
        return n;
    }

    function clueCount() {
        var n = 0;
        for (var i = 0; i < Cells.N; i++) {
            if (puzzle[i] != 0) { n++; }
        }
        return n;
    }

    // --- the clock -------------------------------------------------------

    //! Advance the play clock from the wall clock rather than from a frame
    //! count, so a screen that redraws lazily does not run slow.
    function tickClock() {
        var now = System.getTimer();
        if (lastTick == null) {
            lastTick = now;
            return false;
        }
        var delta = now - lastTick;
        if (delta < 0) { delta = 0; }        // the timer wraps
        if (delta < 1000) { return false; }
        var seconds = delta / 1000;
        elapsed += seconds;
        lastTick += seconds * 1000;
        return true;
    }

    function resumeClock() {
        lastTick = System.getTimer();
    }

    function pauseClock() {
        tickClock();
        lastTick = null;
    }

    // --- moves -----------------------------------------------------------

    hidden function pushUndo(i) {
        if (undoCount >= UNDO_DEPTH) {
            for (var k = 1; k < UNDO_DEPTH; k++) {
                undoCell[k - 1] = undoCell[k];
                undoValue[k - 1] = undoValue[k];
                undoNotes[k - 1] = undoNotes[k];
            }
            undoCount = UNDO_DEPTH - 1;
        }
        undoCell[undoCount] = i;
        undoValue[undoCount] = entries[i];
        undoNotes[undoCount] = notes[i];
        undoCount++;
    }

    //! Enter `d` at the selected cell. Returns a symbol the view turns into
    //! feedback: :given, :wrong, :placed or :won.
    function place(i, d) {
        if (isGiven(i) || complete) { return :given; }
        pushUndo(i);
        entries[i] = d;
        notes[i] = 0;

        if (Prefs.autoNotes) {
            var b = ~Bits.of(d);
            var r = Cells.row(i);
            var c = Cells.col(i);
            var bx = Cells.box(i);
            for (var k = 0; k < 9; k++) {
                notes[r * 9 + k] &= b;
                notes[c + k * 9] &= b;
                notes[Cells.unitCell(18 + bx, k)] &= b;
            }
        }

        var wrong = (d != solution[i]);
        if (wrong) { mistakes++; }
        if (isSolved()) {
            finish();
            return :won;
        }
        save();
        return wrong ? :wrong : :placed;
    }

    function erase(i) {
        if (isGiven(i) || complete) { return false; }
        if (entries[i] == 0 && notes[i] == 0) { return false; }
        pushUndo(i);
        entries[i] = 0;
        notes[i] = 0;
        save();
        return true;
    }

    function toggleNote(i, d) {
        if (isGiven(i) || complete || entries[i] != 0) { return false; }
        pushUndo(i);
        notes[i] ^= Bits.of(d);
        save();
        return true;
    }

    function canUndo() {
        return undoCount > 0 && !complete;
    }

    function undo() {
        if (!canUndo()) { return false; }
        undoCount--;
        var i = undoCell[undoCount];
        entries[i] = undoValue[undoCount];
        notes[i] = undoNotes[undoCount];
        selected = i;
        save();
        return true;
    }

    function eraseAll() {
        if (complete) { return; }
        for (var i = 0; i < Cells.N; i++) {
            if (puzzle[i] == 0) {
                entries[i] = 0;
                notes[i] = 0;
            }
        }
        undoCount = 0;
        save();
    }

    //! Give the player one square, and charge them for it in the record.
    function applyHint(hint) {
        var kind = hint.get(:kind);
        var i = hint.get(:cell);
        if (i == null || i < 0) { return false; }
        hints++;
        if (kind == Logic.HINT_WRONG) {
            erase(i);
            selected = i;
            save();
            return true;
        }
        selected = i;
        place(i, hint.get(:digit));
        return true;
    }

    function isSolved() {
        for (var i = 0; i < Cells.N; i++) {
            if (entries[i] != solution[i]) { return false; }
        }
        return true;
    }

    hidden function finish() {
        complete = true;
        pauseClock();
        Stats.recordWin(tier, elapsed, mistakes, hints);
        Storage.deleteValue(SAVE_KEY);
    }

    //! True when this win beat the stored best for its tier. Read after
    //! `finish`, which has already folded the time into the record - so the
    //! comparison is against the previous best, kept by Stats for exactly
    //! this question.
    function wasPersonalBest() {
        return Stats.lastWasBest;
    }

    // --- persistence ------------------------------------------------------

    function save() {
        if (puzzle == null || complete) { return; }
        Storage.setValue(SAVE_KEY, [
            SAVE_VERSION, tier, elapsed, mistakes, hints, selected,
            puzzle, solution, entries, notes
        ]);
    }

    function discard() {
        Storage.deleteValue(SAVE_KEY);
        clear();
    }

    //! Restore a game in progress. Anything unexpected in storage is treated
    //! as "no saved game" rather than trusted - a corrupt board would be a
    //! puzzle with no solution, which is worse than losing one session.
    function load() {
        var d = Storage.getValue(SAVE_KEY);
        if (!(d instanceof Lang.Array) || d.size() < 10) { return false; }
        if (d[0] != SAVE_VERSION) {
            Storage.deleteValue(SAVE_KEY);
            return false;
        }
        var p = d[6];
        var s = d[7];
        var e = d[8];
        var n = d[9];
        if (!(p instanceof Lang.Array) || p.size() != Cells.N) { return false; }
        if (!(s instanceof Lang.Array) || s.size() != Cells.N) { return false; }
        if (!(e instanceof Lang.Array) || e.size() != Cells.N) { return false; }
        if (!(n instanceof Lang.Array) || n.size() != Cells.N) { return false; }

        clear();
        tier = d[1];
        elapsed = d[2];
        mistakes = d[3];
        hints = d[4];
        selected = d[5];
        puzzle = p;
        solution = s;
        entries = e;
        notes = n;
        complete = false;
        return true;
    }
}
