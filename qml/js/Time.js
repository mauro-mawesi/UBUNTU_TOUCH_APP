.pragma library

// Lightweight time helpers — kept here (not in I18nData) so the strings
// stay co-located with the formatting logic and load fast.

var _STRINGS = {
    en: { now: "now", minAgo: "%1 min ago", hourAgo: "%1h ago",
          yesterday: "yesterday",
          buckets: { today: "Today", yesterday: "Yesterday", week: "Last 7 days", older: "Older" } },
    es: { now: "ahora", minAgo: "hace %1 min", hourAgo: "hace %1 h",
          yesterday: "ayer",
          buckets: { today: "Hoy", yesterday: "Ayer", week: "Últimos 7 días", older: "Anterior" } },
    nl: { now: "nu", minAgo: "%1 min geleden", hourAgo: "%1 u geleden",
          yesterday: "gisteren",
          buckets: { today: "Vandaag", yesterday: "Gisteren", week: "Afgelopen 7 dagen", older: "Ouder" } }
};

var _MONTHS = {
    en: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
    es: ["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"],
    nl: ["jan","feb","mrt","apr","mei","jun","jul","aug","sep","okt","nov","dec"]
};

function _s(lang) {
    if (lang === "es" || lang === "nl") return _STRINGS[lang];
    return _STRINGS.en;
}
function _m(lang) {
    if (lang === "es" || lang === "nl") return _MONTHS[lang];
    return _MONTHS.en;
}
function _pad(n) { return n < 10 ? "0" + n : "" + n; }

function _midnight(date) {
    var d = new Date(date.getTime());
    d.setHours(0, 0, 0, 0);
    return d.getTime();
}

// "now" / "hace N min" / "hace N h" / "ayer" / "dd mmm" / "dd mmm yyyy"
function relativeShort(ts, lang) {
    if (!ts || ts <= 0) return "";
    var s = _s(lang);
    var now = Date.now();
    var diffMs = now - ts;
    if (diffMs < 60 * 1000) return s.now;
    if (diffMs < 60 * 60 * 1000) {
        var m = Math.floor(diffMs / 60000);
        return s.minAgo.replace("%1", m);
    }
    if (diffMs < 24 * 60 * 60 * 1000) {
        var h = Math.floor(diffMs / 3600000);
        return s.hourAgo.replace("%1", h);
    }
    var todayMid = _midnight(new Date());
    var dayMid = _midnight(new Date(ts));
    var daysAgo = Math.round((todayMid - dayMid) / (24 * 60 * 60 * 1000));
    if (daysAgo === 1) return s.yesterday;
    var d = new Date(ts);
    var months = _m(lang);
    var sameYear = d.getFullYear() === new Date().getFullYear();
    var base = _pad(d.getDate()) + " " + months[d.getMonth()];
    return sameYear ? base : base + " " + d.getFullYear();
}

// Discretizes a timestamp into one of four buckets used by the sidebar.
function dateBucket(ts, lang) {
    var s = _s(lang);
    if (!ts || ts <= 0) return s.buckets.older;
    var todayMid = _midnight(new Date());
    var dayMid = _midnight(new Date(ts));
    var daysAgo = Math.round((todayMid - dayMid) / (24 * 60 * 60 * 1000));
    if (daysAgo <= 0) return s.buckets.today;
    if (daysAgo === 1) return s.buckets.yesterday;
    if (daysAgo <= 7) return s.buckets.week;
    return s.buckets.older;
}

// HH:mm for tooltips / message metadata.
function clock(ts) {
    if (!ts || ts <= 0) return "";
    var d = new Date(ts);
    return _pad(d.getHours()) + ":" + _pad(d.getMinutes());
}
