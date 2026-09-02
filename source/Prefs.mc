using Toybox.Application.Storage;
using Toybox.Lang;

//! Player settings, each one a thing a real Sudoku player has an opinion
//! about. They are read on every frame the board draws, so they are cached
//! in memory and only written back when one changes.
module Prefs {

    // One storage key per setting rather than one dictionary. Storage
    // serialises dictionaries, but the key types it accepts are not worth
    // betting a player's settings on, and separate keys are additive: a
    // setting added in a later version simply reads back as its default.
    const PREFIX = "pref.";

    // Highlight the row, column and box of the selected cell, plus every
    // other square holding the same digit. Enormously helpful when scanning;
    // some players consider it cheating.
    var highlightPeers = true;

    // Mark an entry that contradicts the solution immediately, instead of
    // letting it sit until the board no longer adds up.
    var showMistakes = true;

    // Erase a digit from the pencil marks of every peer when it is entered.
    var autoNotes = true;

    // Vibrate on a completed unit, a mistake and a win.
    var haptics = true;

    // Some people race the clock; some people find it stressful.
    var showTimer = true;

    function read(name, fallback) {
        var v = Storage.getValue(PREFIX + name);
        return (v instanceof Lang.Boolean) ? v : fallback;
    }

    function load() {
        highlightPeers = read("highlightPeers", highlightPeers);
        showMistakes = read("showMistakes", showMistakes);
        autoNotes = read("autoNotes", autoNotes);
        haptics = read("haptics", haptics);
        showTimer = read("showTimer", showTimer);
    }

    function save() {
        Storage.setValue(PREFIX + "highlightPeers", highlightPeers);
        Storage.setValue(PREFIX + "showMistakes", showMistakes);
        Storage.setValue(PREFIX + "autoNotes", autoNotes);
        Storage.setValue(PREFIX + "haptics", haptics);
        Storage.setValue(PREFIX + "showTimer", showTimer);
    }

    function toggle(key) {
        if (key == :highlightPeers) { highlightPeers = !highlightPeers; }
        else if (key == :showMistakes) { showMistakes = !showMistakes; }
        else if (key == :autoNotes) { autoNotes = !autoNotes; }
        else if (key == :haptics) { haptics = !haptics; }
        else if (key == :showTimer) { showTimer = !showTimer; }
        save();
    }

    function get(key) {
        if (key == :highlightPeers) { return highlightPeers; }
        if (key == :showMistakes) { return showMistakes; }
        if (key == :autoNotes) { return autoNotes; }
        if (key == :haptics) { return haptics; }
        if (key == :showTimer) { return showTimer; }
        return false;
    }
}
