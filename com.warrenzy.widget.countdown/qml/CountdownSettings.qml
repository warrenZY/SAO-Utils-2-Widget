// Settings window: profile list, date/time, style, font.
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import NERvGear 1.0 as NVG
import "i18n.js" as I18n
import "countdownconfig.js" as Cfg

NVG.Window {
    id: settingsWindow

    property var targetWidget: null
    property var ownerAction: null

    title: I18n.t("settings.title")
    visible: true
    minimumWidth: 480
    minimumHeight: 640

    Component.onDestruction: {
        if (ownerAction && ownerAction.settingsWindow === settingsWindow)
            ownerAction.settingsWindow = null;
    }
    onClosing: destroy()

    // ---- Shared style tokens ----
    readonly property color  labelColor:  "#666666"
    readonly property int    labelSize:   13
    readonly property int    labelWidth:  60
    readonly property int    fieldHeight: 42
    readonly property int    padH: 10
    readonly property int    padV: 8
    readonly property int    rowGap: 8

    property var config: ({ profiles: [] })
    property string currentProfileId: ""
    property var profileList: []

    property var allFonts: []
    property var filteredFontList: []
    property string pendingFont: Cfg.DEFAULT_FONT
    property int  pendingFontWeight: 50
    property real pendingLineHeight: Cfg.DEFAULT_LINE_HEIGHT
    property string pendingStrokeColor: Cfg.DEFAULT_STROKE_COLOR
    property bool pendingStrokeEnabled: Cfg.DEFAULT_STROKE_ON
    property bool fontExpanded: false

    property bool loadingForm: false
    property bool formDirty: false

    QtObject { id: settingsOwner }

    Component.onCompleted: {
        allFonts = buildAllFonts();
        filteredFontList = allFonts.slice();
        config = Cfg.loadConfig();
        currentProfileId = (targetWidget && targetWidget.settings.profileId) || "";
        if (!currentProfileId && config.profiles.length > 0)
            currentProfileId = config.profiles[0].id;
        refreshProfileList();
        syncComboIndex();
        loadForm();
    }

    // ---- Font list ----
    function buildAllFonts() {
        var sys = [];
        try { sys = Qt.fontFamilies(); } catch (e) { }
        var seen = {};
        var result = [];
        if (Cfg.DEFAULT_FONT) {
            result.push(Cfg.DEFAULT_FONT);
            seen[Cfg.DEFAULT_FONT] = true;
        }
        var others = [];
        for (var i = 0; i < sys.length; ++i) {
            var n = sys[i];
            if (!n || typeof n !== "string") continue;
            n = n.trim();
            if (!n || seen[n]) continue;
            seen[n] = true;
            others.push(n);
        }
        others.sort(function (a, b) { return a.localeCompare(b); });
        for (var j = 0; j < others.length; ++j) result.push(others[j]);
        return result;
    }

    function updateFilteredFonts(query) {
        query = (query || "").toString().trim().toLowerCase();
        if (!query) { filteredFontList = allFonts.slice(); return; }
        var result = [];
        for (var i = 0; i < allFonts.length; ++i)
            if (String(allFonts[i]).toLowerCase().indexOf(query) >= 0)
                result.push(allFonts[i]);
        filteredFontList = result;
    }

    // ---- Profile list management ----
    function refreshProfileList() { profileList = config.profiles.slice(); }

    function syncComboIndex() {
        if (profileList.length === 0) { profileCombo.currentIndex = -1; return; }
        for (var i = 0; i < profileList.length; ++i) {
            if (profileList[i] && profileList[i].id === currentProfileId) {
                profileCombo.currentIndex = i; return;
            }
        }
        profileCombo.currentIndex = 0;
    }

    function currentProfile() { return Cfg.findProfile(config, currentProfileId); }
    function markDirty() { if (!loadingForm) formDirty = true; }

    function syncFontWeightCombo() {
        var w = Cfg.FONT_WEIGHTS;
        for (var i = 0; i < w.length; ++i) {
            if (w[i].value === settingsWindow.pendingFontWeight) {
                fontWeightCombo.currentIndex = i; return;
            }
        }
        fontWeightCombo.currentIndex = 0;
    }

    // Safely read a profile field with a default.
    function pick(p, key, fallback) {
        return (p && p[key] !== undefined && p[key] !== null)
               ? p[key] : fallback;
    }

    // ---- Form I/O ----
    function storeForm() {
        var p = currentProfile();
        if (!p) return;
        p.title         = titleField.text;
        p.targetDate    = new Date(
            yearField.value, monthField.value - 1, dayField.value,
            hourField.value, minuteField.value, 0).toISOString();
        p.titleSize     = titleSizeField.value;
        p.valueSize     = valueSizeField.value;
        p.titleColor    = titleColorField.text;
        p.valueColor    = valueColorField.text;
        p.fontFamily    = settingsWindow.pendingFont || Cfg.DEFAULT_FONT;
        p.fontWeight    = settingsWindow.pendingFontWeight;
        p.lineHeight    = settingsWindow.pendingLineHeight;
        p.strokeColor   = settingsWindow.pendingStrokeColor;
        p.strokeEnabled = settingsWindow.pendingStrokeEnabled;
    }

    // Save the current state and push it to the bound widget.
    // When there are no profiles, this clears the widget's profileId
    // so the widget returns to its "unbound / reset" state.
    function commitToWidget() {
        if (settingsWindow.profileList.length > 0)
            storeForm();
        Cfg.saveConfig(settingsWindow.config, settingsOwner);
        if (settingsWindow.targetWidget) {
            settingsWindow.targetWidget.settings.profileId
                    = settingsWindow.currentProfileId || "";
            settingsWindow.targetWidget.refreshProfile();
            settingsWindow.targetWidget.refreshCountdown();
        }
        settingsWindow.formDirty = false;
    }

    function loadForm() {
        loadingForm = true;
        var p = currentProfile();

        profileNameField.text = pick(p, "name", "");
        titleField.text       = pick(p, "title", "");
        titleColorField.text  = pick(p, "titleColor", Cfg.DEFAULT_TITLE_COLOR);
        valueColorField.text  = pick(p, "valueColor", Cfg.DEFAULT_VALUE_COLOR);
        titleSizeField.value  = pick(p, "titleSize", 24);
        valueSizeField.value  = pick(p, "valueSize", 24);

        settingsWindow.pendingFont = pick(p, "fontFamily", Cfg.DEFAULT_FONT);
        settingsWindow.pendingFontWeight = pick(p, "fontWeight", 50);
        settingsWindow.pendingLineHeight =
            pick(p, "lineHeight", Cfg.DEFAULT_LINE_HEIGHT);
        settingsWindow.pendingStrokeColor =
            pick(p, "strokeColor", Cfg.DEFAULT_STROKE_COLOR);
        settingsWindow.pendingStrokeEnabled =
            !!pick(p, "strokeEnabled", Cfg.DEFAULT_STROKE_ON);

        fontSearchField.text = "";
        lineHeightField.text = Number(settingsWindow.pendingLineHeight).toFixed(1);
        strokeColorField.text = settingsWindow.pendingStrokeColor;
        strokeCheck.checked = settingsWindow.pendingStrokeEnabled;
        syncFontWeightCombo();

        var d = (p && p.targetDate)
                ? new Date(p.targetDate)
                : new Date(Date.now() + 86400000);
        yearField.value   = d.getFullYear();
        monthField.value  = d.getMonth() + 1;
        dayField.value    = d.getDate();
        hourField.value   = p ? d.getHours() : 0;
        minuteField.value = p ? d.getMinutes() : 0;

        loadingForm = false;
        formDirty = false;
    }

    function bumpLineHeight(delta) {
        var v = parseFloat(lineHeightField.text);
        if (isNaN(v)) v = Cfg.DEFAULT_LINE_HEIGHT;
        v = v + (delta > 0 ? 0.1 : -0.1);
        v = Math.max(0.5, Math.min(5.0, Math.round(v * 10) / 10));
        lineHeightField.text = v.toFixed(1);
        settingsWindow.pendingLineHeight = v;
        settingsWindow.markDirty();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ---- Profile selector ----
        RowLayout {
            Layout.fillWidth: true
            spacing: settingsWindow.rowGap

            SettingsLabel { text: I18n.t("settings.profile") }

            SettingsComboBox {
                id: profileCombo
                model: settingsWindow.profileList
                textRole: "name"
                displayText: {
                    if (settingsWindow.profileList.length === 0)
                        return I18n.t("settings.noProfile");
                    var base = currentText || "";
                    return settingsWindow.formDirty
                           ? base + I18n.t("settings.unsaved") : base;
                }
                onActivated: {
                    settingsWindow.storeForm();
                    if (index < 0
                            || index >= settingsWindow.config.profiles.length)
                        return;
                    var p = settingsWindow.config.profiles[index];
                    if (!p || !p.id) return;
                    settingsWindow.currentProfileId = p.id;
                    settingsWindow.loadForm();
                }
            }

            Button {
                text: "+"
                Layout.preferredWidth: settingsWindow.fieldHeight
                Layout.preferredHeight: settingsWindow.fieldHeight
                onClicked: {
                    settingsWindow.storeForm();
                    var name = I18n.tf("settings.newProfile",
                                       [settingsWindow.config.profiles.length + 1]);
                    var p = Cfg.makeDefaultProfile(
                        name, I18n.t("data.defaultTitleTomorrow"));
                    settingsWindow.config.profiles.push(p);
                    settingsWindow.currentProfileId = p.id;
                    settingsWindow.refreshProfileList();
                    settingsWindow.syncComboIndex();
                    settingsWindow.loadForm();
                }
            }
            Button {
                text: "\u00D7"
                Layout.preferredWidth: settingsWindow.fieldHeight
                Layout.preferredHeight: settingsWindow.fieldHeight
                enabled: settingsWindow.config.profiles.length > 0
                onClicked: {
                    var list = settingsWindow.config.profiles;
                    if (!list || list.length === 0) return;
                    var idx = -1;
                    for (var i = 0; i < list.length; ++i) {
                        if (list[i] && list[i].id === settingsWindow.currentProfileId) {
                            idx = i; break;
                        }
                    }
                    if (idx < 0) return;
                    list.splice(idx, 1);
                    settingsWindow.currentProfileId =
                        list.length === 0 ? "" : list[0].id;
                    settingsWindow.refreshProfileList();
                    settingsWindow.syncComboIndex();
                    settingsWindow.loadForm();
                }
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
                width: scrollView.availableWidth
                spacing: settingsWindow.rowGap

                SettingsLabel { text: I18n.t("settings.profileName") }
                TextField {
                    id: profileNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.fieldHeight
                    font.pixelSize: 15
                    selectByMouse: true
                    leftPadding: settingsWindow.padH
                    rightPadding: settingsWindow.padH
                    topPadding: settingsWindow.padV
                    bottomPadding: settingsWindow.padV
                    onTextChanged: settingsWindow.markDirty()
                }

                SettingsLabel {
                    text: I18n.t("settings.label.title")
                    Layout.topMargin: 4
                }
                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.fieldHeight
                    placeholderText: I18n.t("settings.placeholder")
                    font.pixelSize: 15
                    selectByMouse: true
                    leftPadding: settingsWindow.padH
                    rightPadding: settingsWindow.padH
                    topPadding: settingsWindow.padV
                    bottomPadding: settingsWindow.padV
                    onTextChanged: settingsWindow.markDirty()
                }

                SettingsLabel {
                    text: I18n.t("settings.label.date")
                    Layout.topMargin: 4
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.rowGap
                    NumberField { id: yearField
                                  Layout.fillWidth: true
                                  from: 2024; to: 2099
                                  nextField: monthField
                                  onValueChanged: settingsWindow.markDirty() }
                    NumberField { id: monthField
                                  Layout.fillWidth: true
                                  from: 1; to: 12; padWidth: 2
                                  nextField: dayField
                                  onValueChanged: settingsWindow.markDirty() }
                    NumberField { id: dayField
                                  Layout.fillWidth: true
                                  from: 1; to: 31; padWidth: 2
                                  nextField: hourField
                                  onValueChanged: settingsWindow.markDirty() }
                }

                SettingsLabel {
                    text: I18n.t("settings.label.time")
                    Layout.topMargin: 4
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.rowGap
                    NumberField { id: hourField
                                  Layout.fillWidth: true
                                  from: 0; to: 23; padWidth: 2
                                  nextField: minuteField
                                  onValueChanged: settingsWindow.markDirty() }
                    NumberField { id: minuteField
                                  Layout.fillWidth: true
                                  from: 0; to: 59; padWidth: 2
                                  nextField: titleColorField
                                  onValueChanged: settingsWindow.markDirty() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8; Layout.bottomMargin: 4
                    height: 1; color: "#e0e0e0"
                }

                // ---- Colors & sizes ----
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: settingsWindow.rowGap
                    rowSpacing: settingsWindow.rowGap

                    SettingsLabel {
                        text: I18n.t("settings.short.title")
                        Layout.preferredWidth: settingsWindow.labelWidth
                    }
                    TextField {
                        id: titleColorField
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.fieldHeight
                        font.pixelSize: 15; selectByMouse: true
                        horizontalAlignment: TextInput.AlignHCenter
                        leftPadding: settingsWindow.padH
                        rightPadding: settingsWindow.padH
                        topPadding: settingsWindow.padV
                        bottomPadding: settingsWindow.padV
                        onTextChanged: settingsWindow.markDirty()
                    }
                    Rectangle {
                        Layout.preferredWidth: settingsWindow.fieldHeight
                        Layout.preferredHeight: settingsWindow.fieldHeight
                        color: titleColorField.text
                        border.color: "#bbbbbb"; border.width: 1; radius: 3
                    }
                    NumberField { id: titleSizeField
                                  Layout.preferredWidth: 72
                                  from: 8; to: 60; padWidth: 2
                                  nextField: valueColorField
                                  onValueChanged: settingsWindow.markDirty() }

                    SettingsLabel {
                        text: I18n.t("settings.short.value")
                        Layout.preferredWidth: settingsWindow.labelWidth
                    }
                    TextField {
                        id: valueColorField
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.fieldHeight
                        font.pixelSize: 15; selectByMouse: true
                        horizontalAlignment: TextInput.AlignHCenter
                        leftPadding: settingsWindow.padH
                        rightPadding: settingsWindow.padH
                        topPadding: settingsWindow.padV
                        bottomPadding: settingsWindow.padV
                        onTextChanged: settingsWindow.markDirty()
                    }
                    Rectangle {
                        Layout.preferredWidth: settingsWindow.fieldHeight
                        Layout.preferredHeight: settingsWindow.fieldHeight
                        color: valueColorField.text
                        border.color: "#bbbbbb"; border.width: 1; radius: 3
                    }
                    NumberField { id: valueSizeField
                                  Layout.preferredWidth: 72
                                  from: 8; to: 60; padWidth: 2
                                  nextField: titleField
                                  onValueChanged: settingsWindow.markDirty() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8; Layout.bottomMargin: 4
                    height: 1; color: "#e0e0e0"
                }

                // ---- Font section (collapsible) ----
                Button {
                    id: fontToggle
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    background: Rectangle {
                        radius: 3
                        border.color: "#c0c0c0"
                        border.width: 1
                        color: fontToggle.pressed ? "#dcdcdc"
                             : fontToggle.hovered ? "#ececec" : "#f6f6f6"
                    }
                    contentItem: RowLayout {
                        spacing: 6
                        Text {
                            text: (settingsWindow.fontExpanded ? "\u25BC " : "\u25B6 ")
                                  + I18n.t("settings.font")
                            color: settingsWindow.labelColor
                            font.pixelSize: settingsWindow.labelSize
                            font.family: Cfg.makeFontStack("")
                            verticalAlignment: Text.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            elide: Text.ElideRight
                            text: I18n.tf("settings.fontCurrent",
                                          [settingsWindow.pendingFont || "-"])
                            color: settingsWindow.labelColor
                            font.pixelSize: settingsWindow.labelSize
                            font.family: Cfg.makeFontStack(settingsWindow.pendingFont)
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    onClicked: settingsWindow.fontExpanded
                               = !settingsWindow.fontExpanded
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.rowGap
                    visible: settingsWindow.fontExpanded

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: "#fafafa"
                        border.color: "#dddddd"; border.width: 1; radius: 3
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
                            style: settingsWindow.pendingStrokeEnabled
                                   ? Text.Outline : Text.Normal
                            styleColor: settingsWindow.pendingStrokeEnabled
                                        ? (settingsWindow.pendingStrokeColor
                                           || "transparent")
                                        : "transparent"
                        }
                    }

                    TextField {
                        id: fontSearchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.fieldHeight
                        font.pixelSize: 15; selectByMouse: true
                        leftPadding: settingsWindow.padH
                        rightPadding: settingsWindow.padH
                        topPadding: settingsWindow.padV
                        bottomPadding: settingsWindow.padV
                        placeholderText: I18n.t("settings.fontSearch")
                        onTextChanged: settingsWindow.updateFilteredFonts(text)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        border.color: "#cccccc"; border.width: 1; radius: 3
                        color: "#fafafa"
                        clip: true

                        ListView {
                            id: fontView
                            anchors.fill: parent
                            anchors.margins: 2
                            model: settingsWindow.filteredFontList
                            clip: true
                            spacing: 1
                            ScrollBar.vertical: ScrollBar { }

                            delegate: Rectangle {
                                width: fontView.width
                                height: 28
                                radius: 2
                                color: {
                                    if (modelData === settingsWindow.pendingFont)
                                        return "#d0e8ff";
                                    if (fontMouseArea.containsMouse)
                                        return "#e8e8e8";
                                    return "transparent";
                                }
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: modelData
                                    font.pixelSize: 15
                                    font.family: Cfg.makeFontStack(modelData)
                                }
                                MouseArea {
                                    id: fontMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        settingsWindow.pendingFont = modelData;
                                        settingsWindow.markDirty();
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: settingsWindow.rowGap
                        SettingsLabel {
                            text: I18n.t("settings.fontWeight")
                            Layout.preferredWidth: settingsWindow.labelWidth
                        }
                        SettingsComboBox {
                            id: fontWeightCombo
                            model: Cfg.FONT_WEIGHTS
                            textRole: "label"
                            onActivated: {
                                if (currentIndex < 0
                                        || currentIndex >= Cfg.FONT_WEIGHTS.length)
                                    return;
                                settingsWindow.pendingFontWeight
                                        = Cfg.FONT_WEIGHTS[currentIndex].value;
                                settingsWindow.markDirty();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: settingsWindow.rowGap
                        CheckBox {
                            id: strokeCheck
                            text: I18n.t("settings.strokeEnabled")
                            font.pixelSize: settingsWindow.labelSize
                            font.family: Cfg.makeFontStack("")
                            palette.windowText: settingsWindow.labelColor
                            onToggled: {
                                settingsWindow.pendingStrokeEnabled = checked;
                                settingsWindow.markDirty();
                            }
                        }
                        SettingsLabel {
                            text: I18n.t("settings.strokeColor")
                            enabled: strokeCheck.checked
                        }
                        TextField {
                            id: strokeColorField
                            Layout.fillWidth: true
                            Layout.preferredHeight: settingsWindow.fieldHeight
                            font.pixelSize: 15; selectByMouse: true
                            horizontalAlignment: TextInput.AlignHCenter
                            leftPadding: settingsWindow.padH
                            rightPadding: settingsWindow.padH
                            topPadding: settingsWindow.padV
                            bottomPadding: settingsWindow.padV
                            placeholderText: "#000000"
                            enabled: strokeCheck.checked
                            onTextChanged: {
                                settingsWindow.pendingStrokeColor = text;
                                settingsWindow.markDirty();
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: settingsWindow.fieldHeight
                            Layout.preferredHeight: settingsWindow.fieldHeight
                            color: strokeColorField.text || "transparent"
                            border.color: "#bbbbbb"; border.width: 1; radius: 3
                            opacity: strokeCheck.checked ? 1.0 : 0.4
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: settingsWindow.rowGap
                        SettingsLabel {
                            text: I18n.t("settings.lineHeight")
                            Layout.preferredWidth: settingsWindow.labelWidth
                        }
                        TextField {
                            id: lineHeightField
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: settingsWindow.fieldHeight
                            font.pixelSize: 15; selectByMouse: true
                            horizontalAlignment: TextInput.AlignHCenter
                            leftPadding: settingsWindow.padH
                            rightPadding: settingsWindow.padH
                            topPadding: settingsWindow.padV
                            bottomPadding: settingsWindow.padV
                            validator: DoubleValidator {
                                bottom: 0.5; top: 5.0; decimals: 1
                                notation: DoubleValidator.StandardNotation
                            }
                            onTextEdited: {
                                var v = parseFloat(text);
                                if (!isNaN(v) && v >= 0.5 && v <= 5.0) {
                                    settingsWindow.pendingLineHeight = v;
                                    settingsWindow.markDirty();
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                onWheel: {
                                    settingsWindow.bumpLineHeight(wheel.angleDelta.y);
                                    wheel.accepted = true;
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                Item { Layout.preferredHeight: 8 }
            }
        }

        // ---- Action buttons ----
        RowLayout {
            Layout.fillWidth: true
            spacing: settingsWindow.rowGap

            Button {
                text: I18n.t("settings.apply")
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                font.pixelSize: 15
                enabled: settingsWindow.targetWidget !== null

                onClicked: {
                    settingsWindow.commitToWidget();
                    NVG.SystemCall.messageBox({ text: I18n.t("settings.applied") });
                }
            }

            Button {
                text: I18n.t("settings.save")
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                font.pixelSize: 15
                highlighted: true
                enabled: settingsWindow.targetWidget !== null

                onClicked: {
                    settingsWindow.commitToWidget();
                    NVG.SystemCall.messageBox({ text: I18n.t("settings.saved") });
                    settingsWindow.close();
                }
            }
        }
    }
}
