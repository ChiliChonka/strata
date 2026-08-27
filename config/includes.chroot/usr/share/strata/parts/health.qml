//
// System health, shown only when there is something to show.
//
// Installed by `strata install diagnostics`. It is deliberately invisible while
// everything is fine: a permanent green tick trains people to ignore it, and
// then it is worth nothing on the day it turns red.
//
// Clicking opens `strata doctor` in a terminal, which is also the command an
// agent on this system would run first.
//
// Colours come from /etc/xdg/quickshell/theme.js. They are repeated here rather
// than imported: this file is loaded by absolute path from outside the shell's
// own directory, and a relative import would not resolve. Keep the two in step.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: health

    property int failedUnits: 0
    property int crashes: 0
    readonly property bool trouble: failedUnits > 0 || crashes > 0

    visible: trouble
    implicitWidth: trouble ? label.implicitWidth + 12 : 0
    // Fixed, not bound to the parent: the parent is a Loader whose own size
    // comes from this item's implicit size, so reading parent.height here is a
    // binding loop. Qt breaks such a loop by leaving the height at 0, which
    // renders the element invisible even when it loaded correctly.
    implicitHeight: 20

    Process {
        id: probe
        // One shell invocation rather than two processes on a timer.
        command: ["sh", "-c",
            "printf '%s %s' " +
            "\"$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)\" " +
            "\"$(coredumpctl --since -24h --no-pager --no-legend 2>/dev/null | wc -l)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                health.failedUnits = parseInt(parts[0] || "0", 10) || 0;
                health.crashes     = parseInt(parts[1] || "0", 10) || 0;
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: "#3b2422"
        visible: health.trouble

        Text {
            id: label
            anchors.centerIn: parent
            font.pixelSize: 11
            color: "#d99188"
            text: {
                const bits = [];
                if (health.failedUnits > 0) bits.push(health.failedUnits + " failed");
                if (health.crashes > 0)     bits.push(health.crashes + " crashed");
                return bits.join("  ");
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: openDoctor.running = true
        }
    }

    Process {
        id: openDoctor
        command: ["sh", "-c", "foot -H sh -c 'strata doctor; printf \"\\npress enter\"; read _'"]
    }
}
