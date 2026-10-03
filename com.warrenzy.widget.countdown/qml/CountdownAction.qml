// Opens the settings window bound to the widget that triggered it.
import NERvGear 1.0 as NVG
import NERvGear.Templates 1.0 as T
import QtQuick 2.12
import "i18n.js" as I18n

T.Action {
    id: thiz

    title: I18n.t("action.title")
    description: title

    property var widgetRef: null
    property var settingsWindow: null

    execute: function () {
        if (!thiz.widgetRef) {
            console.warn("[countdown] no widgetRef on Action");
            return;
        }
        if (thiz.settingsWindow) {
            try { thiz.settingsWindow.requestActivate(); return; }
            catch (e) { thiz.settingsWindow = null; }
        }

        var component = Qt.createComponent(
            Qt.resolvedUrl("CountdownSettings.qml"));
        if (component.status !== Component.Ready) {
            console.warn("CountdownSettings load failed: "
                         + component.errorString());
            return;
        }
        var win = component.createObject(thiz, {
            "targetWidget": thiz.widgetRef,
            "ownerAction":  thiz
        });
        if (!win) {
            console.warn("Failed to create CountdownSettings window");
            return;
        }
        thiz.settingsWindow = win;
    }
}
