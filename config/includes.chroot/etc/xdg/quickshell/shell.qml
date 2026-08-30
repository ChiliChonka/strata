//
// Strata's default Quickshell configuration.
//
// Quickshell looks for shell.qml under every XDG config directory, so this file
// in /etc/xdg is the system default. A user who creates
// ~/.config/quickshell/shell.qml replaces it entirely — theirs is found first.
// Nothing in the image edits a user's copy.
//
// AGENTS.md limited the MVP shell to workspaces, clock, network, volume and
// battery. ADR-0012 replaced that scope: the desktop must be able to do what a
// desktop does, so the bar also carries brightness, bluetooth, screenshots and
// session actions, and the shell owns the wallpaper as well. What stays out of
// scope is a widget suite — extras arrive as drop-in parts, below.
//
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/elements" as Elements

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

        // Variants takes exactly one delegate, and modelData belongs to it, so
        // the bar and its popout window are grouped rather than listed side by
        // side. Scope is Quickshell's non-visual container for precisely this.
        Scope {
            // Addressed by id, not by `parent`: a window has no visual parent,
            // so the delegate's screen has to be reachable by name.
            id: perScreen
            required property var modelData

        // Below everything, including the bar's own window.
        Wallpaper { screen: perScreen.modelData }

        PanelWindow {
            id: bar
            screen: perScreen.modelData

            // Get out of the way of a fullscreen window.
            //
            // The bar is a layer-shell surface on the top layer, and Hyprland
            // draws a fullscreen window *below* that layer — so without this
            // the top of a fullscreen video sits behind the bar rather than
            // over it. Hiding is right rather than moving to a lower layer,
            // which would put the bar behind ordinary windows too.
            //
            // Per monitor, not globally: fullscreen on one screen should not
            // blank the bar on another.
            // The workspace's hasFullscreen is true for both states, so using it
            // hid the bar when a window was merely maximized — which is the one
            // state where the bar is supposed to stay. Hyprland numbers them on
            // the window itself: 1 is maximized, 2 is fullscreen. Measured, not
            // read: both values were watched changing on a real window.
            readonly property var hlMonitor: Hyprland.monitorFor(perScreen.modelData)
            readonly property bool wsFullscreen:
                hlMonitor && hlMonitor.activeWorkspace
                    ? hlMonitor.activeWorkspace.hasFullscreen
                    : false

            // hasFullscreen cannot tell the two apart, and activeToplevel is
            // null in this Quickshell — measured on both the workspace and the
            // singleton, before and after refreshToplevels(). So Hyprland is
            // asked directly, but only when the state actually changes: the
            // alternative was another timer, and this shell has enough of those.
            property bool fullscreenHere: false
            onWsFullscreenChanged: {
                if (wsFullscreen) fsMode.running = true;
                else fullscreenHere = false;
            }

            Process {
                id: fsMode
                command: ["sh", "-c",
                    "hyprctl activewindow -j | grep -oE '\"fullscreen\": [0-9]+' | grep -oE '[0-9]+'"]
                stdout: StdioCollector {
                    onStreamFinished: bar.fullscreenHere = text.trim() === "2"
                }
            }

            visible: !fullscreenHere

            anchors { top: true; left: true; right: true }

            // The window is taller than the bar so there is somewhere to draw a
            // shadow. Without this the surface ended exactly at the bar's edge
            // and nothing could fall below it.
            //
            // The exclusive zone stays the bar's own height: the shadow is
            // drawn over whatever is underneath and must not push windows down
            // by another ten pixels.
            implicitHeight: Theme.barHeight + Theme.shadowDrop
            exclusiveZone: Theme.barHeight
            color: "transparent"

            Rectangle {
                id: barSurface
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: Theme.barHeight
                color: Theme.bar
            }

            // A gradient rather than stacked copies: this edge is straight, so
            // it needs no shape and can be a real fade.
            //
            // Five stops on a smoothstep, which is the shape of a blurred edge:
            // flat where it leaves the bar, flat where it reaches nothing, and
            // all of its slope in the middle. A straight ramp had a visible
            // kink; a square falloff was steepest right at the bar, which is
            // precisely where a soft shadow is flattest, and it still read as an
            // edge. The popout's own shadow accumulates to this same curve, so
            // the two are one shadow where they meet.
            Rectangle {
                anchors { top: barSurface.bottom; left: parent.left; right: parent.right }
                height: Theme.shadowDrop
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, Theme.shadowStrength) }
                    GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, Theme.shadowStrength * 0.8438) }
                    GradientStop { position: 0.50; color: Qt.rgba(0, 0, 0, Theme.shadowStrength * 0.5) }
                    GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, Theme.shadowStrength * 0.1563) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0) }
                }
            }

            // Anchored to the middle of the window, not placed in the row.
            //
            // As a row item between two stretching spacers it was centred in
            // whatever space the two groups left, so it moved whenever either
            // side changed width — installing an agent shifted it visibly left.
            //
            // On a narrow enough bar a long group could reach under it. Nothing
            // prevents that; the alternative is a clock that is never quite in
            // the middle.
            Elements.Clock {
                anchors.centerIn: barSurface
            }

            RowLayout {
                anchors.fill: barSurface
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
                            color: modelData.active ? Theme.accent : Theme.raised
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: modelData.active ? Theme.bar : Theme.muted
                                font.family: Theme.fontUi
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }

                // What is open, next to the workspaces it belongs with.
                Elements.Windows {}

                Item { Layout.fillWidth: true }

                // ---- The desktop's own controls ---------------------------
                //
                // ADR-0012's surface list, one file each under elements/. They
                // are named here rather than scanned: these are the desktop, not
                // optional extras, and a missing one should be a loud error.
                Elements.Screenshot {}
                Elements.Bluetooth {}
                Elements.Brightness {}
                Elements.Audio {}
                Elements.Battery {}
                Elements.Network {}

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

                Elements.Session {}

            }
        }

        // Drawn next to the bar rather than inside it: a layer-shell surface
        // cannot escape its own window, and the panel has to hang below.
        PopoutHost {
            screen: perScreen.modelData
            barWindow: bar
        }

        }
    }
}
