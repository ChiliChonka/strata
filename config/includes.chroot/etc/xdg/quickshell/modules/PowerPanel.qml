//
// Lock, log out, suspend, restart, shut down.
//
// Restart and shut down ask a second time. Everything else on this panel is
// recoverable in a few seconds; those two are not, and they sit one misclick
// away from the clock.
//
import Quickshell.Io
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PopupPanel {
    id: root

    property var bar: null
    readonly property var services: bar ? bar.services : null

    // Which destructive action is waiting for a confirming second click.
    property string pending: ""

    title: "Session"

    property string who: ""

    Process {
        running: true
        command: ["sh", "-c", "printf '%s@%s' \"$(id -un)\" \"$(uname -n)\""]
        stdout: StdioCollector {
            onStreamFinished: root.who = text.trim()
        }
    }

    function act(name) {
        if (!root.services) return;
        switch (name) {
        case "lock":     root.services.lock(); break;
        case "logout":   root.services.logout(); break;
        case "suspend":  root.services.suspend(); break;
        case "reboot":   root.services.reboot(); break;
        case "poweroff": root.services.poweroff(); break;
        }
        if (root.bar) root.bar.closePanel();
    }

    function press(name, destructive) {
        if (!destructive) { root.act(name); return; }
        if (root.pending === name) { root.act(name); return; }
        root.pending = name;
        confirmTimeout.restart();
    }

    // A confirmation that waits forever is a trap of its own.
    Timer {
        id: confirmTimeout
        interval: 4000
        onTriggered: root.pending = ""
    }

    Text {
        width: parent.width
        text: root.who
        color: Theme.muted
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Theme.sizeSm
    }

    Grid {
        width: parent.width
        columns: 3
        spacing: Theme.padSm

        Repeater {
            model: [
                { key: "lock",     icon: "lock",     label: "Lock",     danger: false },
                { key: "logout",   icon: "logout",   label: "Log out",  danger: false },
                { key: "suspend",  icon: "suspend",  label: "Suspend",  danger: false },
                { key: "reboot",   icon: "restart",  label: "Restart",  danger: true  },
                { key: "poweroff", icon: "power",    label: "Shut down", danger: true }
            ]

            delegate: ActionTile {
                required property var modelData

                width: (parent.width - 2 * Theme.padSm) / 3
                icon: modelData.icon
                label: armed ? "Confirm?" : modelData.label
                danger: modelData.danger
                armed: root.pending === modelData.key
                onClicked: root.press(modelData.key, modelData.danger)
            }
        }
    }
}
