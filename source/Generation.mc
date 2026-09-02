using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Lang;

//! Drives the generator behind Garmin's ProgressBar.
//!
//! The work is real - a few hundred solver runs - so it cannot happen in the
//! callback that starts it. A timer pulls one slice per tick, which keeps the
//! watch responsive and lets the bar actually move. `ProgressBar` is the
//! platform's own busy screen, so this looks like the watch syncing rather
//! than like a game hanging.
//!
//! The instance is parked in a module variable for the duration. A Timer with
//! no live reference to its owner is a collected object with a pending
//! callback, and that is a crash rather than a slow puzzle.
module Generation {

    const STEP_MS = 25;

    var current = null;

    function begin(tier) {
        current = new GenerationRun(tier);
        current.start();
    }

    function finished() {
        current = null;
    }

    //! Abandon a run in progress. Stopping the timer is the point: a
    //! forgotten timer would keep stepping and eventually push a board the
    //! player has already walked away from.
    function cancel() {
        if (current != null) {
            current.cancel();
            current = null;
        }
    }
}

class GenerationRun {

    hidden var generator;
    hidden var bar;
    hidden var timer;
    hidden var tier;

    function initialize(tierIndex) {
        tier = tierIndex;
        generator = new Generator(tierIndex);
    }

    function start() {
        bar = new WatchUi.ProgressBar(Difficulty.name(tier), 0.0);
        WatchUi.pushView(bar, new GenerationDelegate(), WatchUi.SLIDE_UP);
        timer = new Timer.Timer();
        timer.start(method(:onStep), Generation.STEP_MS, true);
    }

    function cancel() {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
    }

    function onStep() as Void {
        var pct = generator.step();
        if (!generator.isDone()) {
            bar.setProgress(pct.toFloat());
            return;
        }

        timer.stop();
        timer = null;
        bar.setProgress(100.0);

        var session = $.gSession;
        session.start(tier, generator.result(), generator.solution);

        // switchToView replaces the progress bar rather than stacking on top
        // of it, so Back from the board goes to the main menu and never
        // returns to a finished progress screen.
        var v = new BoardView();
        WatchUi.switchToView(v, new BoardDelegate(v), WatchUi.SLIDE_LEFT);
        Generation.finished();
    }
}

//! Back during generation abandons it. Without this the player is stuck
//! watching a bar they did not mean to start.
class GenerationDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() {
        Generation.cancel();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
