//
// Network state in the bar.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null
    readonly property var net: bar && bar.services ? bar.services.network : null

    active: bar && bar.panelSource === "NetworkPanel.qml"
    onClicked: if (bar) bar.openPanel("NetworkPanel.qml", root, 300)

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.net ? root.net.icon : "network-off"
        size: 15
        level: root.net ? root.net.level : 0
        color: root.net && root.net.connected ? Theme.text : Theme.muted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        // The SSID is worth the space; "Wired" and "Offline" are not, since the
        // icon already says both.
        visible: root.net !== null && root.net.kind === "wifi"
        text: root.net ? root.net.label : ""
        color: Theme.text
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 130)
        font.family: Theme.font
        font.pixelSize: Theme.size
    }
}
