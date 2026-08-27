//
// Everything that has arrived and not been dismissed.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PopupPanel {
    id: root

    property var bar: null
    readonly property var services: bar ? bar.services : null
    readonly property var svc: services ? services.notifications : null
    readonly property var prefs: services ? services.prefs : null
    readonly property var list: svc ? svc.list : []

    title: "Notifications"

    // ---- Do not disturb / clear -------------------------------------------
    Item {
        width: parent.width
        height: 24

        Rectangle {
            id: dndToggle
            anchors.left: parent.left
            width: dndRow.implicitWidth + 16
            height: 22
            radius: Theme.radiusSm
            color: root.prefs && root.prefs.dnd ? Theme.accentDim
                                                : (dndHover.containsMouse ? Theme.raised : "transparent")
            border.width: 1
            border.color: root.prefs && root.prefs.dnd ? Theme.accent : Theme.line

            Row {
                id: dndRow
                anchors.centerIn: parent
                spacing: 5

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.prefs && root.prefs.dnd ? "bell-off" : "bell"
                    size: 13
                    color: root.prefs && root.prefs.dnd ? Theme.bright : Theme.muted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Do not disturb"
                    color: root.prefs && root.prefs.dnd ? Theme.bright : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.sizeSm
                }
            }

            MouseArea {
                id: dndHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.prefs) root.prefs.setDnd(!root.prefs.dnd)
            }
        }

        Text {
            anchors { right: parent.right; verticalCenter: dndToggle.verticalCenter }
            visible: root.list.length > 0
            text: "Clear all"
            color: clearHover.containsMouse ? Theme.bright : Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.sizeSm

            MouseArea {
                id: clearHover
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.svc) root.svc.dismissAll()
            }
        }
    }

    // ---- The list ----------------------------------------------------------
    Text {
        width: parent.width
        visible: root.list.length === 0
        text: root.svc === null
              ? "Notification service unavailable."
              : "Nothing here."
        color: Theme.subtle
        horizontalAlignment: Text.AlignHCenter
        topPadding: 12
        bottomPadding: 12
        font.family: Theme.font
        font.pixelSize: Theme.sizeSm
    }

    // Newest first, and capped: a panel taller than the screen is unusable, and
    // anything older than the last dozen is scrollback nobody reads.
    Column {
        width: parent.width
        spacing: Theme.padSm

        Repeater {
            model: root.list.slice().reverse().slice(0, 12)

            delegate: NotificationCard {
                required property var modelData
                width: parent.width
                notification: modelData
                services: root.services
                compact: true
            }
        }
    }
}
