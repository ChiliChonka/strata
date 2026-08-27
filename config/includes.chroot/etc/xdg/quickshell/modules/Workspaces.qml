//
// The workspace strip.
//
// Drawn as a stratigraphic column laid on its side: the current workspace is a
// filled band, ones that exist are outlined chips, and the rest are markers.
// Hyprland only keeps a workspace alive while something is on it, so "exists"
// and "has windows" are the same question and no extra IPC is needed to answer
// it.
//
// Workspaces 1 to 5 are always shown so the strip does not jump around as
// windows open and close; anything above that appears only while in use.
//
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme

Row {
    id: root

    property var bar: null
    readonly property string monitorName: bar && bar.modelData ? bar.modelData.name : ""

    spacing: 3

    readonly property var entries: {
        const live = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const mine = {};
        for (let i = 0; i < live.length; i++) {
            const w = live[i];
            if (!w || w.id < 1) continue;                 // special workspaces
            if (root.monitorName !== "" && w.monitor && w.monitor.name !== root.monitorName)
                continue;
            mine[w.id] = w;
        }

        const out = [];
        for (let n = 1; n <= 5; n++)
            out.push({ id: n, name: mine[n] ? mine[n].name : String(n),
                       used: mine[n] !== undefined,
                       active: mine[n] !== undefined && mine[n].active === true });

        const extra = [];
        for (const key in mine) {
            const n = parseInt(key, 10);
            if (n > 5) extra.push(n);
        }
        extra.sort((a, b) => a - b);
        for (let i = 0; i < extra.length; i++) {
            const n = extra[i];
            out.push({ id: n, name: mine[n].name, used: true,
                       active: mine[n].active === true });
        }
        return out;
    }

    Repeater {
        model: root.entries

        delegate: Rectangle {
            id: chip
            required property var modelData

            implicitWidth: modelData.active ? 26 : (modelData.used ? 20 : 12)
            implicitHeight: 16
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.radiusSm

            color: modelData.active ? Theme.accent
                                    : (modelData.used ? Theme.raised : "transparent")
            border.width: modelData.used && !modelData.active ? 1 : 0
            border.color: Theme.line

            Behavior on implicitWidth { NumberAnimation { duration: Theme.anim } }
            Behavior on color { ColorAnimation { duration: Theme.anim } }

            Text {
                anchors.centerIn: parent
                visible: chip.modelData.used
                text: chip.modelData.name
                color: chip.modelData.active ? Theme.base : Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.sizeSm
                font.bold: chip.modelData.active
            }

            // An unused workspace is a marker, not a button-shaped void.
            Rectangle {
                anchors.centerIn: parent
                visible: !chip.modelData.used
                width: 3
                height: 3
                radius: 1.5
                color: hover.containsMouse ? Theme.muted : Theme.subtle
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + chip.modelData.id)
            }
        }
    }

    MouseArea {
        // Scrolling anywhere over the strip walks through workspaces, which is
        // the one gesture people try without being told.
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Hyprland.dispatch(wheel.angleDelta.y > 0 ? "workspace e-1"
                                                                   : "workspace e+1")
    }
}
