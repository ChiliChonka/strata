//
// What is focused, next to the workspaces.
//
// Hyprland tiles without decorations, so on a busy workspace the only thing
// naming the focused window is the bar. Elided rather than allowed to grow: the
// clock in the centre is a fixed landmark and must not move.
//
import QtQuick
import "../theme.js" as Theme

Item {
    id: root

    property var bar: null
    readonly property var toplevels: bar && bar.services ? bar.services.toplevels : null
    readonly property var active: toplevels ? toplevels.active : null

    readonly property string appId: active && active.appId ? active.appId : ""
    readonly property string title: active && active.title ? active.title : ""

    visible: title !== ""
    implicitWidth: visible ? Math.min(row.implicitWidth, 340) : 0
    implicitHeight: Theme.itemH

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.padSm

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 12
            radius: 1.5
            color: Theme.accentDim
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 320)
            text: root.title
            color: Theme.muted
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.size
        }
    }
}
