using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;

//! Input for the board.
//!
//! Two ways to reach a square, because one is not enough on a 30px grid:
//!
//!   tap    coarse and fast. The first tap on a square selects it; a tap on
//!          the square that is *already* selected opens the digit picker.
//!          That second tap is what makes a mis-hit free - you see where you
//!          landed before anything is entered.
//!   swipe  fine, vertical only. A swipe up or down nudges the selection one
//!          row, so correcting a mis-hit never means aiming at the same 30px
//!          target again.
//!   drag   fine, horizontal only. A held finger dragged left or right steps
//!          the selection one column per DRAG_STEP_PX of travel. Horizontal
//!          movement can't use swipe the way vertical does: on real Venu 2
//!          hardware a left-to-right swipe never reaches onSwipe at all - the
//!          system consumes it entirely as the back gesture and pops this
//!          view, dead on arrival regardless of anything this delegate does.
//!          A drag is a different, lower-level input (continuous position
//!          while held, not a quick flick-and-release) and isn't claimed by
//!          that gesture, which is what makes it usable here instead.
//!
//! The start button opens the picker for the current square, so the whole
//! game is playable without touching the screen at all.
class BoardDelegate extends WatchUi.BehaviorDelegate {

    // How far (in pixels) a drag has to travel past its last step before it
    // steps the selection another column. Small enough to feel responsive,
    // large enough that the drag's own start jitter can't fire it by
    // accident.
    const DRAG_STEP_PX = 20;

    hidden var view;
    hidden var dragOriginX;
    hidden var dragOriginY;

    function initialize(boardView) {
        BehaviorDelegate.initialize();
        view = boardView;
        dragOriginX = null;
    }

    hidden function session() as Session? {
        return $.gSession;
    }

    // --- touch -----------------------------------------------------------

    function onTap(evt) {
        var s = session();
        if (s == null || s.entries == null) { return false; }
        var layout = view.getLayout();
        if (layout == null) { return false; }

        var c = evt.getCoordinates();
        var x = c[0];
        var y = c[1];

        var zone = layout.zoneAt(x, y);
        if (zone >= 0) {
            onZone(zone);
            return true;
        }

        var cell = layout.cellAt(x, y);
        if (cell >= 0) {
            if (cell == s.selected) {
                openPicker();
            } else {
                s.selected = cell;
                view.refresh();
            }
            return true;
        }
        return true;
    }

    function onSwipe(evt) {
        var s = session();
        if (s == null || s.selected < 0) { return true; }
        var d = evt.getDirection();
        var r = Cells.row(s.selected);

        // Horizontal is handled by onDrag instead - see the class comment.
        if (d == WatchUi.SWIPE_UP && r > 0) { r--; }
        else if (d == WatchUi.SWIPE_DOWN && r < 8) { r++; }
        else { return true; }

        s.selected = r * 9 + Cells.col(s.selected);
        view.refresh();
        return true;
    }

    function onDrag(evt) {
        var s = session();
        if (s == null || s.selected < 0) { return true; }
        var type = evt.getType();

        if (type == WatchUi.DRAG_TYPE_STOP) {
            dragOriginX = null;
            return true;
        }

        var xy = evt.getCoordinates();
        var x = xy[0];
        var y = xy[1];

        if (type == WatchUi.DRAG_TYPE_START || dragOriginX == null) {
            dragOriginX = x;
            dragOriginY = y;
            return true;
        }

        var dx = x - dragOriginX;
        var dy = y - dragOriginY;
        // Not a clear enough horizontal move yet - a vertical drag is left
        // for onSwipe, and a short jitter isn't a deliberate step.
        if (dx.abs() < DRAG_STEP_PX || dx.abs() < dy.abs()) { return true; }

        var c = Cells.col(s.selected);
        if (dx > 0 && c < 8) { c++; }
        else if (dx < 0 && c > 0) { c--; }

        // Re-baseline here regardless of whether the column actually moved,
        // so holding a drag at the left/right edge doesn't leave a huge
        // accumulated dx that steps several columns the instant there is
        // room to.
        dragOriginX = x;
        dragOriginY = y;

        s.selected = Cells.row(s.selected) * 9 + c;
        view.refresh();
        return true;
    }

    // --- buttons ---------------------------------------------------------

    //! Hangs off the raw key event, not onSelect: on real Venu 2 hardware a
    //! screen tap also arrives as the select behaviour, with no coordinates.
    //! An onSelect override opened the picker again after every real tap -
    //! for whichever cell was already selected, regardless of where the
    //! finger actually landed - which is why every tap looked like it always
    //! targeted the current cell. onKey(KEY_ENTER) is reached only by the
    //! physical select button, so the two gestures stay apart. (See the same
    //! fix in the foundry app's GameDelegate.)
    function onKey(event as WatchUi.KeyEvent) {
        if (event.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }
        openPicker();
        return true;
    }

