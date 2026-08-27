//
// The configured coding agent, one click away.
//
// Installed alongside any agent component. It shows nothing when no agent is
// present, so installing the part without an agent is harmless.
//
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: agent

    property string name: ""
    readonly property bool available: name.length > 0

    visible: available
    implicitWidth: available ? label.implicitWidth + 12 : 0
    // Fixed, not bound to the parent: the parent is a Loader whose own size
    // comes from this item's implicit size, so reading parent.height here is a
    // binding loop. Qt breaks such a loop by leaving the height at 0, which
    // renders the element invisible even when it loaded correctly.
    implicitHeight: 18

    Process {
        running: true
        // First agent found wins; the order is the order they are listed.
        command: ["sh", "-c",
            "for a in claude codex gemini opencode; do " +
            "  command -v \"$a\" >/dev/null 2>&1 && { printf '%s' \"$a\"; exit 0; }; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: agent.name = text.trim()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: "#22262b"
        visible: agent.available

        Text {
            id: label
            anchors.centerIn: parent
            font.pixelSize: 12
            color: "#8a9199"
            text: agent.name
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: launch.running = true
        }
    }

    Process {
        id: launch
        command: ["sh", "-c", "foot " + agent.name]
    }
}
