using Toybox.WatchUi;
using Toybox.Timer;

//! One reusable accept/decline handler.
//!
//! `WatchUi.Confirmation` is the platform's yes/no screen, so a destructive
//! action in this app asks the same way, in the same place on the glass, as
//! deleting an activity does. This delegate just routes the answer to a
//! `method(:name)` callback, which keeps every caller down to two lines.
class Confirm extends WatchUi.ConfirmationDelegate {

    hidden var onYes;
    hidden var deferred;    // kept referenced so it isn't collected mid-flight

    function initialize(callback) {
        ConfirmationDelegate.initialize();
        onYes = callback;
    }

    function onResponse(response) {
        if (response != WatchUi.CONFIRM_YES) { return true; }
        // The native Confirmation view dismisses itself right after this
        // callback returns. Calling `onYes` synchronously here - when it
        // pushes a new view, as chooseDifficulty does - races that
        // self-dismissal: on real Venu 2 hardware the dismissal pops
        // whatever is now on top rather than specifically itself, so the
        // view `onYes` just pushed gets popped immediately, before the
        // player ever sees it. A one-shot timer runs `onYes` on the next
        // tick instead, after the dismissal has already happened.
        deferred = new Timer.Timer();
        deferred.start(method(:runYes), 1, false);
        return true;
    }

    function runYes() as Void {
        onYes.invoke();
    }
}

module Ask {
    //! Put `question` to the player; run `callback` only on yes.
    function confirm(question, callback) {
        // SLIDE_IMMEDIATE on a native Confirmation view has shown up broken
        // on real hardware elsewhere in these apps - the dialog draws but
        // never accepts a response. Every other confirm in garmin-apps/*
        // uses SLIDE_UP, which works.
        WatchUi.pushView(new WatchUi.Confirmation(question),
                         new Confirm(callback),
                         WatchUi.SLIDE_UP);
    }
}
