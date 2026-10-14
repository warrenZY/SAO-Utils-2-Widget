// Settings window: profile list, date/time, style, font.
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import "countdownconfig.js" as Cfg
import "hub.js" as Hub

NVG.Window {
    id: settingsWindow

    property var targetWidget: null
    property int hubSubscriptionId: -1

    title: qsTr("Countdown Settings")
    visible: true
    minimumWidth: 480
    minimumHeight: 640

    // ---- Style tokens ----
    readonly property QtObject style: QtObject {
        readonly property color  labelColor: "#666666"
        readonly property int    labelSize:  13
        readonly property string labelFont:  Cfg.makeFontStack("")
        readonly property int    labelWidth: 100

        readonly property int fieldHeight:   46
        readonly property int fieldFontSize: 15
        readonly property int sizeWidth:     72
        readonly property int rowGap:        8
        readonly property int padH:          10

        readonly property int labelPlusSize: labelWidth + rowGap + sizeWidth

        readonly property int separatorTopMargin:    8
        readonly property int separatorBottomMargin: 4

        readonly property int fontListHeight: 180
        readonly property int fontItemHeight: 26
        readonly property int buttonHeight:   44

        readonly property int   previewHeight: 64
        readonly property color previewBg:     "#fafafa"
        readonly property color previewBorder: "#dddddd"
    }

    property var config: ({ profiles: [] })
    property string currentProfileId: ""
    property var profileList: []

    // Per-id drafts this window has edited but not persisted.
    property var formCache: ({})
    // Ids this window has created but not yet persisted.
    property var newIds: ({})
    // Derived: ids whose in-window content differs from config.
    property var unsavedIds: ({})

    property var allFonts: []
    property var filteredFontList: []
    property string pendingFont: Cfg.DEFAULT_FONT
    property int  pendingFontWeight: Cfg.DEFAULT_FONT_WEIGHT
    property real pendingLineHeight: Cfg.DEFAULT_LINE_HEIGHT
    property bool fontExpanded: false

    property bool loadingForm: false

    QtObject { id: settingsOwner }

    Component.onCompleted: {
        allFonts = Cfg.allFontFamilies().slice();
        filteredFontList = allFonts.slice();

        hubSubscriptionId = Hub.subscribe(function () {
            settingsWindow.onHubNotify();
        });

        config = Cfg.loadConfig();
        currentProfileId = (targetWidget && targetWidget.settings.profileId) || "";

        // Bound id is stale: fall back for display only. The widget
        // keeps its binding until the user applies from this window.
        if (currentProfileId && !Cfg.findProfile(config, currentProfileId))
            currentProfileId = "";

        if (!currentProfileId && config.profiles.length > 0)
            currentProfileId = config.profiles[0].id;

        refreshProfileList();
        if (currentProfileId) loadForm();
    }

    Component.onDestruction: {
        if (hubSubscriptionId >= 0)
            Hub.unsubscribe(hubSubscriptionId);
    }

    // ---- Hub ----

    function onHubNotify() {
        var r = Cfg.mergeWindowState(Cfg.loadConfig(), formCache, newIds);
        config = r.config;
        formCache = r.formCache;
        newIds = r.newIds;
        refreshProfileList();

        // Current profile was removed elsewhere: fall back only when
        // this window holds no unsaved draft for it.
        if (currentProfileId && !formCache[currentProfileId] &&
            !Cfg.findProfile(config, currentProfileId)) {
            currentProfileId = config.profiles.length > 0
                             ? config.profiles[0].id : "";
            if (currentProfileId) { loadForm(); return; }
            unsavedIds = {};
            return;
        }

        // Current profile has no local edits: refresh from config.
        if (currentProfileId && !formCache[currentProfileId]) {
            loadForm();
            return;
        }

        syncUnsavedIds();
    }

    // ---- Profile list ----

    function refreshProfileList() { profileList = config.profiles.slice(); }

    function currentProfile() { return Cfg.findProfile(config, currentProfileId); }

    // ---- Dirty state ----

    // Sync the current form into formCache and recompute unsavedIds.
    // A profile is cached when its form differs from config, or when
    // it is a not-yet-persisted creation of this window.
    function syncProfileState() {
        if (loadingForm || !currentProfileId) return;

        var p = Cfg.findProfile(config, currentProfileId);

        // If the bound id no longer exists in config and was not just
        // created by this window, don't accumulate edits for it — a
        // later save would materialise a phantom profile.
        if (!p && !newIds[currentProfileId]) {
            if (formCache[currentProfileId]) {
                var c = {};
                for (var k in formCache)
                    if (k !== currentProfileId) c[k] = formCache[k];
                formCache = c;
                syncUnsavedIds();
            }
            return;
        }

        var s = snapshotForm();
        var differs = p ? Cfg.snapshotDiffersFrom(s, p) : true;
        var keep = differs || newIds[currentProfileId];

        var c2 = {};
        for (var k2 in formCache) c2[k2] = formCache[k2];
        if (keep) c2[currentProfileId] = s;
        else delete c2[currentProfileId];

        formCache = c2;
        syncUnsavedIds();
    }

    function syncUnsavedIds() {
        var result = {};
        for (var id in formCache) result[id] = true;
        unsavedIds = result;
    }

    // ---- Form <-> snapshot ----

    function snapshotForm() {
        return {
            name: profileNameField.text,
            title: titleField.text,
            targetDate: new Date(
                yearField.value, monthField.value - 1, dayField.value,
                hourField.value, minuteField.value, 0).toISOString(),
            titleSize: titleSizeField.value,
            valueSize: valueSizeField.value,
            titleColor: String(titleColorPicker.value),
            valueColor: String(valueColorPicker.value),
            strokeColor: String(strokeColorPicker.value),
            strokeEnabled: !!strokeSwitchPref.value,
            fontFamily: settingsWindow.pendingFont || Cfg.DEFAULT_FONT,
            fontWeight: settingsWindow.pendingFontWeight,
            lineHeight: lineHeightField.value,
        };
    }

    function profileToSnapshot(p) {
        return {
            name: p.name || "",
            title: p.title || "",
            targetDate: p.targetDate,
            titleSize: p.titleSize,
            valueSize: p.valueSize,
            titleColor: p.titleColor,
            valueColor: p.valueColor,
            strokeColor: p.strokeColor,
            strokeEnabled: !!p.strokeEnabled,
            fontFamily: p.fontFamily,
            fontWeight: p.fontWeight,
            lineHeight: p.lineHeight,
        };
    }

    function applySnapshot(s) {
        loadingForm = true;

        profileNameField.text = s.name  || "";
        titleField.text       = s.title || "";

        titleSizeField.value = s.titleSize;
        valueSizeField.value = s.valueSize;

        titleColorPicker.value  = s.titleColor;
        valueColorPicker.value  = s.valueColor;
        strokeColorPicker.value = s.strokeColor;
        strokeSwitchPref.value  = !!s.strokeEnabled;

        settingsWindow.pendingFont = s.fontFamily;
        settingsWindow.pendingFontWeight = s.fontWeight;

        var d = new Date(s.targetDate);
        yearField.value   = d.getFullYear();
        monthField.value  = d.getMonth() + 1;
        dayField.value    = d.getDate();
        hourField.value   = d.getHours();
        minuteField.value = d.getMinutes();

        lineHeightField.value = s.lineHeight;

        fontSearchField.text = "";
        syncFontWeightCombo();

        loadingForm = false;
    }

    function loadForm() {
        if (!currentProfileId) return;

        var cached = formCache[currentProfileId];
        if (cached) {
            applySnapshot(cached);
        } else {
            var p = currentProfile();
            applySnapshot(p ? p : Cfg.makeDefaultProfile("", ""));
        }
        syncProfileState();
    }

    // ---- Profile actions ----

    // Create a new profile, cache its default snapshot as a draft, and
    // switch the form to it.
    function addProfile() {
        syncProfileState();

        var name = qsTr("New Profile %1").arg(config.profiles.length + 1);
        var p = Cfg.makeDefaultProfile(name, qsTr("Time until tomorrow"));
        var s = profileToSnapshot(p);

        var c = {};
        for (var k in formCache) c[k] = formCache[k];
        c[p.id] = s;
        formCache = c;

        var n = {};
        for (var nk in newIds) n[nk] = true;
        n[p.id] = true;
        newIds = n;

        config.profiles.push(p);
        currentProfileId = p.id;
        refreshProfileList();

        applySnapshot(s);
        syncUnsavedIds();
    }

    // Delete the currently selected profile from disk and switch to
    // whatever remains. Persisted independently of the draft model.
    // currentProfileId is left untouched; onHubNotify detects the
    // removal and falls back for display. The widget binding is left
    // untouched too: only an explicit Apply rebinds it.
    function removeCurrentProfile() {
        var list = config.profiles;
        if (!list || list.length === 0) return;

        var idx = -1;
        for (var i = 0; i < list.length; ++i) {
            if (list[i] && list[i].id === currentProfileId) {
                idx = i; break;
            }
        }
        if (idx < 0) return;

        var removedId = list[idx].id;

        Cfg.deleteProfile(removedId, settingsOwner);

        var c = {};
        for (var k in formCache)
            if (k !== removedId) c[k] = formCache[k];
        formCache = c;

        var n = {};
        for (var nk in newIds)
            if (nk !== removedId) n[nk] = true;
        newIds = n;

        Hub.notify();
    }

    // ---- Commit ----

    // Persist the given ids (null = every pending draft). Removes those
    // ids from formCache/newIds, reloads from disk, and broadcasts.
    function commitTo(ids) {
        syncProfileState();

        if (ids === null || ids === undefined)
            ids = Object.keys(formCache);

        var entries = {};
        for (var i = 0; i < ids.length; ++i) {
            var id = ids[i];
            if (formCache[id]) {
                entries[id] = formCache[id];
            } else {
                var p = Cfg.findProfile(config, id);
                if (p) entries[id] = profileToSnapshot(p);
            }
        }
        Cfg.updateProfiles(entries, settingsOwner);

        var idSet = {};
        for (var j = 0; j < ids.length; ++j) idSet[ids[j]] = true;

        var c = {};
        for (var k in formCache)
            if (!idSet[k]) c[k] = formCache[k];
        formCache = c;

        var n = {};
        for (var nk in newIds)
            if (!idSet[nk]) n[nk] = true;
        newIds = n;

        Hub.notify();
    }

    // Persist the current profile and point the widget at it.
    function applyCurrent() {
        if (!currentProfileId) return;
        if (targetWidget)
            targetWidget.settings.profileId = currentProfileId;
        commitTo([currentProfileId]);
    }

    // Persist every pending profile without touching the widget binding.
    function saveAll() {
        commitTo(null);
    }

    // Bind the widget to the current profile, persist every pending
    // edit, then close the window.
    function applyAndClose() {
        if (targetWidget)
            targetWidget.settings.profileId = currentProfileId || "";
        commitTo(null);
        NVG.SystemCall.messageBox({ text: qsTr("Settings saved.") });
        settingsWindow.close();
    }

    // ---- Fonts ----

    function updateFilteredFonts(query) {
        query = (query || "").toString().trim().toLowerCase();
        if (!query) { filteredFontList = allFonts.slice(); return; }
        var result = [];
        for (var i = 0; i < allFonts.length; ++i)
            if (String(allFonts[i]).toLowerCase().indexOf(query) >= 0)
                result.push(allFonts[i]);
        filteredFontList = result;
    }

    function syncFontWeightCombo() {
        var w = Cfg.FONT_WEIGHTS;
        for (var i = 0; i < w.length; ++i) {
            if (w[i].value === settingsWindow.pendingFontWeight) {
                fontWeightCombo.currentIndex = i;
                return;
            }
        }
        fontWeightCombo.currentIndex = 0;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ---- Profile selector ----
        RowLayout {
            Layout.fillWidth: true
            spacing: settingsWindow.style.rowGap

            Label {
                text: qsTr("Profile")
                color: settingsWindow.style.labelColor
                font.pixelSize: settingsWindow.style.labelSize
                font.family: settingsWindow.style.labelFont
            }

            ComboBox {
                id: profileCombo
                Layout.fillWidth: true
                Layout.preferredHeight: settingsWindow.style.fieldHeight
                font.pixelSize: settingsWindow.style.fieldFontSize
                model: settingsWindow.profileList

                currentIndex: {
                    for (var i = 0; i < settingsWindow.profileList.length; ++i) {
                        if (settingsWindow.profileList[i].id
                                === settingsWindow.currentProfileId)
                            return i;
                    }
                    return -1;
                }

                displayText: {
                    if (settingsWindow.profileList.length === 0)
                        return qsTr("(No valid profile)");
                    if (currentIndex < 0)
                        return qsTr("(No valid profile)");
                    var name = profileNameField.text || "";
                    if (!name) name = currentText || "";
                    return settingsWindow.unsavedIds[settingsWindow.currentProfileId]
                         ? name + qsTr(" (unsaved)")
                         : name;
                }

                delegate: ItemDelegate {
                    id: profileDelegate
                    width: profileCombo.width
                    highlighted: profileCombo.highlightedIndex === index
                    leftPadding: settingsWindow.style.padH
                    rightPadding: settingsWindow.style.padH

                    contentItem: Text {
                        text: {
                            var d = modelData;
                            var name = (d && d.name) ? d.name : "";
                            var dirty = d && settingsWindow.unsavedIds[d.id];
                            return dirty ? name + qsTr(" (unsaved)")
                                         : name;
                        }
                        color: "#333333"
                        font: profileCombo.font
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                onActivated: {
                    settingsWindow.syncProfileState();

                    if (index < 0
                            || index >= settingsWindow.profileList.length)
                        return;
                    var p = settingsWindow.profileList[index];
                    if (!p || !p.id) return;
                    if (p.id === settingsWindow.currentProfileId) return;
                    settingsWindow.currentProfileId = p.id;
                    settingsWindow.loadForm();
                }
            }

            Button {
                text: "+"
                Layout.preferredWidth: settingsWindow.style.fieldHeight
                Layout.preferredHeight: settingsWindow.style.fieldHeight
                onClicked: settingsWindow.addProfile()
            }
            Button {
                text: "\u00D7"
                Layout.preferredWidth: settingsWindow.style.fieldHeight
                Layout.preferredHeight: settingsWindow.style.fieldHeight
                enabled: settingsWindow.profileList.length > 0
                onClicked: settingsWindow.removeCurrentProfile()
            }
        }

        // ---- Scrollable form ----
        ScrollView {
            id: scrollView
            visible: settingsWindow.profileList.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scrollView.availableWidth - 8
                spacing: settingsWindow.style.rowGap

                Label {
                    text: qsTr("Profile Name")
                    color: settingsWindow.style.labelColor
                    font.pixelSize: settingsWindow.style.labelSize
                    font.family: settingsWindow.style.labelFont
                }
                TextField {
                    id: profileNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.style.fieldHeight
                    font.pixelSize: settingsWindow.style.fieldFontSize
                    selectByMouse: true
                    leftPadding: settingsWindow.style.padH
                    rightPadding: settingsWindow.style.padH
                    onTextChanged: settingsWindow.syncProfileState()
                }

                Label {
                    text: qsTr("Countdown Title")
                    color: settingsWindow.style.labelColor
                    font.pixelSize: settingsWindow.style.labelSize
                    font.family: settingsWindow.style.labelFont
                    Layout.topMargin: 4
                }
                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.style.fieldHeight
                    placeholderText: qsTr("Enter a title")
                    font.pixelSize: settingsWindow.style.fieldFontSize
                    selectByMouse: true
                    leftPadding: settingsWindow.style.padH
                    rightPadding: settingsWindow.style.padH
                    onTextChanged: settingsWindow.syncProfileState()
                }

                Label {
                    text: qsTr("Target Date (Y-M-D)")
                    color: settingsWindow.style.labelColor
                    font.pixelSize: settingsWindow.style.labelSize
                    font.family: settingsWindow.style.labelFont
                    Layout.topMargin: 4
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap
                    NumberField { id: yearField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 1970; to: 9999
                                  nextField: monthField
                                  onValueChanged: settingsWindow.syncProfileState() }
                    NumberField { id: monthField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 1; to: 12; padWidth: 2
                                  nextField: dayField
                                  onValueChanged: settingsWindow.syncProfileState() }
                    NumberField { id: dayField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 1; to: 31; padWidth: 2
                                  nextField: hourField
                                  onValueChanged: settingsWindow.syncProfileState() }
                }

                Label {
                    text: qsTr("Target Time (H:M)")
                    color: settingsWindow.style.labelColor
                    font.pixelSize: settingsWindow.style.labelSize
                    font.family: settingsWindow.style.labelFont
                    Layout.topMargin: 4
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap
                    NumberField { id: hourField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 0; to: 23; padWidth: 2
                                  nextField: minuteField
                                  onValueChanged: settingsWindow.syncProfileState() }
                    NumberField { id: minuteField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 0; to: 59; padWidth: 2
                                  nextField: titleSizeField
                                  onValueChanged: settingsWindow.syncProfileState() }
                }

                Divider {
                    Layout.fillWidth: true
                    Layout.topMargin: settingsWindow.style.separatorTopMargin
                    Layout.bottomMargin: settingsWindow.style.separatorBottomMargin
                }

                // ---- Title row ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap

                    Label {
                        text: qsTr("Title")
                        color: settingsWindow.style.labelColor
                        font.pixelSize: settingsWindow.style.labelSize
                        font.family: settingsWindow.style.labelFont
                        Layout.preferredWidth: settingsWindow.style.labelWidth
                    }
                    NumberField {
                        id: titleSizeField
                        Layout.preferredWidth: settingsWindow.style.sizeWidth
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        from: 8; to: 200
                        onValueChanged: settingsWindow.syncProfileState()
                    }
                    ColorPicker {
                        id: titleColorPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        textColor: settingsWindow.style.labelColor
                        textSize: settingsWindow.style.labelSize
                        textFont: settingsWindow.style.labelFont
                        onValueChanged: settingsWindow.syncProfileState()
                    }
                }

                // ---- Value row ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap

                    Label {
                        text: qsTr("Countdown")
                        color: settingsWindow.style.labelColor
                        font.pixelSize: settingsWindow.style.labelSize
                        font.family: settingsWindow.style.labelFont
                        Layout.preferredWidth: settingsWindow.style.labelWidth
                    }
                    NumberField {
                        id: valueSizeField
                        Layout.preferredWidth: settingsWindow.style.sizeWidth
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        from: 8; to: 200
                        onValueChanged: settingsWindow.syncProfileState()
                    }
                    ColorPicker {
                        id: valueColorPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        textColor: settingsWindow.style.labelColor
                        textSize: settingsWindow.style.labelSize
                        textFont: settingsWindow.style.labelFont
                        onValueChanged: settingsWindow.syncProfileState()
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    Layout.topMargin: settingsWindow.style.separatorTopMargin
                    Layout.bottomMargin: settingsWindow.style.separatorBottomMargin
                }

                // ---- Stroke row ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap

                    P.SwitchPreference {
                        id: strokeSwitchPref
                        name: "strokeEnabled"
                        label: qsTr("Enable Outline")
                        leftPadding: 0
                        Layout.minimumWidth: settingsWindow.style.labelPlusSize
                        Layout.preferredWidth: settingsWindow.style.labelPlusSize
                        Layout.maximumWidth: settingsWindow.style.labelPlusSize
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        defaultValue: false
                        onValueChanged: settingsWindow.syncProfileState()
                    }

                    ColorPicker {
                        id: strokeColorPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        textColor: settingsWindow.style.labelColor
                        textSize: settingsWindow.style.labelSize
                        textFont: settingsWindow.style.labelFont
                        enabled: strokeSwitchPref.value
                        onValueChanged: settingsWindow.syncProfileState()
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    Layout.topMargin: settingsWindow.style.separatorTopMargin
                    Layout.bottomMargin: settingsWindow.style.separatorBottomMargin
                }

                // ---- Font: label + toggle split 50/50 ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap

                    Label {
                        text: qsTr("Font")
                        color: settingsWindow.style.labelColor
                        font.pixelSize: settingsWindow.style.labelSize
                        font.family: settingsWindow.style.labelFont
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Button {
                        id: fontToggle
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        checkable: true
                        checked: settingsWindow.fontExpanded

                        contentItem: RowLayout {
                            spacing: 6
                            Text {
                                text: settingsWindow.fontExpanded ? "\u25BC" : "\u25B6"
                                color: settingsWindow.style.labelColor
                                font.pixelSize: settingsWindow.style.labelSize
                                font.family: settingsWindow.style.labelFont
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                text: settingsWindow.pendingFont || "-"
                                color: settingsWindow.style.labelColor
                                font.pixelSize: settingsWindow.style.labelSize
                                font.family: Cfg.makeFontStack(
                                                  settingsWindow.pendingFont)
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        onToggled: settingsWindow.fontExpanded = checked
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap
                    visible: settingsWindow.fontExpanded

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.previewHeight
                        color: settingsWindow.style.previewBg
                        border.color: settingsWindow.style.previewBorder
                        border.width: 1; radius: 3
                        Text {
                            anchors.fill: parent; anchors.margins: 10
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: "Aa Bb Cc  0123  字体预览"
                            font.family: Cfg.makeFontStack(settingsWindow.pendingFont)
                            font.weight: settingsWindow.pendingFontWeight
                            font.pixelSize: 20
                            color: "#333333"
                            lineHeight: settingsWindow.pendingLineHeight
                            lineHeightMode: Text.ProportionalHeight
                            style: strokeSwitchPref.value
                                   ? Text.Outline : Text.Normal
                            styleColor: strokeSwitchPref.value
                                        ? (strokeColorPicker.value || "transparent")
                                        : "transparent"
                        }
                    }

                    TextField {
                        id: fontSearchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        font.pixelSize: settingsWindow.style.fieldFontSize
                        selectByMouse: true
                        leftPadding: settingsWindow.style.padH
                        rightPadding: settingsWindow.style.padH
                        placeholderText: qsTr("Type to search fonts...")
                        onTextChanged: settingsWindow.updateFilteredFonts(text)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fontListHeight
                        border.color: "#cccccc"; border.width: 1; radius: 3
                        color: "#fafafa"
                        clip: true

                        ListView {
                            id: fontView
                            anchors.fill: parent
                            anchors.margins: 2
                            model: settingsWindow.filteredFontList
                            clip: true
                            ScrollBar.vertical: ScrollBar { }

                            delegate: ItemDelegate {
                                width: fontView.width
                                implicitHeight: settingsWindow.style.fontItemHeight
                                padding: 0
                                highlighted: modelData === settingsWindow.pendingFont
                                onClicked: {
                                    settingsWindow.pendingFont = modelData;
                                    settingsWindow.syncProfileState();
                                }

                                contentItem: Item {
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        text: modelData
                                        font.pixelSize: settingsWindow.style.fieldFontSize
                                        font.family: Cfg.makeFontStack(modelData)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: settingsWindow.style.rowGap
                        Label {
                            text: qsTr("Font Weight")
                            color: settingsWindow.style.labelColor
                            font.pixelSize: settingsWindow.style.labelSize
                            font.family: settingsWindow.style.labelFont
                            Layout.preferredWidth: settingsWindow.style.labelWidth
                        }
                        ComboBox {
                            id: fontWeightCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: settingsWindow.style.fieldHeight
                            font.pixelSize: settingsWindow.style.fieldFontSize
                            model: Cfg.FONT_WEIGHTS
                            textRole: "label"
                            onActivated: {
                                if (currentIndex < 0
                                        || currentIndex >= Cfg.FONT_WEIGHTS.length)
                                    return;
                                settingsWindow.pendingFontWeight
                                        = Cfg.FONT_WEIGHTS[currentIndex].value;
                                settingsWindow.syncProfileState();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: settingsWindow.style.rowGap
                        Label {
                            text: qsTr("Line Height")
                            color: settingsWindow.style.labelColor
                            font.pixelSize: settingsWindow.style.labelSize
                            font.family: settingsWindow.style.labelFont
                            Layout.preferredWidth: settingsWindow.style.labelWidth
                        }
                        NumberField {
                            id: lineHeightField
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: settingsWindow.style.fieldHeight
                            from: 0.5; to: 5.0; decimals: 1
                            onValueChanged: {
                                settingsWindow.pendingLineHeight = value;
                                settingsWindow.syncProfileState();
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                Item { Layout.preferredHeight: 8 }
            }
        }

        // ---- Action buttons ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: settingsWindow.style.rowGap

            RowLayout {
                Layout.fillWidth: true
                spacing: settingsWindow.style.rowGap

                Button {
                    text: qsTr("Apply Current")
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.style.buttonHeight
                    font.pixelSize: settingsWindow.style.fieldFontSize
                    enabled: settingsWindow.targetWidget !== null
                    onClicked: settingsWindow.applyCurrent()
                }

                Button {
                    text: qsTr("Save All")
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.style.buttonHeight
                    font.pixelSize: settingsWindow.style.fieldFontSize
                    enabled: settingsWindow.targetWidget !== null
                    onClicked: settingsWindow.saveAll()
                }
            }

            Button {
                text: qsTr("Apply && Close")
                Layout.fillWidth: true
                Layout.preferredHeight: settingsWindow.style.buttonHeight
                font.pixelSize: settingsWindow.style.fieldFontSize
                highlighted: true
                enabled: settingsWindow.targetWidget !== null
                onClicked: settingsWindow.applyAndClose()
            }
        }
    }
}