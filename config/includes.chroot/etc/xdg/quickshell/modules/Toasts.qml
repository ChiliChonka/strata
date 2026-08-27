//
// Notifications as they arrive.
//
// One stack per monitor, but only the focused monitor shows it: a toast
// repeated on three screens is three times the interruption for one event.
//
// Critical notifications have no timer. Everything else honours the sender's
// expiry, or five seconds when it did not ask for one.
//
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme

PanelWindow {
    id: root

    required property var modelData
    property var services: null

    readonly property var svc: services ? services.notifications : null
    readonly property bool focusedHere: Hyprland.focusedMonitor
        ? Hyprland.focusedMonitor.name === modelData.name : true

    // Notifications that have been posted and not yet timed out or dismissed.
    property var queue: []

    readonly property var shown: {
        const live = root.svc ? root.svc.list : [];
        return root.queue.filter(n => live.indexOf(n) !== -1);
    }

    function drop(n) {
        root.queue = root.queue.filter(x => x !== n);
    }

    Connections {
        target: root.svc
        function onPosted(notification) {
            // Four is as many as anyone reads before they stop being separate
            // messages and become a wall.
            root.queue = root.queue.concat([notification]).slice(-4);
        }
    }

    screen: modelData
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + Theme.gap; right: Theme.gap }
    implicitWidth: 340
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.focusedHere && root.shown.length > 0

    Column {
        id: stack
        width: parent.width
        spacing: Theme.padSm

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        }

        Repeater {
            model: root.shown

            delegate: NotificationCard {
                id: card
                required property var modelData

                width: stack.width
                notification: modelData
                services: root.services
                compact: true

                onDismissed: root.drop(card.modelData)

                Timer {
                    running: !card.critical
                    interval: {
                        const t = card.modelData && card.modelData.expireTimeout !== undefined
                                ? card.modelData.expireTimeout : -1;
                        return t > 0 ? t * 1000 : 5000;
                    }
                    onTriggered: root.drop(card.modelData)
                }

                // Clicking the body puts it away without dismissing it from the
                // panel: the toast is the interruption, the panel is the record.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    z: -1
                    onClicked: root.drop(card.modelData)
                }
            }
        }
    }
}
