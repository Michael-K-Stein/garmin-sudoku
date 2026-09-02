using Toybox.Lang;

module Fmt {

    //! A duration as m:ss, or h:mm:ss once it runs past an hour. A puzzle
    //! that took 4 minutes should not read "00:04:07".
    function clock(seconds) {
        if (seconds < 0) { seconds = 0; }
        var h = seconds / 3600;
        var m = (seconds / 60) % 60;
        var s = seconds % 60;
        if (h > 0) {
            return h.toString() + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.toString() + ":" + s.format("%02d");
    }

    //! The same, but "-" for "never finished one of these".
    function clockOrDash(seconds) {
        if (seconds == null || seconds <= 0) { return "-"; }
        return clock(seconds);
    }

    function percent(part, whole) {
        if (whole <= 0) { return "0%"; }
        return (part * 100 / whole).toString() + "%";
    }

    function plural(n, one, many) {
        return n.toString() + " " + (n == 1 ? one : many);
    }
}
