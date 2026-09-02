using Toybox.WatchUi;
using Toybox.Lang;

//! Every list screen in the app, on Garmin's own Menu2.
//!
//! A hand-drawn list would have to reinvent scrolling, momentum, the
//! selection highlight and the title band, and would still feel unlike the
//! rest of the watch. Menu2 gets all of that for free and matches the system
//! menus the player already knows.

//! The app's home screen.
module MainMenu {

    function build() {
        var menu = new WatchUi.Menu2({:title => "Sudoku"});
        var s = $.gSession;

        if (s != null && s.hasGame()) {
            menu.addItem(new WatchUi.MenuItem(
                "Continue",
                Difficulty.name(s.tier) + "  " + Fmt.clock(s.elapsed),
                :continueGame, {}));
        }
        menu.addItem(new WatchUi.MenuItem("New Puzzle", null, :newGame, {}));
        menu.addItem(new WatchUi.MenuItem("Record", null, :stats, {}));
        menu.addItem(new WatchUi.MenuItem("Settings", null, :settings, {}));
        menu.addItem(new WatchUi.MenuItem("How to Play", null, :help, {}));
        return menu;
    }

    function delegate() {
        return new MainMenuDelegate();
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :continueGame) {
            openBoard();
        } else if (id == :newGame) {
            var s = $.gSession;
            if (s != null && s.hasGame()) {
                // Starting a new puzzle throws the current one away, and the
                // only warning a player gets is this one.
                Ask.confirm("Abandon the puzzle\nin progress?", method(:chooseDifficulty));
            } else {
                chooseDifficulty();
            }
        } else if (id == :stats) {
            WatchUi.pushView(new StatsView(), new PopDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :settings) {
            SettingsMenu.push();
        } else if (id == :help) {
            var help = new HelpView();
            WatchUi.pushView(help, new HelpDelegate(help), WatchUi.SLIDE_LEFT);
        }
    }

    function chooseDifficulty() {
        DifficultyMenu.push();
    }

    hidden function openBoard() {
        var v = new BoardView();
        WatchUi.pushView(v, new BoardDelegate(v), WatchUi.SLIDE_LEFT);
    }
}

//! Pick a tier. Each row carries what the tier actually promises and what the
//! player has managed on it so far, so the choice is informed rather than a
//! guess at what "Hard" means in this particular app.
module DifficultyMenu {

    function push() {
        var menu = new WatchUi.Menu2({:title => "Difficulty"});
        for (var t = 0; t < Difficulty.COUNT; t++) {
            var best = Stats.best(t);
            var sub = Difficulty.blurb(t);
            if (best > 0) { sub = sub + "  best " + Fmt.clock(best); }
            menu.addItem(new WatchUi.MenuItem(Difficulty.name(t), sub, t, {}));
        }
        WatchUi.pushView(menu, new DifficultyMenuDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class DifficultyMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var tier = item.getId();
        if (!(tier instanceof Lang.Number)) { return; }
        // Drop this menu first, so that when generation finishes the board
        // replaces the progress bar and Back from the board lands on the
        // main menu rather than back here.
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        Generation.begin(tier);
    }
}

//! The settings list. Every entry is a toggle, and every toggle is written
//! straight through to storage - there is no "save" step to forget.
module SettingsMenu {

    function push() {
        var menu = new WatchUi.Menu2({:title => "Settings"});
        add(menu, "Highlight", "Row, column, box", :highlightPeers);
        add(menu, "Flag Mistakes", "As soon as they happen", :showMistakes);
        add(menu, "Tidy Notes", "Clear marks on entry", :autoNotes);
        add(menu, "Timer", "Show while playing", :showTimer);
        add(menu, "Vibration", null, :haptics);
        menu.addItem(new WatchUi.MenuItem("Clear Record", "All difficulties", :reset, {}));
        WatchUi.pushView(menu, new SettingsMenuDelegate(), WatchUi.SLIDE_LEFT);
    }

    function add(menu, label, sub, key) {
        menu.addItem(new WatchUi.ToggleMenuItem(label, sub, key, Prefs.get(key), {}));
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :reset) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            Ask.confirm("Erase every best time\nand streak?", method(:doReset));
            return;
        }
        Prefs.toggle(id);
        // Menu2 has already flipped the item's own checkbox; this keeps the
        // stored value and the drawn state in agreement even if a toggle is
        // ever rejected.
        if (item instanceof WatchUi.ToggleMenuItem) {
            item.setEnabled(Prefs.get(id));
        }
    }

    function doReset() {
        Stats.reset();
    }
}

//! For screens that have nothing to handle but Back.
class PopDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
