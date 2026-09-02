using Toybox.Attention;

//! Feedback you can feel. Every call is guarded twice - by the player's
//! setting, and by `has`, because vibration and tones are optional hardware
//! and the do-not-disturb state can withdraw them at any moment.
module Haptics {

    function pulse(strength, ms) {
        if (!Prefs.haptics) { return; }
        if (Attention has :vibrate && Attention has :VibeProfile) {
            try {
                Attention.vibrate([new Attention.VibeProfile(strength, ms)]);
            } catch (e) {
                // No vibration motor, or the system has taken it away. The
                // visual feedback stands on its own.
            }
        }
    }

    function tap()     { pulse(20, 40); }
    function mistake() { pulse(75, 150); }
    function hint()    { pulse(40, 80); }

    function win() {
        if (!Prefs.haptics) { return; }
        if (Attention has :vibrate && Attention has :VibeProfile) {
            try {
                Attention.vibrate([
                    new Attention.VibeProfile(50, 120),
                    new Attention.VibeProfile(0, 80),
                    new Attention.VibeProfile(100, 300)
                ]);
            } catch (e) {
            }
        }
    }
}
