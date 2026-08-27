//
// The session menu handle.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null

    active: bar && bar.panelSource === "PowerPanel.qml"
    onClicked: if (bar) bar.openPanel("PowerPanel.qml", root, 268)

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "power"
        size: 15
        color: root.active || root.hovered ? Theme.bad : Theme.muted
    }
}
