// Renders [hex][circular swatch] inside a NERvGear ColorPreference
// and opens the system color dialog on click. Used by both the
// title/value rows and the stroke row.
import QtQuick 2.12
import QtQuick.Layouts 1.12
import NERvGear.Preferences 1.0 as P

P.ColorPreference {
    id: root

    property color  textColor:    "#666666"
    property int    textSize:     13
    property string textFont:     ""
    property int    swatchSize:   24
    property int    swatchRadius: 12
    property color  swatchBorder: "#888888"

    label: ""

    contentItem: RowLayout {
        spacing: 8
        Item { Layout.fillWidth: true }
        Text {
            text: root.value.toString().toUpperCase()
            color: root.textColor
            font.pixelSize: root.textSize
            font.family: root.textFont
            verticalAlignment: Text.AlignVCenter
        }
        Rectangle {
            Layout.preferredWidth: root.swatchSize
            Layout.preferredHeight: root.swatchSize
            radius: root.swatchRadius
            color: root.value
            border.color: root.swatchBorder
            border.width: 1
        }
    }
}
