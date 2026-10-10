// Desktop widget: renders title + countdown for this instance's profile.
import QtQuick 2.12
import QtQuick.Controls 2.12
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import "countdownconfig.js" as Cfg
import "hub.js" as Hub

T.Widget {
    id: widget

    title: qsTr("Countdown")
    solid: true
    implicitWidth: 260
    implicitHeight: 80

    action: CountdownAction { widgetRef: widget }

    menu: Menu {
        MenuItem {
            text: qsTr("Settings")
            onTriggered: widget.action.execute()
        }
    }

    readonly property string profileId: settings.profileId || ""
    property var profile: null
    property string countdownText: ""
    property int hubSubscriptionId: -1

    Component.onCompleted: {
        Cfg.ensureConfigFile(widget);

        widget.hubSubscriptionId = Hub.subscribe(function () {
            widget.refreshProfile();
            widget.refreshCountdown();
        });

        widget.refreshProfile();
        widget.refreshCountdown();
    }

    Component.onDestruction: {
        if (widget.hubSubscriptionId >= 0) {
            Hub.unsubscribe(widget.hubSubscriptionId);
            widget.hubSubscriptionId = -1;
        }
    }

    // One-shot ticker; refreshCountdown re-arms it each run so the
    // widget only wakes when a visible digit flips.
    Timer {
        id: ticker
        running: true
        repeat: false
        interval: 0
        onTriggered: widget.refreshCountdown()
    }

    // Pull this widget's entry from the shared store. The binding is
    // sticky: a stale id is kept as-is and the widget shows the empty
    // state, so a delete in another window does not silently rebind
    // this instance elsewhere. Only an unbound instance adopts the
    // first profile.
    function refreshProfile() {
        var cfg = Cfg.loadConfig();
        var p = null;
        if (cfg.profiles && cfg.profiles.length > 0) {
            p = Cfg.findProfile(cfg, widget.profileId);
            if (!p && !widget.profileId) {
                p = cfg.profiles[0];
                widget.settings.profileId = p.id;
            }
        }

        if (!widget.profile || !p) {
            if (widget.profile !== p) widget.profile = p;
        } else if (Cfg.snapshotDiffersFrom(widget.profile, p)) {
            widget.profile = p;
        }
    }

    // Recompute text and schedule the next wake-up at the moment the
    // last visible digit will change.
    function refreshCountdown() {
        var p = widget.profile;
        var targetMs = (p && p.targetDate)
                     ? new Date(p.targetDate).getTime() : 0;

        if (!targetMs || isNaN(targetMs)) {
            widget.countdownText = qsTr("Not set");
            ticker.interval = 30000;
            ticker.restart();
            return;
        }

        var diff = targetMs - Date.now();
        if (diff <= 0) {
            widget.countdownText = qsTr("Time's up!");
            ticker.interval = 30000;
            ticker.restart();
            return;
        }

        var days    = Math.floor(diff / 86400000);
        var hours   = Math.floor((diff % 86400000) / 3600000);
        var minutes = Math.floor((diff % 3600000) / 60000);
        var seconds = Math.floor((diff % 60000) / 1000);

        var text, quantum;
        if (days > 0) {
            text = days + qsTr("d") + " "
                 + hours + qsTr("h") + " "
                 + minutes + qsTr("m");
            quantum = 60000;
        } else if (hours > 0) {
            text = hours + qsTr("h") + " "
                 + minutes + qsTr("m") + " "
                 + seconds + qsTr("s");
            quantum = 1000;
        } else {
            text = minutes + qsTr("m") + " "
                 + seconds + qsTr("s");
            quantum = 1000;
        }

        widget.countdownText = text;

        var next = (diff % quantum) + 50;
        if (next < 200) next = 200;
        ticker.interval = next;
        ticker.restart();
    }

    readonly property string effectiveFontFamily:
        Cfg.makeFontStack(widget.profile ? widget.profile.fontFamily : "")

    readonly property int effectiveFontWeight:
        (widget.profile && typeof widget.profile.fontWeight === "number")
            ? widget.profile.fontWeight : Cfg.DEFAULT_FONT_WEIGHT

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

            text: widget.profile
                  ? (widget.profile.title || qsTr("Time until target"))
                  : qsTr("Time until target")

            font.family: widget.effectiveFontFamily
            font.weight: widget.effectiveFontWeight
            font.pixelSize: widget.profile
                          ? (widget.profile.titleSize || Cfg.DEFAULT_TITLE_SIZE)
                          : Cfg.DEFAULT_TITLE_SIZE
            lineHeight: widget.effectiveLineHeight
            lineHeightMode: Text.ProportionalHeight
            color: widget.profile
                 ? (widget.profile.titleColor || Cfg.DEFAULT_TITLE_COLOR)
                 : Cfg.DEFAULT_TITLE_COLOR
            style: widget.effectiveStrokeColor ? Text.Outline : Text.Normal
            styleColor: widget.effectiveStrokeColor || "transparent"
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap

            text: widget.countdownText

            font.family: widget.effectiveFontFamily
            font.weight: widget.effectiveFontWeight
            font.pixelSize: widget.profile
                          ? (widget.profile.valueSize || Cfg.DEFAULT_VALUE_SIZE)
                          : Cfg.DEFAULT_VALUE_SIZE
            lineHeight: widget.effectiveLineHeight
            lineHeightMode: Text.ProportionalHeight
            color: widget.profile
                 ? (widget.profile.valueColor || Cfg.DEFAULT_VALUE_COLOR)
                 : Cfg.DEFAULT_VALUE_COLOR
            style: widget.effectiveStrokeColor ? Text.Outline : Text.Normal
            styleColor: widget.effectiveStrokeColor || "transparent"
        }
    }
}