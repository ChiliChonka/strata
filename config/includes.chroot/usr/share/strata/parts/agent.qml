//
// The coding agents you have, and which of them you want to look at.
//
// Installed alongside any agent component. Left-click an icon to open that
// agent; right-click anywhere on the group to choose which ones the bar shows.
// The choice is per user and survives a reboot.
//
// The marks are drawn here rather than shipped as vendor logos: the logos are
// trademarks, and an image that ships them by default is a licensing problem,
// not a design decision. Dropping real icons into
// ~/.config/strata/agent-icons/<name>.svg overrides a mark without touching
// this file.
//
// Colours come from /etc/xdg/quickshell/theme.js. They are repeated here rather
// than imported: this file is loaded by absolute path from outside the shell's
// own directory, and a relative import would not resolve. Keep the two in step.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Everything Strata knows how to install, in the order it is shown.
    readonly property var known: [
        { name: "claude",   label: "Claude Code", mark: "C", color: "#c96442" },
        { name: "codex",    label: "Codex",       mark: "O", color: "#10a37f" },
        { name: "gemini",   label: "Gemini",      mark: "G", color: "#4285f4" },
        { name: "opencode", label: "OpenCode",    mark: "K", color: "#7b8792" },
        { name: "copilot",  label: "Copilot",     mark: "P", color: "#8b949e" }
    ]

    property var present: []          // installed, in `known` order
    property var hidden: []           // deselected by the user
    readonly property var shown: present.filter(n => hidden.indexOf(n) === -1)

    readonly property string configDir: "${XDG_CONFIG_HOME:-$HOME/.config}/strata"

    visible: present.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 20

    function info(name) {
        for (var i = 0; i < known.length; i++)
            if (known[i].name === name) return known[i];
        return { name: name, label: name, mark: name.charAt(0).toUpperCase(), color: "#7b8792" };
    }

    // ---- What is installed -------------------------------------------------
    Process {
        id: detect
        running: true
        command: ["sh", "-c",
            "for a in claude codex gemini opencode copilot; do " +
            "  command -v \"$a\" >/dev/null 2>&1 && echo \"$a\"; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.present = text.split("\n").filter(l => l.trim().length > 0);
            }
        }
    }

    // An agent installed after login should show up on its own, the same way a
    // component's bar element does. Same interval, same reasoning.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: { detect.running = true; loadHidden.running = true; }
    }

    // ---- Which ones the user turned off ------------------------------------
    Process {
        id: loadHidden
        running: true
        command: ["sh", "-c", "cat " + root.configDir + "/bar-agents-hidden 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hidden = text.split("\n").filter(l => l.trim().length > 0);
            }
        }
    }

    Process { id: saveHidden }

    function toggle(name) {
        var next = root.hidden.slice();
        var i = next.indexOf(name);
        if (i === -1) next.push(name); else next.splice(i, 1);
        root.hidden = next;

        // Written through a shell so the directory is created on first use.
        var quoted = next.map(n => "'" + n + "'").join(" ");
        saveHidden.command = ["sh", "-c",
            "mkdir -p " + root.configDir + " && " +
            (next.length > 0
                ? "printf '%s\\n' " + quoted + " > " + root.configDir + "/bar-agents-hidden"
                : ": > " + root.configDir + "/bar-agents-hidden")];
        saveHidden.running = true;
    }

    Process { id: launcher }

    function launch(name) {
        launcher.command = ["sh", "-c", "foot /usr/lib/strata/hold " + name];
        launcher.running = true;
    }

    // ---- The icons in the bar ----------------------------------------------
    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: root.shown
            delegate: Rectangle {
                required property string modelData
                readonly property var meta: root.info(modelData)

                implicitWidth: 18
                implicitHeight: 20
                radius: 4
                color: hover.containsMouse ? meta.color : Qt.darker(meta.color, 1.6)
                border.width: 1
                border.color: meta.color

                Text {
                    anchors.centerIn: parent
                    text: parent.meta.mark
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) chooser.visible = !chooser.visible;
                        else root.launch(parent.modelData);
                    }
                }
            }
        }

        // With every agent hidden the group would vanish and the menu with it,
        // leaving no way back. This keeps a handle on screen.
        Rectangle {
            visible: root.shown.length === 0 && root.present.length > 0
            implicitWidth: 18
            implicitHeight: 20
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: "#4d5761"
            Text {
                anchors.centerIn: parent
                text: "···"
                color: "#7b8792"
                font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: chooser.visible = !chooser.visible
            }
        }
    }

    // ---- The chooser -------------------------------------------------------
    PanelWindow {
        id: chooser
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: 34; right: 10 }
        implicitWidth: 190
        implicitHeight: menu.implicitHeight

        Rectangle {
            id: menu
            anchors.fill: parent
            radius: 10
            color: "#171c22"
            border.width: 1
            border.color: "#333d48"
            implicitHeight: items.implicitHeight + 12

            Column {
                id: items
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 2

                Text {
                    text: "Show in bar"
                    color: "#4d5761"
                    font.pixelSize: 10
                    padding: 4
                }

                Repeater {
                    model: root.present
                    delegate: Rectangle {
                        required property string modelData
                        readonly property var meta: root.info(modelData)
                        readonly property bool on: root.hidden.indexOf(modelData) === -1

                        width: items.width
                        height: 24
                        radius: 4
                        color: rowHover.containsMouse ? "#28303a" : "transparent"

                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 4 }
                            spacing: 8

                            Rectangle {
                                width: 14; height: 14; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: parent.parent.on ? "#8fb6c9" : "transparent"
                                border.width: 1
                                border.color: parent.parent.on ? "#8fb6c9" : "#4d5761"
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.parent.parent.on
                                    text: "✓"
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                width: 14; height: 14; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: parent.parent.meta.color
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.parent.parent.meta.mark
                                    color: "#ffffff"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.parent.meta.label
                                color: "#c2cad2"
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(parent.modelData)
                        }
                    }
                }
            }
        }
    }
}
