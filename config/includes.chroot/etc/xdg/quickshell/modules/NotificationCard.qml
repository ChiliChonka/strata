//
// One notification, drawn the same way in the toast stack and in the panel.
//
// Urgency is compared numerically rather than against the NotificationUrgency
// enum so that this file does not import the notifications module: the toast
// layer and the panel must keep working — showing nothing — on a build where
// that module is missing.  0 = low, 1 = normal, 2 = critical.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

Rectangle {
    id: root

    property var notification: null
    property var services: null
    property bool compact: false

    signal dismissed()

    readonly property int urgency: notification && notification.urgency !== undefined
                                   ? notification.urgency : 1
    readonly property bool critical: urgency === 2
    readonly property string appName: notification && notification.appName
                                      ? notification.appName : "notification"
    readonly property string summary: notification && notification.summary
                                      ? notification.summary : ""
    readonly property string body: notification && notification.body
                                   ? notification.body : ""
    readonly property var actions: notification && notification.actions
                                   ? notification.actions : []

    // Fixed at creation: the notification itself carries no timestamp.
    property double stamp: 0
    property double now: 0

    readonly property string age: {
        if (stamp <= 0 || now <= 0) return "";
        const s = Math.max(0, Math.round((now - stamp) / 1000));
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        return Math.floor(s / 3600) + "h";
    }

    Component.onCompleted: {
        if (services && services.notifications && notification)
            stamp = services.notifications.stampOf(notification.id);
        now = Date.now();
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    implicitHeight: col.implicitHeight + 2 * Theme.pad
    radius: Theme.radius
    color: Theme.raised
    border.width: 1
    border.color: root.critical ? Theme.bad : Theme.lineSoft

    // The urgency stripe: a thin band down the left edge, the same device the
    // bar uses to mark an active element.
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        anchors.margins: 1
        width: 3
        radius: 1.5
        color: root.critical ? Theme.bad : (root.urgency === 0 ? Theme.subtle : Theme.accent)
        opacity: root.urgency === 0 ? 0.5 : 1
    }

    Column {
        id: col
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: Theme.pad + 4
            rightMargin: Theme.pad
            topMargin: Theme.pad
        }
        spacing: 3

        Item {
            width: parent.width
            height: 12

            Caption {
                anchors.left: parent.left
                width: parent.width - 40
                elide: Text.ElideRight
                text: root.appName
                color: root.critical ? Theme.bad : Theme.subtle
            }

            Text {
                anchors.right: closeArea.left
                anchors.rightMargin: 4
                text: root.age
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.sizeMicro
            }

            Item {
                id: closeArea
                anchors.right: parent.right
                width: 12
                height: 12

                Icon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 10
                    color: closeHover.containsMouse ? Theme.bright : Theme.subtle
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.notification) {
                            try { root.notification.dismiss(); } catch (e) { }
                        }
                        root.dismissed();
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.summary !== ""
            text: root.summary
            color: Theme.bright
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.size
            font.bold: true
        }

        Text {
            width: parent.width
            visible: root.body !== ""
            text: root.body
            textFormat: Text.PlainText
            color: Theme.text
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 3 : 8
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.sizeSm
        }

        Row {
            visible: root.actions.length > 0
            spacing: Theme.padSm
            topPadding: 3

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionButton
                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + 16
                    implicitHeight: 20
                    radius: Theme.radiusSm
                    color: actionHover.containsMouse ? Theme.overlay : Theme.surface
                    border.width: 1
                    border.color: actionHover.containsMouse ? Theme.accentDim : Theme.line

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: actionButton.modelData && actionButton.modelData.text
                              ? actionButton.modelData.text : "open"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.sizeSm
                    }

                    MouseArea {
                        id: actionHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            try { actionButton.modelData.invoke(); } catch (e) { }
                            root.dismissed();
                        }
                    }
                }
            }
        }
    }
}
