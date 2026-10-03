// i18n.js - locale-aware string lookup

var _cachedLang = null;

function currentLang() {
  if (_cachedLang) return _cachedLang;
  var name = "en";
  try {
    name = Qt.locale().name.toLowerCase();
  } catch (e) {}
  if (name.indexOf("zh") === 0) _cachedLang = "zh";
  else if (name.indexOf("ja") === 0) _cachedLang = "ja";
  else _cachedLang = "en";
  return _cachedLang;
}

var STRINGS = {
  en: {
    "action.title": "Open Countdown Settings",
    "settings.title": "Countdown Settings",
    "settings.profile": "Profile",
    "settings.profileName": "Profile Name",
    "settings.newProfile": "New Profile %1",
    "settings.noProfile": "(No valid profile)",
    "settings.unsaved": " (unsaved)",
    "settings.font": "Font",
    "settings.fontWeight": "Weight",
    "settings.lineHeight": "Line Height",
    "settings.stroke": "Stroke",
    "settings.strokeEnabled": "Enable Stroke",
    "settings.strokeColor": "Color",
    "settings.fontSearch": "Type to search fonts...",
    "settings.fontCurrent": "Current: %1",
    "settings.label.title": "Countdown Title",
    "settings.placeholder": "e.g. Distance to 2027 exam",
    "settings.label.date": "Target Date (Y - M - D)",
    "settings.label.time": "Target Time (H : M)",
    "settings.short.title": "Title",
    "settings.short.value": "Countdown",
    "settings.apply": "Save and Apply",
    "settings.save": "Save and Close",
    "settings.saved": "Settings saved.",
    "settings.applied": "Settings applied.",
    "data.defaultTitle": "Distance to target",
    "data.defaultTitleTomorrow": "Distance to tomorrow",
    "data.notSet": "Not set",
    "data.timesUp": "Time's up!",
    "unit.day": "d",
    "unit.hour": "h",
    "unit.min": "m",
    "unit.sec": "s",
  },
  zh: {
    "action.title": "打开倒计时设置",
    "settings.title": "倒计时设置",
    "settings.profile": "配置",
    "settings.profileName": "配置名称",
    "settings.newProfile": "新配置 %1",
    "settings.noProfile": "（无有效配置）",
    "settings.unsaved": "（未保存）",
    "settings.font": "字体",
    "settings.fontWeight": "字重",
    "settings.lineHeight": "行高",
    "settings.stroke": "描边",
    "settings.strokeEnabled": "启用描边",
    "settings.strokeColor": "颜色",
    "settings.fontSearch": "输入以搜索字体...",
    "settings.fontCurrent": "当前：%1",
    "settings.label.title": "倒计时标题",
    "settings.placeholder": "例如：距离2027考研还有",
    "settings.label.date": "目标日期（年 - 月 - 日）",
    "settings.label.time": "目标时间（时 : 分）",
    "settings.short.title": "标题",
    "settings.short.value": "倒计时",
    "settings.apply": "保存并应用",
    "settings.save": "保存并关闭",
    "settings.saved": "设置已保存。",
    "settings.applied": "设置已应用。",
    "data.defaultTitle": "距离目标还有",
    "data.defaultTitleTomorrow": "距离明天还有",
    "data.notSet": "未设置目标",
    "data.timesUp": "时间到！",
    "unit.day": "天",
    "unit.hour": "小时",
    "unit.min": "分钟",
    "unit.sec": "秒",
  },
  ja: {
    "action.title": "カウントダウン設定を開く",
    "settings.title": "カウントダウン設定",
    "settings.profile": "プロファイル",
    "settings.profileName": "プロファイル名",
    "settings.newProfile": "新しいプロファイル %1",
    "settings.noProfile": "（有効なプロファイルなし）",
    "settings.unsaved": "（未保存）",
    "settings.font": "フォント",
    "settings.fontWeight": "ウェイト",
    "settings.lineHeight": "行の高さ",
    "settings.stroke": "ストローク",
    "settings.strokeEnabled": "ストロークを有効化",
    "settings.strokeColor": "色",
    "settings.fontSearch": "入力して検索...",
    "settings.fontCurrent": "現在：%1",
    "settings.label.title": "カウントダウンタイトル",
    "settings.placeholder": "例：2027年試験まで",
    "settings.label.date": "目標日付（年 - 月 - 日）",
    "settings.label.time": "目標時刻（時 : 分）",
    "settings.short.title": "タイトル",
    "settings.short.value": "カウントダウン",
    "settings.apply": "保存して適用",
    "settings.save": "保存して閉じる",
    "settings.saved": "設定を保存しました。",
    "settings.applied": "設定を適用しました。",
    "data.defaultTitle": "目標まで",
    "data.defaultTitleTomorrow": "明日まで",
    "data.notSet": "未設定",
    "data.timesUp": "時間です！",
    "unit.day": "日",
    "unit.hour": "時間",
    "unit.min": "分",
    "unit.sec": "秒",
  },
};

function t(key) {
  var dict = STRINGS[currentLang()] || STRINGS["en"];
  return dict[key] || STRINGS["en"][key] || key;
}

function tf(key, args) {
  var s = t(key);
  if (!args) return s;
  for (var i = 0; i < args.length; ++i)
    s = s.replace("%" + (i + 1), String(args[i]));
  return s;
}
