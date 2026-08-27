//
// Display brightness in the bar.
//
// Hidden entirely on a machine with no backlight, which is every desktop and
// the QEMU test image.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null
    readonly property var svc: bar && bar.services ? bar.services.brightness : null

    visible: svc !== null && svc.available
    active: bar && bar.panelSource === "QuickPanel.qml"

    onClicked: if (bar) bar.openPanel("QuickPanel.qml", root, 300)
    onScrolled: steps => { if (root.svc) root.svc.nudge(steps); }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: "brightness"
        size: 15
        color: Theme.text
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.svc ? root.svc.percent + "%" : ""
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.size
    }
}
