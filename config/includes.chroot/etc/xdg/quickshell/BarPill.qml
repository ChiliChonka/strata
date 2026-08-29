//
// The one shape every bar element is built from.
//
// An icon, optionally a label, a hover state, and a click. Elements that need a
// panel put a Popout next to it; elements that only report state leave the
// click unconnected and it stays inert.
//
// Everything here comes from Theme, so a user writing their own element gets
// the same proportions by using this file rather than by copying numbers out
// of it.
//
import QtQuick
import "root:/"

Item {
    id: pill

    property string icon: ""            // a Material Icons ligature, e.g. "wifi"
    property string label: ""           // optional text after the icon
    property color tint: Theme.text
    property bool active: false         // draws the raised background permanently
    signal clicked(int button)

    readonly property bool hovered: area.containsMouse

    implicitWidth: row.implicitWidth + Theme.pad
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: pill.active ? Theme.hover
             : pill.hovered ? Theme.raised
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.duration / 2 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: pill.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                font.family: Theme.fontIcon
                font.pixelSize: 15
                color: pill.tint
            }
            Text {
                visible: pill.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font.family: Theme.fontUi
                font.pixelSize: 11
                color: pill.tint
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => pill.clicked(mouse.button)
    }
}
