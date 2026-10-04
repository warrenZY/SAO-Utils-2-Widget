// Settings window: profile list, date/time, style, font.
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import NERvGear 1.0 as NVG
import NERvGear.Controls 1.0
import NERvGear.Preferences 1.0 as P
import "i18n.js" as I18n
import "countdownconfig.js" as Cfg
import "hub.js" as Hub

NVG.Window {
    id: settingsWindow

    property var targetWidget: null
    property var ownerAction: null
    property int hubSubscriptionId: -1

    title: I18n.t("settings.title")
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

    Component.onCompleted: {
        allFonts = buildAllFonts();
        filteredFontList = allFonts.slice();

        hubSubscriptionId = Hub.subscribe(function () {
            settingsWindow.onHubNotify();
        });

        config = Cfg.loadConfig();
        currentProfileId = (targetWidget && targetWidget.settings.profileId) || "";
        if (!currentProfileId && config.profiles.length > 0)
            currentProfileId = config.profiles[0].id;
        refreshProfileList();
        loadForm();
    }

    Component.onDestruction: {
        if (hubSubscriptionId >= 0)
            Hub.unsubscribe(hubSubscriptionId);
        if (ownerAction && ownerAction.settingsWindow === settingsWindow)
            ownerAction.settingsWindow = null;
    }
    onClosing: destroy()

    property var config: ({ profiles: [] })
    property string currentProfileId: ""
    property var profileList: []

    property var allFonts: []
    property var filteredFontList: []
    property string pendingFont: Cfg.DEFAULT_FONT
    property int  pendingFontWeight: 50
    property real pendingLineHeight: Cfg.DEFAULT_LINE_HEIGHT
    property bool fontExpanded: false

    property bool loadingForm: false
    property bool formDirty: false

    QtObject { id: settingsOwner }

    function onHubNotify() {
        config = Cfg.loadConfig();
        refreshProfileList();
    }

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

    function refreshProfileList() { profileList = config.profiles.slice(); }

    function currentProfile() { return Cfg.findProfile(config, currentProfileId); }
    function markDirty() { if (!loadingForm) formDirty = true; }

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

    function pick(p, key, fallback) {
        return (p && p[key] !== undefined && p[key] !== null)
               ? p[key] : fallback;
    }

    function applyFormTo(p) {
        p.name          = profileNameField.text;
        p.title         = titleField.text;
        p.targetDate    = new Date(
            yearField.value, monthField.value - 1, dayField.value,
            hourField.value, minuteField.value, 0).toISOString();
        p.titleSize     = titleSizeField.value;
        p.valueSize     = valueSizeField.value;
        p.titleColor    = String(titleColorPicker.value);
        p.valueColor    = String(valueColorPicker.value);
        p.strokeColor   = String(strokeColorPicker.value);
        p.strokeEnabled = !!strokeSwitchPref.value;
        p.fontFamily    = settingsWindow.pendingFont || Cfg.DEFAULT_FONT;
        p.fontWeight    = settingsWindow.pendingFontWeight;
        p.lineHeight    = settingsWindow.pendingLineHeight;
    }

    function storeForm() {
        if (!settingsWindow.currentProfileId) return;

        var p = Cfg.findProfile(settingsWindow.config,
                                settingsWindow.currentProfileId);
        if (!p) {
            p = Cfg.makeDefaultProfile(
                profileNameField.text
                    || I18n.tf("settings.newProfile",
                               [settingsWindow.config.profiles.length + 1]),
                titleField.text);
            settingsWindow.config.profiles.push(p);
            settingsWindow.currentProfileId = p.id;
        }
        applyFormTo(p);
    }

    function commitToWidget() {
        storeForm();

        if (settingsWindow.targetWidget) {
            settingsWindow.targetWidget.settings.profileId
                    = settingsWindow.currentProfileId || "";
        }
        Cfg.saveConfig(settingsWindow.config, settingsOwner);
        settingsWindow.formDirty = false;

        Hub.notify();
    }

    function loadForm() {
        loadingForm = true;
        var p = currentProfile();

        profileNameField.text = pick(p, "name", "");
        titleField.text       = pick(p, "title", "");

        titleSizeField.value    = pick(p, "titleSize", 24);
        valueSizeField.value    = pick(p, "valueSize", 24);
        titleColorPicker.value  = pick(p, "titleColor", Cfg.DEFAULT_TITLE_COLOR);
        valueColorPicker.value  = pick(p, "valueColor", Cfg.DEFAULT_VALUE_COLOR);
        strokeColorPicker.value = pick(p, "strokeColor", Cfg.DEFAULT_STROKE_COLOR);
        strokeSwitchPref.value  = !!pick(p, "strokeEnabled", Cfg.DEFAULT_STROKE_ON);

        settingsWindow.pendingFont = pick(p, "fontFamily", Cfg.DEFAULT_FONT);
        settingsWindow.pendingFontWeight = pick(p, "fontWeight", 50);
        settingsWindow.pendingLineHeight =
            pick(p, "lineHeight", Cfg.DEFAULT_LINE_HEIGHT);

        fontSearchField.text = "";
        lineHeightField.text = Number(settingsWindow.pendingLineHeight).toFixed(1);
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
            spacing: settingsWindow.style.rowGap

            Label {
                text: I18n.t("settings.profile")
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
                textRole: "name"

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
                        return I18n.t("settings.noProfile");
                    if (currentIndex < 0)
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
                Layout.preferredWidth: settingsWindow.style.fieldHeight
                Layout.preferredHeight: settingsWindow.style.fieldHeight
                onClicked: {
                    settingsWindow.storeForm();
                    var name = I18n.tf("settings.newProfile",
                                       [settingsWindow.config.profiles.length + 1]);
                    var p = Cfg.makeDefaultProfile(
                        name, I18n.t("data.defaultTitleTomorrow"));
                    settingsWindow.config.profiles.push(p);
                    settingsWindow.currentProfileId = p.id;
                    settingsWindow.refreshProfileList();
                    settingsWindow.loadForm();
                    settingsWindow.formDirty = true;
                }
            }
            Button {
                text: "\u00D7"
                Layout.preferredWidth: settingsWindow.style.fieldHeight
                Layout.preferredHeight: settingsWindow.style.fieldHeight
                enabled: settingsWindow.profileList.length > 0
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
                    settingsWindow.loadForm();
                    settingsWindow.formDirty = true;
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
                width: scrollView.availableWidth - 8
                spacing: settingsWindow.style.rowGap

                Label {
                    text: I18n.t("settings.profileName")
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
                    onTextChanged: settingsWindow.markDirty()
                }

                Label {
                    text: I18n.t("settings.label.title")
                    color: settingsWindow.style.labelColor
                    font.pixelSize: settingsWindow.style.labelSize
                    font.family: settingsWindow.style.labelFont
                    Layout.topMargin: 4
                }
                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    Layout.preferredHeight: settingsWindow.style.fieldHeight
                    placeholderText: I18n.t("settings.placeholder")
                    font.pixelSize: settingsWindow.style.fieldFontSize
                    selectByMouse: true
                    leftPadding: settingsWindow.style.padH
                    rightPadding: settingsWindow.style.padH
                    onTextChanged: settingsWindow.markDirty()
                }

                Label {
                    text: I18n.t("settings.label.date")
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
                                  from: 2024; to: 2099
                                  nextField: monthField
                                  onValueChanged: settingsWindow.markDirty() }
                    NumberField { id: monthField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 1; to: 12; padWidth: 2
                                  nextField: dayField
                                  onValueChanged: settingsWindow.markDirty() }
                    NumberField { id: dayField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 1; to: 31; padWidth: 2
                                  nextField: hourField
                                  onValueChanged: settingsWindow.markDirty() }
                }

                Label {
                    text: I18n.t("settings.label.time")
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
                                  onValueChanged: settingsWindow.markDirty() }
                    NumberField { id: minuteField
                                  Layout.fillWidth: true
                                  Layout.preferredHeight: settingsWindow.style.fieldHeight
                                  from: 0; to: 59; padWidth: 2
                                  onValueChanged: settingsWindow.markDirty() }
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
                        text: I18n.t("settings.short.title")
                        color: settingsWindow.style.labelColor
                        font.pixelSize: settingsWindow.style.labelSize
                        font.family: settingsWindow.style.labelFont
                        Layout.preferredWidth: settingsWindow.style.labelWidth
                    }
                    NumberField {
                        id: titleSizeField
                        Layout.preferredWidth: settingsWindow.style.sizeWidth
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        from: 8; to: 60; padWidth: 2
                        onValueChanged: settingsWindow.markDirty()
                    }
                    ColorPicker {
                        id: titleColorPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        textColor: settingsWindow.style.labelColor
                        textSize: settingsWindow.style.labelSize
                        textFont: settingsWindow.style.labelFont
                        onValueChanged: {
                            if (settingsWindow.loadingForm) return;
                            settingsWindow.markDirty();
                        }
                    }
                }

                // ---- Value row ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: settingsWindow.style.rowGap

                    Label {
                        text: I18n.t("settings.short.value")
                        color: settingsWindow.style.labelColor
                        font.pixelSize: settingsWindow.style.labelSize
                        font.family: settingsWindow.style.labelFont
                        Layout.preferredWidth: settingsWindow.style.labelWidth
                    }
                    NumberField {
                        id: valueSizeField
                        Layout.preferredWidth: settingsWindow.style.sizeWidth
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        from: 8; to: 60; padWidth: 2
                        onValueChanged: settingsWindow.markDirty()
                    }
                    ColorPicker {
                        id: valueColorPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        textColor: settingsWindow.style.labelColor
                        textSize: settingsWindow.style.labelSize
                        textFont: settingsWindow.style.labelFont
                        onValueChanged: {
                            if (settingsWindow.loadingForm) return;
                            settingsWindow.markDirty();
                        }
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
                        label: I18n.t("settings.strokeEnabled")
                        leftPadding: 0
                        Layout.minimumWidth: settingsWindow.style.labelPlusSize
                        Layout.preferredWidth: settingsWindow.style.labelPlusSize
                        Layout.maximumWidth: settingsWindow.style.labelPlusSize
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        defaultValue: false
                        onValueChanged: {
                            if (settingsWindow.loadingForm) return;
                            settingsWindow.markDirty();
                        }
                    }

                    ColorPicker {
                        id: strokeColorPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: settingsWindow.style.fieldHeight
                        textColor: settingsWindow.style.labelColor
                        textSize: settingsWindow.style.labelSize
                        textFont: settingsWindow.style.labelFont
                        enabled: strokeSwitchPref.value
                        onValueChanged: {
                            if (settingsWindow.loadingForm) return;
                            settingsWindow.markDirty();
                        }
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
                        text: I18n.t("settings.font")
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
                        placeholderText: I18n.t("settings.fontSearch")
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
                                    settingsWindow.markDirty();
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
                            text: I18n.t("settings.fontWeight")
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
                                settingsWindow.markDirty();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: settingsWindow.style.rowGap
                        Label {
                            text: I18n.t("settings.lineHeight")
                            color: settingsWindow.style.labelColor
                            font.pixelSize: settingsWindow.style.labelSize
                            font.family: settingsWindow.style.labelFont
                            Layout.preferredWidth: settingsWindow.style.labelWidth
                        }
                        TextField {
                            id: lineHeightField
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: settingsWindow.style.fieldHeight
                            font.pixelSize: settingsWindow.style.fieldFontSize
                            selectByMouse: true
                            horizontalAlignment: TextInput.AlignHCenter
                            leftPadding: settingsWindow.style.padH
                            rightPadding: settingsWindow.style.padH
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
            spacing: settingsWindow.style.rowGap

            Button {
                text: I18n.t("settings.apply")
                Layout.fillWidth: true
                Layout.preferredHeight: settingsWindow.style.buttonHeight
                font.pixelSize: settingsWindow.style.fieldFontSize
                enabled: settingsWindow.targetWidget !== null
                onClicked: {
                    settingsWindow.commitToWidget();
                    NVG.SystemCall.messageBox({ text: I18n.t("settings.applied") });
                }
            }

            Button {
                text: I18n.t("settings.save")
                Layout.fillWidth: true
                Layout.preferredHeight: settingsWindow.style.buttonHeight
                font.pixelSize: settingsWindow.style.fieldFontSize
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
