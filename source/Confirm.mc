using Toybox.WatchUi;

//! One reusable accept/decline handler.
//!
//! `WatchUi.Confirmation` is the platform's yes/no screen, so a destructive
//! action in this app asks the same way, in the same place on the glass, as
//! deleting an activity does. This delegate just routes the answer to a
//! `method(:name)` callback, which keeps every caller down to two lines.
class Confirm extends WatchUi.ConfirmationDelegate {

    hidden var onYes;

    function initialize(callback) {
        ConfirmationDelegate.initialize();
        onYes = callback;
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            onYes.invoke();
        }
        return true;
    }
}

module Ask {
    //! Put `question` to the player; run `callback` only on yes.
    function confirm(question, callback) {
        WatchUi.pushView(new WatchUi.Confirmation(question),
                         new Confirm(callback),
                         WatchUi.SLIDE_IMMEDIATE);
    }
}
