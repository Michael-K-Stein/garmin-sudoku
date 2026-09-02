using Toybox.Test;
using Toybox.Lang;
using Toybox.Application.Storage;

//! The rules a view is not allowed to break, checked directly on Session.
module Play {

    //! A session sitting on a real puzzle, one move from nothing.
    function fresh() as Session {
        var solver = new Solver();
        var puzzle = Fixture.parse(Fixture.EASY);
        var solution = solver.solveFirst(puzzle);
        var s = new Session();
        s.start(Difficulty.EASY, puzzle, solution);
        return s;
    }

    function firstBlank(s as Session) as Lang.Number {
        var e = s.entries;
        for (var i = 0; i < Cells.N; i++) {
            if (e[i] == 0) { return i; }
        }
        return -1;
    }
}

(:test)
function testGivensAreImmutable(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var given = -1;
    for (var i = 0; i < Cells.N; i++) {
        if (s.isGiven(i)) { given = i; break; }
    }
    if (given < 0) { return false; }

    var before = s.entries[given];
    s.place(given, (before % 9) + 1);
    if (s.entries[given] != before) { return false; }
    // A rejected move must not have cost the player a mistake either.
    return s.mistakes == 0 && !s.erase(given);
}

(:test)
function testWrongEntryCountsOnce(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var i = Play.firstBlank(s);
    var wrong = (s.solution[i] % 9) + 1;

    var result = s.place(i, wrong);
    if (result != :wrong || s.mistakes != 1) { return false; }

    // Correcting it does not un-count the mistake, but does not add one.
    s.place(i, s.solution[i]);
    return s.mistakes == 1 && s.entries[i] == s.solution[i];
}

(:test)
function testEntryClearsPeerNotes(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var i = Play.firstBlank(s);
    var d = s.solution[i];

    // Pencil that digit into a peer, then commit it here.
    var peer = -1;
    for (var k = 0; k < Cells.N; k++) {
        if (Cells.peers(k, i) && s.entries[k] == 0) { peer = k; break; }
    }
    if (peer < 0) { return false; }
    s.toggleNote(peer, d);
    if ((s.notes[peer] & Bits.of(d)) == 0) { return false; }

    s.place(i, d);
    return (s.notes[peer] & Bits.of(d)) == 0;
}

(:test)
function testUndoRestoresValueAndNotes(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var i = Play.firstBlank(s);

    s.toggleNote(i, 3);
    s.toggleNote(i, 7);
    var marked = s.notes[i];

    s.place(i, s.solution[i]);
    if (s.notes[i] != 0) { return false; }        // entering clears the marks

    if (!s.undo()) { return false; }
    return s.entries[i] == 0 && s.notes[i] == marked;
}

(:test)
function testEraseAllKeepsTheClues(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var i = Play.firstBlank(s);
    s.place(i, s.solution[i]);
    s.eraseAll();

    for (var k = 0; k < Cells.N; k++) {
        var expected = s.isGiven(k) ? s.puzzle[k] : 0;
        if (s.entries[k] != expected) { return false; }
    }
    return !s.canUndo();
}

(:test)
function testSolvingFinishesTheGame(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var last = :placed;
    for (var i = 0; i < Cells.N; i++) {
        if (s.entries[i] == 0) { last = s.place(i, s.solution[i]); }
    }
    // The final placement is the one that reports the win.
    return last == :won && s.complete && !s.hasGame();
}

(:test)
function testSaveAndLoadRoundTrip(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    var i = Play.firstBlank(s);
    s.place(i, s.solution[i]);
    s.toggleNote(Play.firstBlank(s), 5);
    s.elapsed = 137;
    s.save();

    var back = new Session();
    if (!back.load()) { return false; }
    if (back.tier != s.tier || back.elapsed != 137) { return false; }
    for (var k = 0; k < Cells.N; k++) {
        if (back.entries[k] != s.entries[k]) { return false; }
        if (back.notes[k] != s.notes[k]) { return false; }
        if (back.puzzle[k] != s.puzzle[k]) { return false; }
        if (back.solution[k] != s.solution[k]) { return false; }
    }
    back.discard();
    return true;
}

//! A save written by a future version must be discarded, not half-read. The
//! failure this guards against is a board with no solution.
(:test)
function testFutureSaveIsRejected(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    s.save();

    var stored = Storage.getValue(Session.SAVE_KEY) as Lang.Array;
    stored[0] = Session.SAVE_VERSION + 1;
    Storage.setValue(Session.SAVE_KEY, stored);

    var back = new Session();
    var loaded = back.load();
    return !loaded && Storage.getValue(Session.SAVE_KEY) == null;
}

(:test)
function testCompletedGameIsNotOfferedAsContinue(logger as Test.Logger) as Lang.Boolean {
    var s = Play.fresh();
    for (var i = 0; i < Cells.N; i++) {
        if (s.entries[i] == 0) { s.place(i, s.solution[i]); }
    }
    // Finishing deletes the save, so a fresh session has nothing to resume.
    var back = new Session();
    return !back.load() && !back.hasGame();
}