    function onMenu() {
        var menu = new WatchUi.Menu2({:title => "Puzzle"});
        menu.addItem(new WatchUi.MenuItem("Erase All", "Keep the clues", :eraseAll, {}));
        menu.addItem(new WatchUi.MenuItem("Settings", null, :settings, {}));
        menu.addItem(new WatchUi.MenuItem("How to Play", null, :help, {}));
        menu.addItem(new WatchUi.MenuItem("Quit", "Progress is saved", :quit, {}));
        WatchUi.pushView(menu, new BoardMenuDelegate(view), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() {
        var s = session();
        if (s != null) { s.save(); }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // --- the action bar --------------------------------------------------

    hidden function onZone(zone as Lang.Number) as Void {
        var s = session();
        if (s == null) { return; }
        if (zone == 0) {
            s.noteMode = !s.noteMode;
            Haptics.tap();
            view.refresh();
        } else if (zone == 1) {
            if (s.selected >= 0 && s.erase(s.selected)) {
                Haptics.tap();
                view.refresh();
            }
        } else if (zone == 2) {
            if (s.undo()) {
                Haptics.tap();
                view.refresh();
            }
        } else {
            // A hint is the one action with a cost attached - it goes on the
            // record - so it is the one that asks first.
            Ask.confirm("Use a hint?", method(:giveHint));
        }
    }

    hidden function openPicker() as Void {
        var s = session();
        if (s == null || s.selected < 0 || s.isGiven(s.selected) || s.complete) {
            return;
        }
        var entries = s.entries;
        if (entries == null) { return; }
        var title = s.noteMode ? "Pencil mark" : "Enter digit";
        var picker = new DigitPicker(title, entries[s.selected]);
        WatchUi.pushView(picker,
                         new DigitPickerDelegate(method(:onDigit)),
                         WatchUi.SLIDE_IMMEDIATE);
    }

    //! The picker's answer.
    function onDigit(d) {
        var s = session();
        if (s == null || s.selected < 0) { return; }

        if (s.noteMode) {
            s.toggleNote(s.selected, d);
            Haptics.tap();
            view.refresh();
            return;
        }

        var result = s.place(s.selected, d);
        if (result == :won) {
            Haptics.win();
            view.refresh();
            WatchUi.pushView(new WinView(), new WinDelegate(), WatchUi.SLIDE_UP);
            return;
        }
        if (result == :wrong && Prefs.showMistakes) {
            Haptics.mistake();
        } else {
            Haptics.tap();
        }
        // Move on to the next empty square: on a watch, re-aiming for every
        // digit is most of the work, and the next blank is nearly always
        // where the player was going anyway.
        advance(s);
        view.refresh();
    }

    hidden function advance(s as Session) as Void {
        var entries = s.entries;
        if (entries == null) { return; }
        for (var n = 1; n <= Cells.N; n++) {
            var i = (s.selected + n) % Cells.N;
            if (entries[i] == 0) {
                s.selected = i;
                return;
            }
        }
    }

    //! Confirmed from the action bar. Explains itself rather than just
    //! filling a square - a hint that teaches the technique is worth more
    //! than one that hands over a digit.
    function giveHint() {
        var s = session();
        if (s == null || s.complete) { return; }
        var hint = Logic.nextHint(s.entries, s.solution);
        var kind = hint.get(:kind);
        if (kind == Logic.HINT_NONE) { return; }

        var note;
        if (kind == Logic.HINT_WRONG) {
            note = "Wrong digit here";
        } else if (kind == Logic.HINT_NAKED) {
            note = "Only one digit fits";
        } else if (kind == Logic.HINT_HIDDEN) {
            note = unitWord(hint.get(:unit)) + " needs a "
                   + hint.get(:digit).toString();
        } else {
            note = "No simple step left";
        }

        s.applyHint(hint);
        Haptics.hint();
        view.refresh();
        view.highlight(hint.get(:cell), note);

        if (s.complete) {
            WatchUi.pushView(new WinView(), new WinDelegate(), WatchUi.SLIDE_UP);
        }
    }

    hidden function unitWord(u) {
        if (u < 9) { return "This row"; }
        if (u < 18) { return "This column"; }
        return "This box";
    }
}

//! The board's own menu. Kept separate from the main menu because the
//! actions here only make sense with a puzzle open.
class BoardMenuDelegate extends WatchUi.Menu2InputDelegate {

    hidden var view;

    function initialize(boardView) {
        Menu2InputDelegate.initialize();
        view = boardView;
    }

    function onSelect(item) {
        var id = item.getId();
        // Close the menu before acting. Every branch below either puts
        // something else on screen or returns to the board, and a menu left
        // underneath would be waiting there afterwards.
        WatchUi.popView(WatchUi.SLIDE_DOWN);

        if (id == :eraseAll) {
            Ask.confirm("Erase everything you\nentered?", method(:doEraseAll));
        } else if (id == :settings) {
            SettingsMenu.push();
        } else if (id == :help) {
            var help = new HelpView();
            WatchUi.pushView(help, new HelpDelegate(help), WatchUi.SLIDE_LEFT);
        } else if (id == :quit) {
            var s = $.gSession;
            if (s != null) { s.save(); }
            WatchUi.popView(WatchUi.SLIDE_RIGHT);    // the board
        }
    }

    function doEraseAll() {
        var s = $.gSession;
        if (s != null) { s.eraseAll(); }
        view.refresh();
    }
}
