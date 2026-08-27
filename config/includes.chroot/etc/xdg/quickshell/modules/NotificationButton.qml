//
// The bell.
//
// Left-click opens the list, right-click switches do-not-disturb — the same
// two gestures as every other grouped element in this bar.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null
    readonly property var svc: bar && bar.services ? bar.services.notifications : null
    readonly property var prefs: bar && bar.services ? bar.services.prefs : null
    readonly property int count: svc ? svc.count : 0
    readonly property bool dnd: prefs ? prefs.dnd : false

    active: bar && bar.panelSource === "NotificationPanel.qml"

    onClicked: button => {
        if (button === Qt.RightButton) {
            if (root.prefs) root.prefs.setDnd(!root.prefs.dnd);
        } else if (bar) {
            bar.openPanel("NotificationPanel.qml", root, 340);
        }
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.dnd ? "bell-off" : "bell"
        size: 15
        color: root.count > 0 && !root.dnd ? Theme.accent : Theme.muted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.count > 0
        text: root.count
        color: root.dnd ? Theme.muted : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.size
    }
}
