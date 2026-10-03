// Integer input with wheel support and zero padding.
import QtQuick 2.12
import QtQuick.Controls 2.12

TextField {
    id: root

    property int value: 0
    property int from: 0
    property int to: 100
    property int padWidth: 0
    property Item nextField: null

    signal committed()

    horizontalAlignment: TextInput.AlignHCenter
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    font.pixelSize: 15
    topPadding: 8; bottomPadding: 8
    leftPadding: 8; rightPadding: 8

    validator: IntValidator { bottom: root.from; top: root.to }

    function display(v) {
        return padWidth > 0 ? ("00000" + v).slice(-padWidth) : v.toString();
    }
    function setValue(v) {
        value = Math.max(from, Math.min(to, v));
        text = display(value);
    }
    function commitText() {
        var v = parseInt(text);
        if (isNaN(v)) v = from;
        value = Math.max(from, Math.min(to, v));
        text = display(value);
    }

    Component.onCompleted: text = display(value)
    onValueChanged: if (text !== display(value)) text = display(value)

    onActiveFocusChanged: {
        if (activeFocus) { text = value.toString(); selectAll(); }
        else commitText();
    }
    onAccepted: {
        commitText();
        if (nextField) nextField.forceActiveFocus();
        committed();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: {
            if (wheel.angleDelta.y > 0) root.setValue(root.value + 1);
            else if (wheel.angleDelta.y < 0) root.setValue(root.value - 1);
            wheel.accepted = true;
        }
    }
}
