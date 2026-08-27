//
// Network panel: what is connected, and the networks in range.
//
// Deliberately not a connection editor. ADR-0009 put nmtui in that role, and
// this panel hands over to it for anything beyond joining a network — static
// addresses, VPNs, enterprise authentication.
//
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PopupPanel {
    id: root

    property var bar: null
    readonly property var net: bar && bar.services ? bar.services.network : null

    title: "Network"

    // Scanning runs only while this panel exists.
    Component.onCompleted: if (net) net.wantScan = true;
    Component.onDestruction: if (net) net.wantScan = false;

    // ---- Current connection ------------------------------------------------
    Row {
        width: parent.width
        spacing: Theme.gap

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.net ? root.net.icon : "network-off"
            size: 20
            level: root.net ? root.net.level : 0
            color: root.net && root.net.connected ? Theme.accent : Theme.muted
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: root.net ? root.net.label : "Offline"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.sizeMd
            }

            Text {
                text: {
                    if (!root.net) return "";
                    if (!root.net.connected) return "not connected";
                    const bits = [];
                    if (root.net.device !== "") bits.push(root.net.device);
                    if (root.net.kind === "wifi" && root.net.signalStrength > 0)
                        bits.push(root.net.signalStrength + "%");
                    if (root.net.connectivity === "limited") bits.push("no internet");
                    return bits.join(" · ");
                }
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.sizeSm
            }
        }
    }

    Divider { width: parent.width }

    // ---- Wi-Fi radio -------------------------------------------------------
    Item {
        width: parent.width
        height: 22

        Caption {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Wi-Fi"
        }

        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 34
            height: 18
            radius: 9
            color: root.net && root.net.wifiRadio ? Theme.accentDim : Theme.raised
            border.width: 1
            border.color: root.net && root.net.wifiRadio ? Theme.accent : Theme.line

            Behavior on color { ColorAnimation { duration: Theme.anim } }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                y: 3
                x: root.net && root.net.wifiRadio ? 19 : 3
                color: root.net && root.net.wifiRadio ? Theme.accent : Theme.subtle
                Behavior on x { NumberAnimation { duration: Theme.anim } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.net) root.net.toggleWifi()
            }
        }
    }

    // ---- Networks in range -------------------------------------------------
    Column {
        width: parent.width
        spacing: 1
        visible: root.net !== null && root.net.wifiRadio

        Repeater {
            // A long list turns the panel into a wall. The strongest handful is
            // what anyone actually picks from; nmtui has the rest.
            model: root.net ? root.net.accessPoints.slice(0, 6) : []

            delegate: Rectangle {
                id: apRow
                required property var modelData

                width: parent.width
                height: 28
                radius: Theme.radiusSm
                color: apHover.containsMouse ? Theme.raised : "transparent"

                Icon {
                    id: apIcon
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    name: "wifi"
                    size: 14
                    level: apRow.modelData.strength / 100
                    color: apRow.modelData.inUse ? Theme.accent : Theme.muted
                }

                Text {
                    anchors {
                        left: apIcon.right; leftMargin: Theme.padSm
                        right: apLock.left; rightMargin: Theme.padSm
                        verticalCenter: parent.verticalCenter
                    }
                    text: apRow.modelData.ssid
                    elide: Text.ElideRight
                    color: apRow.modelData.inUse ? Theme.text : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.sizeSm
                }

                Icon {
                    id: apLock
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    name: apRow.modelData.secure ? "lock" : ""
                    size: 12
                    color: Theme.subtle
                    width: 12
                }

                MouseArea {
                    id: apHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.net || apRow.modelData.inUse) return;
                        root.net.connect(apRow.modelData.ssid);
                        if (root.bar) root.bar.closePanel();
                    }
                }
            }
        }
    }

    Divider { width: parent.width }

    // ---- Hand over ---------------------------------------------------------
    Rectangle {
        width: parent.width
        height: 26
        radius: Theme.radiusSm
        color: moreHover.containsMouse ? Theme.raised : "transparent"

        Text {
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            text: "Connection settings (nmtui)"
            color: moreHover.containsMouse ? Theme.text : Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.sizeSm
        }

        MouseArea {
            id: moreHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.net) root.net.openEditor();
                if (root.bar) root.bar.closePanel();
            }
        }
    }
}
