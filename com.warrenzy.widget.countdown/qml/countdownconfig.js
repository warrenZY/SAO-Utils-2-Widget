// Profile storage.
var PLUGIN = "com.warrenzy.widget.countdown";
var GROUP = "profiles";

var FONT_FALLBACK = "Source Han Sans SC";
var DEFAULT_FONT_STACK = "Open Sans, " + FONT_FALLBACK;
var DEFAULT_FONT = FONT_FALLBACK;

var FONT_WEIGHTS = [
    { label: "Thin", value: 0 },
    { label: "Extra-Light", value: 12 },
    { label: "Light", value: 25 },
    { label: "Normal", value: 50 },
    { label: "Medium", value: 57 },
    { label: "Semi-Bold", value: 63 },
    { label: "Bold", value: 75 },
    { label: "Extra-Bold", value: 81 },
    { label: "Black", value: 87 },
];

var DEFAULT_TITLE_COLOR = "#bbffffff";
var DEFAULT_VALUE_COLOR = "#bbffffff";
var DEFAULT_LINE_HEIGHT = 1.0;
var DEFAULT_STROKE_COLOR = "#000000";
var DEFAULT_STROKE_ON = false;
var DEFAULT_TITLE_SIZE = 24;
var DEFAULT_VALUE_SIZE = 24;
var DEFAULT_FONT_WEIGHT = 50;

// Windows legacy bitmap fonts. Qt can't compute glyph bearings for
// these and logs a warning on every render, then falls back silently.
// Treat them as unavailable so we don't surface them in the picker
// or bind them into a profile.
var BITMAP_FONT_NAMES = {
    "Courier": true,
    "Fixedsys": true,
    "MS Sans Serif": true,
    "MS Serif": true,
    "Modern": true,
    "Roman": true,
    "Script": true,
    "Small Fonts": true,
    "System": true,
    "Terminal": true,
};

function isUnusableFont(family) {
    return !!BITMAP_FONT_NAMES[family];
}

// Round an ISO date to the minute, so comparisons ignore the sub-minute
// component that the form never produces.
function toMinuteMs(iso) {
    if (!iso) return 0;
    var d = new Date(iso);
    if (isNaN(d.getTime())) return 0;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(),
        d.getHours(), d.getMinutes(), 0).getTime();
}

function eqLooseString(a, b) { return (a || "") === (b || ""); }
function eqColor(a, b) {
    return String(a || "").toLowerCase() === String(b || "").toLowerCase();
}
function eqStrict(a, b) { return a === b; }
function eqBool(a, b) { return !!a === !!b; }
function eqFont(a, b) {
    return (a || DEFAULT_FONT) === (b || DEFAULT_FONT);
}
function eqLineHeight(a, b) { return Math.abs(a - b) <= 1e-6; }

// Profile field map: name -> equality predicate. Single source of truth
// for both buildProfile (its key list) and snapshotDiffersFrom (its
// per-field comparison rules). Adding a field means touching this map
// plus normalizeProfile.
var PROFILE_FIELDS = {
    name: eqLooseString,
    title: eqLooseString,
    targetDate: function (a, b) { return toMinuteMs(a) === toMinuteMs(b); },
    titleSize: eqStrict,
    valueSize: eqStrict,
    titleColor: eqColor,
    valueColor: eqColor,
    strokeColor: eqColor,
    strokeEnabled: eqBool,
    fontFamily: eqFont,
    fontWeight: eqStrict,
    lineHeight: eqLineHeight,
};

// Wrap a family name in a fallback stack ending in the CJK font.
function makeFontStack(family) {
    if (!family) return DEFAULT_FONT_STACK;
    family = family.trim();
    if (!family || isUnusableFont(family)) return DEFAULT_FONT_STACK;
    if (family.indexOf(FONT_FALLBACK) >= 0) return family;
    return family + ", " + FONT_FALLBACK;
}

function newProfileId() {
    return "p_" + Date.now() + "_" + Math.floor(Math.random() * 100000);
}

function ensureConfigFile(owner) {
    var map = null;
    try {
        map = NVG.Settings.load(PLUGIN, GROUP);
    } catch (e) {
        console.warn("[countdown] settings load failed: " + e);
    }
    if (map instanceof NVG.SettingsMap) return;
    try {
        var m = NVG.Settings.createMap(owner);
        m.profiles = JSON.stringify({ profiles: [] });
        NVG.Settings.save(m, PLUGIN, GROUP);
    } catch (e) {
        console.warn("[countdown] create profiles.xml failed: " + e);
    }
}

