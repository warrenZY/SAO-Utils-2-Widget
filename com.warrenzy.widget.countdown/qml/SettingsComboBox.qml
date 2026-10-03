// ComboBox with a width-constrained popup so long entries never overflow
// the right edge of the parent container.
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

ComboBox {
    id: control

    Layout.fillWidth: true
    Layout.preferredHeight: 42
    font.pixelSize: 15

    popup: Popup {
        y: control.height - 1
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 2, 320)
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            border.color: "#cccccc"
            radius: 2
            color: "#ffffff"
        }
    }
}
