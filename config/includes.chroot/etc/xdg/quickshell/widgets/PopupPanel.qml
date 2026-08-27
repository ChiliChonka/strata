//
// The chrome shared by every panel that drops out of the bar.
//
// A panel is a plane one step lighter than the bar, with a hairline border and
// a title in the section style. It swallows clicks so that the full-screen
// dismiss area behind it only ever sees clicks that landed outside.
//
import QtQuick
import "../theme.js" as Theme

Rectangle {
    id: root

    property string title: ""
    property alias spacing: col.spacing
    default property alias content: col.data

    color: Theme.surface
    radius: Theme.radiusLg
    border.width: 1
    border.color: Theme.line

    implicitHeight: col.implicitHeight + 2 * Theme.pad
                    + (root.title !== "" ? head.height + col.spacing : 0)

    // Declared before the content so it sits underneath it.
    MouseArea { anchors.fill: parent }

    Item {
        id: head
        visible: root.title !== ""
        height: visible ? 16 : 0
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: Theme.pad

        Caption {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
        }
    }

    Column {
        id: col
        spacing: Theme.gap
        anchors {
            top: root.title !== "" ? head.bottom : parent.top
            topMargin: root.title !== "" ? col.spacing : Theme.pad
            left: parent.left
            right: parent.right
            leftMargin: Theme.pad
            rightMargin: Theme.pad
        }
    }
}