// Return a clean copy of a profile with all fields filled in. Null
// for non-object inputs.
function normalizeProfile(p) {
    if (!p || typeof p !== "object" || Array.isArray(p)) return null;

    var out = {
        id: typeof p.id === "string" && p.id ? p.id : newProfileId(),
        name:
            typeof p.name === "string" && p.name
                ? p.name
                : "Profile " +
                (typeof p.id === "string"
                    ? p.id.slice(-5)
                    : Date.now().toString().slice(-5)),
        title: typeof p.title === "string" ? p.title : "",
        targetDate:
            typeof p.targetDate === "string" && p.targetDate
                ? p.targetDate
                : new Date(Date.now() + 86400000).toISOString(),
        titleSize:
            typeof p.titleSize === "number" && p.titleSize > 0
                ? p.titleSize
                : DEFAULT_TITLE_SIZE,
        valueSize:
            typeof p.valueSize === "number" && p.valueSize > 0
                ? p.valueSize
                : DEFAULT_VALUE_SIZE,
        titleColor:
            typeof p.titleColor === "string" && p.titleColor
                ? p.titleColor
                : DEFAULT_TITLE_COLOR,
        valueColor:
            typeof p.valueColor === "string" && p.valueColor
                ? p.valueColor
                : DEFAULT_VALUE_COLOR,
        fontWeight:
            typeof p.fontWeight === "number"
                ? p.fontWeight
                : DEFAULT_FONT_WEIGHT,
        lineHeight:
            typeof p.lineHeight === "number" ? p.lineHeight : DEFAULT_LINE_HEIGHT,
        strokeColor:
            typeof p.strokeColor === "string" && p.strokeColor
                ? p.strokeColor
                : DEFAULT_STROKE_COLOR,
        fontFamily:
            typeof p.fontFamily === "string" && p.fontFamily
                ? p.fontFamily
                : DEFAULT_FONT,
    };

    // Old format used numeric strokeWidth; map > 0 to enabled.
    if (typeof p.strokeEnabled === "boolean") out.strokeEnabled = p.strokeEnabled;
    else if (typeof p.strokeWidth === "number")
        out.strokeEnabled = p.strokeWidth > 0;
    else out.strokeEnabled = DEFAULT_STROKE_ON;

    return out;
}

// Build a full profile object from a partial snapshot with the given
// id. Missing fields fall back to defaults.
function buildProfile(id, partial) {
    var s = partial || {};
    var picked = { id: id };
    for (var k in PROFILE_FIELDS) {
        picked[k] = s[k];
    }
    return normalizeProfile(picked);
}

// Read config; salvage any well-formed profiles, drop the rest.
function loadConfig() {
    var map = null;
    try {
        map = NVG.Settings.load(PLUGIN, GROUP);
    } catch (e) {
        console.warn("[countdown] settings load failed: " + e);
    }
    var json = map && map.profiles ? String(map.profiles) : "";
    if (!json) return { profiles: [] };

    var raw = null;
    try {
        raw = JSON.parse(json);
    } catch (e) {
        console.warn("[countdown] config parse failed, resetting: " + e);
        return { profiles: [] };
    }
    if (!raw || typeof raw !== "object") return { profiles: [] };
    if (!Array.isArray(raw.profiles)) raw.profiles = [];

    var out = [];
    for (var i = 0; i < raw.profiles.length; ++i) {
        var p = normalizeProfile(raw.profiles[i]);
        if (p) out.push(p);
    }
    return { profiles: out };
}

// Write back, re-normalising every entry first.
function saveConfig(cfg, owner) {
    var map = NVG.Settings.load(PLUGIN, GROUP);
    if (!(map instanceof NVG.SettingsMap)) map = NVG.Settings.createMap(owner);

    var clean = [];
    var src = cfg && Array.isArray(cfg.profiles) ? cfg.profiles : [];
    for (var i = 0; i < src.length; ++i) {
        var p = normalizeProfile(src[i]);
        if (p) clean.push(p);
    }
    map.profiles = JSON.stringify({ profiles: clean });
    NVG.Settings.save(map, PLUGIN, GROUP);
}

