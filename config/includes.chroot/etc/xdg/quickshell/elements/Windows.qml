//
// What is open, and a click to go there.
//
// The last row of ADR-0012's table. It sits on the left, next to the
// workspaces, because that is where a list of windows belongs and because the
// right-hand group is already the machine's status.
//
// Which window has focus is not readable from the model: Hyprland.activeToplevel
// is null in this Quickshell — measured, on the singleton and after
// refreshToplevels(), by two sessions independently. So Hyprland is asked, but
// only when it says something has changed. Hyprland.rawEvent is that signal, and
// using it is why this element has no timer.
//
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: wins

    readonly property var toplevels:
        Hyprland.toplevels ? Hyprland.toplevels.values : []

    // Only this monitor's windows, and only the workspace being looked at:
    // a task list that shows other workspaces is a list of things you cannot
    // click on without leaving where you are.
    readonly property var shown: {
        const ws = Hyprland.focusedWorkspace;
        if (!ws) return [];
        return toplevels.filter(t => t.workspace && t.workspace.id === ws.id);
    }

    property string activeAddress: ""

    implicitWidth: row.implicitWidth
    implicitHeight: 20
    visible: shown.length > 0

    Process {
        id: askActive
        command: ["sh", "-c",
            "hyprctl activewindow -j 2>/dev/null | grep -m1 '\"address\"' " +
            "| grep -oE '0x[0-9a-f]+'"]
        stdout: StdioCollector {
            onStreamFinished: wins.activeAddress = text.trim()
        }
    }

    // Events arrive in bursts — opening a window emits several — so they are
    // collapsed into one query rather than starting a process per line.
    Timer {
        id: settle
        interval: 120
        onTriggered: askActive.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { settle.restart(); }
    }

    Component.onCompleted: askActive.running = true

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: wins.shown

            Rectangle {
                required property var modelData
                readonly property bool focused:
                    wins.activeAddress !== "" &&
                    ("0x" + modelData.address) === wins.activeAddress

                implicitWidth: Math.min(160, title.implicitWidth + 16)
                implicitHeight: 18
                radius: Theme.radiusSmall
                color: focused ? Theme.hover
                     : hover.containsMouse ? Theme.raised : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.duration / 2 } }

                Text {
                    id: title
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 8; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: parent.modelData.title !== "" ? parent.modelData.title : "(untitled)"
                    color: parent.focused ? Theme.text : Theme.muted
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(
                        "focuswindow address:0x" + parent.modelData.address)
                }
            }
        }
    }
}
