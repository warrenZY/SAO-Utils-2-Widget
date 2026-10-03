// countdownconfig.js - profile storage; must not use .pragma library

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

function makeFontStack(family) {
  if (!family || typeof family !== "string") return DEFAULT_FONT_STACK;
  family = family.trim();
  if (!family) return DEFAULT_FONT_STACK;
  if (family.indexOf(FONT_FALLBACK) >= 0) return family;
  return family + ", " + FONT_FALLBACK;
}

function defaultFontFamily() {
  return DEFAULT_FONT;
}

function newProfileId() {
  return "p_" + Date.now() + "_" + Math.floor(Math.random() * 100000);
}

function ensureConfigFile(owner) {
  var map = null;
  try {
    map = NVG.Settings.load(PLUGIN, GROUP);
  } catch (e) {}
  if (map instanceof NVG.SettingsMap) return;
  try {
    var m = NVG.Settings.createMap(owner);
    m.profiles = JSON.stringify({ profiles: [] });
    NVG.Settings.save(m, PLUGIN, GROUP);
  } catch (e) {
    console.warn("[countdown] create profiles.xml failed: " + e);
  }
}

// Sanitize a single raw object into a well-formed profile.
// Returns null if the input is not a plain object.
function normalizeProfile(p) {
  if (!p || typeof p !== "object" || Array.isArray(p)) return null;

  var out = {
    id: typeof p.id === "string" && p.id ? p.id : newProfileId(),
    name: typeof p.name === "string" && p.name ? p.name : "Profile",
    title: typeof p.title === "string" ? p.title : "",
    targetDate:
      typeof p.targetDate === "string" && p.targetDate
        ? p.targetDate
        : new Date(Date.now() + 86400000).toISOString(),
    titleSize:
      typeof p.titleSize === "number" && p.titleSize > 0 ? p.titleSize : 24,
    valueSize:
      typeof p.valueSize === "number" && p.valueSize > 0 ? p.valueSize : 24,
    titleColor:
      typeof p.titleColor === "string" && p.titleColor
        ? p.titleColor
        : DEFAULT_TITLE_COLOR,
    valueColor:
      typeof p.valueColor === "string" && p.valueColor
        ? p.valueColor
        : DEFAULT_VALUE_COLOR,
    fontWeight: typeof p.fontWeight === "number" ? p.fontWeight : 50,
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

  // Migrate legacy numeric strokeWidth into a boolean flag.
  if (typeof p.strokeEnabled === "boolean") out.strokeEnabled = p.strokeEnabled;
  else if (typeof p.strokeWidth === "number")
    out.strokeEnabled = p.strokeWidth > 0;
  else out.strokeEnabled = DEFAULT_STROKE_ON;

  return out;
}

// Reads config; tolerates partial corruption by salvaging valid profiles.
function loadConfig() {
  var map = null;
  try {
    map = NVG.Settings.load(PLUGIN, GROUP);
  } catch (e) {}
  var json = map && map.profiles ? String(map.profiles) : "";
  if (!json) return { profiles: [] };

  var raw = null;
  try {
    raw = JSON.parse(json);
  } catch (e) {
    console.warn("[countdown] config parse failed, starting clean: " + e);
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

function saveConfig(cfg, owner) {
  var map = NVG.Settings.load(PLUGIN, GROUP);
  if (!(map instanceof NVG.SettingsMap)) map = NVG.Settings.createMap(owner);

  // Always re-emit a clean array of normalized profiles.
  var clean = [];
  var src = cfg && Array.isArray(cfg.profiles) ? cfg.profiles : [];
  for (var i = 0; i < src.length; ++i) {
    var p = normalizeProfile(src[i]);
    if (p) clean.push(p);
  }
  map.profiles = JSON.stringify({ profiles: clean });
  NVG.Settings.save(map, PLUGIN, GROUP);
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
