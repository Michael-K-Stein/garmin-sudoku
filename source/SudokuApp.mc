using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;

//! The one Session every screen reads. Views hold a reference to it rather
//! than to each other, which is what keeps the board, the win screen and the
//! menus from having to know one another.
var gSession as Session? = null;

class SudokuApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        // Math.rand is deterministic from a fixed seed, and a puzzle app that
        // deals the same first board to everyone on every install is a bug
        // people notice immediately.
        Math.srand(Time.now().value() + System.getTimer());

        Prefs.load();
        $.gSession = new Session();
        $.gSession.load();
    }

    function onStop(state) {
        var s = $.gSession;
        if (s != null) {
            s.pauseClock();
            s.save();
        }
    }

    //! The menu is the root view, so Back from anywhere walks out to it and
    //! Back from the menu leaves the app - which is what the hardware button
    //! means everywhere else on the watch.
    function getInitialView() {
        return [MainMenu.build(), MainMenu.delegate()];
    }
}
