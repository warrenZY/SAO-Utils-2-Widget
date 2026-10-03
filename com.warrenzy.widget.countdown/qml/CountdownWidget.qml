// Desktop widget: renders title + countdown for this instance's profile.
import QtQuick 2.12
import QtQuick.Controls 2.12
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import "i18n.js" as I18n
import "countdownconfig.js" as Cfg

T.Widget {
    id: widget

    title: I18n.t("widget.title")
    solid: true

    implicitWidth: 260
    implicitHeight: 80

    action: CountdownAction { widgetRef: widget }

    menu: Menu {
        MenuItem {
            text: I18n.t("action.title")
            onTriggered: widget.action.execute()
        }
    }

    readonly property string profileId: settings.profileId || ""
    property var profile: null
    property string countdownText: ""

    Component.onCompleted: {
        Cfg.ensureConfigFile(widget);
        refreshProfile();
        refreshCountdown();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: widget.refreshCountdown()
    }

    // Reload the global profiles and apply this widget's entry.
    function refreshProfile() {
        var cfg = Cfg.loadConfig();
        var p = null;
        if (cfg.profiles && cfg.profiles.length > 0)
            p = Cfg.findProfile(cfg, widget.profileId) || cfg.profiles[0];

        var oldHash = widget.profile ? JSON.stringify(widget.profile) : "";
        var newHash = p ? JSON.stringify(p) : "";
        if (oldHash !== newHash)
            widget.profile = p;
    }

    function refreshCountdown() {
        var p = widget.profile;
        if (!p || !p.targetDate) {
            widget.countdownText = I18n.t("data.notSet");
            return;
        }
        var diff = new Date(p.targetDate).getTime() - Date.now();
        if (diff <= 0) {
            widget.countdownText = I18n.t("data.timesUp");
            return;
        }
        var days    = Math.floor(diff / 86400000);
        var hours   = Math.floor((diff % 86400000) / 3600000);
        var minutes = Math.floor((diff % 3600000) / 60000);
        var seconds = Math.floor((diff % 60000) / 1000);

        var text;
        if (days > 0)
            text = days + I18n.t("unit.day") + " "
                 + hours + I18n.t("unit.hour") + " "
                 + minutes + I18n.t("unit.min");
        else if (hours > 0)
            text = hours + I18n.t("unit.hour") + " "
                 + minutes + I18n.t("unit.min") + " "
                 + seconds + I18n.t("unit.sec");
        else
            text = minutes + I18n.t("unit.min") + " "
                 + seconds + I18n.t("unit.sec");
        widget.countdownText = text;
    }

    readonly property string effectiveFontFamily:
        Cfg.makeFontStack(widget.profile ? widget.profile.fontFamily : "")

    readonly property int effectiveFontWeight:
        (widget.profile && typeof widget.profile.fontWeight === "number")
            ? widget.profile.fontWeight : 50

    readonly property real effectiveLineHeight:
        (widget.profile && typeof widget.profile.lineHeight === "number")
            ? widget.profile.lineHeight : Cfg.DEFAULT_LINE_HEIGHT

    // Stroke only drawn when explicitly enabled and color is set.
    readonly property string effectiveStrokeColor: {
        if (!widget.profile) return "";
        if (!widget.profile.strokeEnabled) return "";
        return widget.profile.strokeColor || "";
    }

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight

            text: widget.profile
                  ? (widget.profile.title || I18n.t("data.defaultTitle"))
                  : I18n.t("data.defaultTitle")

            font.family: widget.effectiveFontFamily
            font.weight: widget.effectiveFontWeight
            font.pixelSize: widget.profile ? (widget.profile.titleSize || 24) : 24
            lineHeight: widget.effectiveLineHeight
            lineHeightMode: Text.ProportionalHeight
            color: widget.profile ? (widget.profile.titleColor || "#bbffffff")
                                  : "#bbffffff"
            style: widget.effectiveStrokeColor ? Text.Outline : Text.Normal
            styleColor: widget.effectiveStrokeColor || "transparent"
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            elide: Text.ElideRight

            text: widget.countdownText

            font.family: widget.effectiveFontFamily
            font.weight: widget.effectiveFontWeight
            font.pixelSize: widget.profile ? (widget.profile.valueSize || 24) : 24
            lineHeight: widget.effectiveLineHeight
            lineHeightMode: Text.ProportionalHeight
            color: widget.profile ? (widget.profile.valueColor || "#bbffffff")
                                  : "#bbffffff"
            style: widget.effectiveStrokeColor ? Text.Outline : Text.Normal
            styleColor: widget.effectiveStrokeColor || "transparent"
        }
    }
}
