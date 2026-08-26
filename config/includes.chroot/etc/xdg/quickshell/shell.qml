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
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

ShellRoot {
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
