// Numeric input with wheel support and zero padding.
import QtQuick 2.12
import QtQuick.Controls 2.12

TextField {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property int  decimals: 0
    property int  padWidth: 0
    property Item nextField: null

    readonly property real step:
        decimals > 0 ? Math.pow(10, -decimals) : 1

    horizontalAlignment: TextInput.AlignHCenter
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    font.pixelSize: 15
    topPadding: 8; bottomPadding: 8
    leftPadding: 8; rightPadding: 8

    validator: DoubleValidator {
        bottom: root.from
        top: root.to
        decimals: root.decimals
        notation: DoubleValidator.StandardNotation
    }

    function display(v) {
        if (decimals > 0) return Number(v).toFixed(decimals);
        var n = Math.round(v);
        return padWidth > 0 ? ("00000" + n).slice(-padWidth) : String(n);
    }
    function clamp(v) {
        return Math.max(from, Math.min(to, v));
    }
    function quantize(v) {
        if (decimals <= 0) return Math.round(v);
        var p = Math.pow(10, decimals);
        return Math.round(v * p) / p;
    }
    function setValue(v) {
        value = clamp(quantize(v));
        text = display(value);
    }
    function commitText() {
        var v = parseFloat(text);
        if (isNaN(v)) v = from;
        value = clamp(quantize(v));
        text = display(value);
    }

    Component.onCompleted: text = display(value)
    onValueChanged: if (text !== display(value)) text = display(value)

    onActiveFocusChanged: {
        if (activeFocus) { text = String(value); selectAll(); }
        else commitText();
    }
    onAccepted: {
        commitText();
        if (nextField) nextField.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: root.activeFocus
        onWheel: {
            if (wheel.angleDelta.y > 0) root.setValue(root.value + root.step);
            else if (wheel.angleDelta.y < 0) root.setValue(root.value - root.step);
            wheel.accepted = true;
        }
    }
}