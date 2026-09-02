using Toybox.Application.Storage;
using Toybox.Lang;

//! The lifetime record, kept per difficulty.
//!
//! One storage key per tier, holding a fixed-length array. Adding a field
//! means appending to that array and defaulting it on read, which keeps an
//! existing record readable instead of resetting someone's streak.
module Stats {

    const PREFIX = "stats.";

    const STARTED = 0;
    const WON = 1;
    const BEST = 2;         // seconds; 0 for "never finished one"
    const TOTAL_TIME = 3;
    const STREAK = 4;       // consecutive wins without a hint or a mistake
    const BEST_STREAK = 5;
    const FLAWLESS = 6;     // wins with no mistake and no hint
    const FIELDS = 7;

    // Set by recordWin, read by the win screen: whether that win was a new
    // personal best. Asking after the fact is impossible, because recording
    // the win is what moves the best.
    var lastWasBest = false;

    function blank() as Lang.Array<Lang.Number> {
        var a = new Lang.Array<Lang.Number>[FIELDS];
        for (var i = 0; i < FIELDS; i++) { a[i] = 0; }
        return a;
    }

    function forTier(tier as Lang.Number) as Lang.Array<Lang.Number> {
        var v = Storage.getValue(PREFIX + tier.toString());
        if (!(v instanceof Lang.Array)) { return blank(); }
        var out = blank();
        var n = (v.size() < FIELDS) ? v.size() : FIELDS;
        for (var i = 0; i < n; i++) {
            if (v[i] instanceof Lang.Number) { out[i] = v[i]; }
        }
        return out;
    }

    function put(tier as Lang.Number, a as Lang.Array<Lang.Number>) as Void {
        Storage.setValue(PREFIX + tier.toString(), a);
    }

    function recordStart(tier) {
        var a = forTier(tier);
        a[STARTED]++;
        put(tier, a);
    }

    function recordWin(tier, seconds, mistakes, hints) {
        var a = forTier(tier);
        a[WON]++;
        a[TOTAL_TIME] += seconds;
        lastWasBest = (a[BEST] == 0 || seconds < a[BEST]);
        if (lastWasBest) { a[BEST] = seconds; }

        if (mistakes == 0 && hints == 0) {
            a[FLAWLESS]++;
            a[STREAK]++;
            if (a[STREAK] > a[BEST_STREAK]) { a[BEST_STREAK] = a[STREAK]; }
        } else {
            a[STREAK] = 0;
        }
        put(tier, a);
    }

    function best(tier) {
        return forTier(tier)[BEST];
    }

    function averageTime(tier) {
        var a = forTier(tier);
        if (a[WON] <= 0) { return 0; }
        return a[TOTAL_TIME] / a[WON];
    }

    function reset() {
        for (var t = 0; t < Difficulty.COUNT; t++) {
            Storage.deleteValue(PREFIX + t.toString());
        }
        lastWasBest = false;
    }
}
