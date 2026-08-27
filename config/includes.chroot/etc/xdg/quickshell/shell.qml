//
// Strata's default Quickshell configuration.
//
// Quickshell looks for shell.qml under every XDG config directory, so this file
// in /etc/xdg is the system default. A user who creates
// ~/.config/quickshell/shell.qml replaces it entirely — theirs is found first.
// Nothing in the image edits a user's copy.
//
// AGENTS.md limits the MVP shell to useful essentials: workspaces, clock,
// network, volume, battery. Building a widget suite is explicitly out of scope,
// so this is a single bar and nothing else.
//
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // ---- Drop-in parts -----------------------------------------------------
    //
    // The bar grows with what is installed and stays this small when nothing is.
    // ADR-0003 constrains the *base image*; it does not say Strata may never
    // show more. Once someone installs a component, that component's bar element
    // comes with it — which is what "optional layer" was always supposed to
    // mean.
    //
    // A part is a QML file placed in one of these directories. It is loaded into
    // the bar's right-hand group, and is expected to size itself. Components
    // install to the system directory; a user's own parts go in their config and
    // are loaded after, so they can sit alongside.
    property var partPaths: []

    Process {
        id: partScan
        running: true
        command: ["sh", "-c",
            "cat /dev/null; " +
            "for d in /etc/xdg/quickshell/parts \"$HOME\"/.config/quickshell/parts; do " +
            "  [ -d \"$d\" ] && ls -1 \"$d\"/*.qml 2>/dev/null; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim().length > 0);
                root.partPaths = lines;
            }
        }
    }

    // Rescan, so that installing a component shows up without logging out.
    //
    // This polls rather than watching, which is not free: an `sh` every few
    // seconds, forever. It buys the thing that matters — `strata install`
    // finishes and the element is simply there. Quickshell watches the QML
    // files it loaded, and a new file in a directory it only listed is not one
    // of them; it was measured not reacting at all to that directory changing,
    // nor to the shell being touched to provoke a reload.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: partScan.running = true
    }

    // One bar per monitor. Variants instantiates the delegate for each screen,
    // so plugging in a display gets a bar without restarting the shell.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 28
            color: "#16191d"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 12

                // ---- Workspaces -------------------------------------------
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: Hyprland.workspaces
                        Rectangle {
                            required property var modelData
                            implicitWidth: 22
                            implicitHeight: 18
                            radius: 3
                            color: modelData.active ? "#6f7f8f" : "#22262b"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: modelData.active ? "#ffffff" : "#8a9199"
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ---- Clock ------------------------------------------------
                Text {
                    text: clock.date.toLocaleString(Qt.locale(), "ddd dd MMM  HH:mm")
                    color: "#d7dbe0"
                    font.pixelSize: 12
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                }

                Item { Layout.fillWidth: true }

                // ---- Volume -----------------------------------------------
                Text {
                    property var sink: Pipewire.defaultAudioSink
                    color: "#d7dbe0"
                    font.pixelSize: 12
                    visible: sink !== null
                    text: {
                        if (!sink || !sink.audio) return "";
                        if (sink.audio.muted) return "vol muted";
                        return "vol " + Math.round(sink.audio.volume * 100) + "%";
                    }

                    // Without a binding the sink's properties are not tracked.
                    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
                }

                // ---- Drop-in parts ----------------------------------------
                //
                // Each part is loaded on its own. A part that fails to load
                // leaves an empty slot rather than taking the bar down with it:
                // a broken optional extra must not cost someone their clock.
                Repeater {
                    model: root.partPaths
                    Loader {
                        required property string modelData
                        source: "file://" + modelData
                        asynchronous: true
                        onStatusChanged: {
                            if (status === Loader.Error)
                                console.warn("bar part failed to load:", modelData);
                        }
                    }
                }

                // ---- Battery ----------------------------------------------
                // Hidden on machines without one, which includes the QEMU
                // smoke test and most desktops.
                Text {
                    property var battery: UPower.displayDevice
                    color: "#d7dbe0"
                    font.pixelSize: 12
                    visible: battery && battery.isLaptopBattery && battery.isPresent
                    text: visible
                        ? "bat " + Math.round(battery.percentage * 100) + "%"
                        : ""
                }
            }
        }
    }
}
