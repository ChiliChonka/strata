//
// A square button with an icon above a label. Used by the session menu, where
// the actions are few, destructive and want to be unmistakable.
//
import QtQuick
import "../theme.js" as Theme

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool danger: false
    // Waiting for a confirming second click.
    property bool armed: false

    signal clicked()

    implicitWidth: 78
    implicitHeight: 62
    radius: Theme.radius
    color: root.armed ? Theme.fade(Theme.bad, 0.3)
                      : (ma.containsMouse
                         ? (root.danger ? Theme.fade(Theme.bad, 0.22) : Theme.overlay)
                         : Theme.raised)
    border.width: 1
    border.color: root.armed ? Theme.bad
                             : (ma.containsMouse
                                ? (root.danger ? Theme.bad : Theme.accentDim)
                                : "transparent")

    Behavior on color { ColorAnimation { duration: Theme.anim } }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.icon
            size: 20
            color: root.armed || (root.danger && ma.containsMouse) ? Theme.bad : Theme.text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.armed || ma.containsMouse ? Theme.bright : Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.sizeSm
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
