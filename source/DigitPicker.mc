using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Lang;

//! Digit entry, on Garmin's own picker.
//!
//! `WatchUi.PickerFactory` is the platform's number-entry component: the same
//! carousel, arrows and confirm button the watch uses for a target pace or an
//! alarm time, with the system's own scrolling feel and its accessibility
//! behaviour. Drawing a bespoke keypad would mean nine 30px targets on a
//! round screen, and it would feel like someone else's app.
class DigitFactory extends WatchUi.PickerFactory {

    hidden var font;

    function initialize(cellFont) {
        PickerFactory.initialize();
        font = cellFont;
    }

    function getSize() {
        return 9;
    }

    function getValue(index) {
        return index + 1;
    }

    //! The index a digit sits at, for `:defaults` - so reopening the picker
    //! on a filled cell starts on the digit already there rather than at 1.
    function indexOf(value) {
        if (value == null || value < 1 || value > 9) { return 0; }
        return value - 1;
    }

    function getDrawable(index, selected) {
        return new WatchUi.Text({
            :text => (index + 1).toString(),
            :color => selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            :font => font,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}

class DigitPicker extends WatchUi.Picker {

    function initialize(titleText, current) {
        var factory = new DigitFactory(Graphics.FONT_NUMBER_MEDIUM);
        var title = new WatchUi.Text({
            :text => titleText,
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_XTINY,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        Picker.initialize({
            :title => title,
            :pattern => [factory],
            :defaults => [factory.indexOf(current)]
        });
    }

    function onUpdate(dc) {
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

//! Hands the chosen digit back to whoever opened the picker. The callback is
//! a `method(:name)` on the board delegate, so the picker itself knows
//! nothing about notes mode, mistakes or the board.
class DigitPickerDelegate extends WatchUi.PickerDelegate {

    hidden var onChosen;

    function initialize(callback) {
        PickerDelegate.initialize();
        onChosen = callback;
    }

    function onAccept(values) {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        var v = values[0];
        if (v instanceof Lang.Number) { onChosen.invoke(v); }
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