// Write a batch of profiles to disk in a single read-modify-write.
// entries is { id -> snapshot }. Existing entries are replaced in
// place; unknown ids are appended. Other profiles are left untouched.
function updateProfiles(entries, owner) {
    if (!entries) return;

    var disk = null;
    for (var id in entries) {
        if (disk === null) disk = loadConfig();

        var merged = buildProfile(id, entries[id]);

        var idx = -1;
        for (var i = 0; i < disk.profiles.length; ++i) {
            if (disk.profiles[i] && disk.profiles[i].id === id) {
                idx = i;
                break;
            }
        }
        if (idx >= 0) disk.profiles[idx] = merged;
        else disk.profiles.push(merged);
    }

    if (disk !== null) saveConfig(disk, owner);
}

// Remove a single profile from disk. Unknown ids are no-ops.
function deleteProfile(id, owner) {
    var disk = loadConfig();
    var idx = -1;
    for (var i = 0; i < disk.profiles.length; ++i) {
        if (disk.profiles[i] && disk.profiles[i].id === id) {
            idx = i;
            break;
        }
    }
    if (idx < 0) return;
    disk.profiles.splice(idx, 1);
    saveConfig(disk, owner);
}

function makeDefaultProfile(name, title) {
    var d = new Date();
    d.setDate(d.getDate() + 1);
    d.setHours(0, 0, 0, 0);
    return normalizeProfile({
        id: newProfileId(),
        name: name || "Default",
        title: title || "",
        targetDate: d.toISOString(),
        titleColor: DEFAULT_TITLE_COLOR,
        valueColor: DEFAULT_VALUE_COLOR,
        lineHeight: DEFAULT_LINE_HEIGHT,
        strokeEnabled: DEFAULT_STROKE_ON,
        strokeColor: DEFAULT_STROKE_COLOR,
        fontFamily: DEFAULT_FONT,
    });
}

function findProfile(cfg, id) {
    if (!id || !cfg || !cfg.profiles) return null;
    for (var i = 0; i < cfg.profiles.length; ++i)
        if (cfg.profiles[i] && cfg.profiles[i].id === id) return cfg.profiles[i];
    return null;
}

function snapshotDiffersFrom(s, p) {
    if (!s || !p) return false;

    for (var k in PROFILE_FIELDS) {
        if (!PROFILE_FIELDS[k](s[k], p[k])) return true;
    }
    return false;
}

// Merge a freshly-loaded config with this window's pending edits.
// Returns { config, formCache, newIds } — inputs are not mutated.
// A draft for an id no longer present on disk is kept alive and
// treated as a profile this window created, so a delete in another
// window never discards the user's unsaved edits.
function mergeWindowState(freshConfig, formCache, newIds) {
    var cfg = { profiles: (freshConfig.profiles || []).slice() };
    var cache = {};

    var nn = {};
    for (var k in newIds) nn[k] = newIds[k];

    // Rebuild profiles this window created but never persisted, so a
    // hub reload does not drop them.
    for (var nid in nn) {
        if (!findProfile(cfg, nid) && formCache[nid])
            cfg.profiles.push(buildProfile(nid, formCache[nid]));
    }

    // Keep drafts that still differ from config; drop the rest. Profiles
    // this window created stay in the cache until they are saved.
    for (var id in formCache) {
        if (nn[id]) { cache[id] = formCache[id]; continue; }
        var p = findProfile(cfg, id);
        if (p && snapshotDiffersFrom(formCache[id], p)) {
            cache[id] = formCache[id];
        } else if (!p) {
            // Profile vanished from disk, but this window still has an
            // unsaved edit for it. Keep the draft and re-adopt it as a
            // local creation so the edit survives the deletion.
            cache[id] = formCache[id];
            nn[id] = true;
            cfg.profiles.push(buildProfile(id, formCache[id]));
        }
    }

    return { config: cfg, formCache: cache, newIds: nn };
}

// Sorted, deduplicated system font families, cached for the life of
// the engine. The default font is always first.
var _fontCache = null;
function allFontFamilies() {
    if (_fontCache) return _fontCache;

    var sys = [];
    try { sys = Qt.fontFamilies(); } catch (e) { }

    var seen = {};
    var result = [];
    if (DEFAULT_FONT) {
        result.push(DEFAULT_FONT);
        seen[DEFAULT_FONT] = true;
    }

    var others = [];
    for (var i = 0; i < sys.length; ++i) {
        var n = sys[i];
        if (!n || typeof n !== "string") continue;
        n = n.trim();
        if (!n || seen[n]) continue;
        if (isUnusableFont(n)) continue;
        seen[n] = true;
        others.push(n);
    }
    others.sort(function (a, b) { return a.localeCompare(b); });
    for (var j = 0; j < others.length; ++j) result.push(others[j]);

    _fontCache = result;
    return _fontCache;
}