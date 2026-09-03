using Toybox.Graphics;
using Toybox.WatchUi;

//! How to play, in two pages.
//!
//! The rules of Sudoku are not the interesting part - the controls are, and
//! specifically the two that are not guessable: that a second tap on the same
//! square is what opens the keypad, and that a swipe nudges the selection.
class HelpView extends WatchUi.View {

    hidden var layout;
    var page = 0;

    static const PAGES = [
        [
            "HOW TO PLAY",
            "Fill every row, column",
            "and 3x3 box with the",
            "digits 1 to 9, once each.",
            "",
            "Tap a square to select it.",
            "Tap it again to enter."
        ],
        [
            "CONTROLS",
            "Swipe to move one square.",
            "Start button also enters.",
            "",
            "Pencil  notes on or off",
            "Back    erase a square",
            "Arrow   undo the last move",
            "Bulb    a hint, and why"
        ]
    ];

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        layout = new Layout(dc);
    }

    function next() {
        page = (page + 1) % PAGES.size();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();

        var font = Graphics.FONT_XTINY;
        var lineH = dc.getFontHeight(font);
        var lines = PAGES[page];
        var block = lineH * lines.size();
        var top = layout.cy - block / 2;

        for (var i = 0; i < lines.size(); i++) {
            var y = top + lineH * i + lineH / 2;
            Theme.heading(dc, i == 0 ? Theme.ACCENT : Theme.TEXT,
                          layout.cx, y, font, lines[i]);
        }

        // Page dots, so it is obvious there is a second page at all.
        var r = 3;
        var gap = r * 4;
        var y = layout.h * 88 / 100;
        for (var i = 0; i < PAGES.size(); i++) {
            dc.setColor(i == page ? Theme.ACCENT : Theme.DIM,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(layout.cx + (i * 2 - 1) * gap / 2, y, r);
        }
    }
}

class HelpDelegate extends WatchUi.BehaviorDelegate {

    hidden var view;

    function initialize(helpView) {
        BehaviorDelegate.initialize();
        view = helpView;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    //! onKey, not onSelect: a real screen tap also fires the select
    //! behaviour with no coordinates, so an onSelect override here would
    //! advance the page a second time right after onTap on real Venu 2
    //! hardware. onKey(KEY_ENTER) is reached only by the physical button.
    function onKey(event as WatchUi.KeyEvent) {
        if (event.getKey() != WatchUi.KEY_ENTER) {
            return false;
        }
        view.next();
        return true;
    }

    function onTap(evt) {
        view.next();
        return true;
    }
}
