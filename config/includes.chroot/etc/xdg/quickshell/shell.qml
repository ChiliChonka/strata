//
// Strata's Quickshell configuration.
//
// Quickshell looks for shell.qml under every XDG config directory, so this file
// in /etc/xdg is the system default. A user who creates
// ~/.config/quickshell/shell.qml replaces it entirely — theirs is found first.
// Nothing in the image edits a user's copy.
//
// Layout of this configuration:
//
//   theme.js    every colour, radius and size, in one place
//   widgets/    the pieces the modules are built from
//   services/   what the shell reads from the system, instantiated once
//   modules/    the bar, its panels, the dock, the toasts and the OSD
//
// The desktop this describes is the one ADR-0012 settles on: a bar with the
// controls a laptop actually needs, a hidden dock, and notifications handled in
// the shell rather than by a second daemon. It is deliberately not a widget
// suite — there is no media player, no weather, no system monitor and no
// wallpaper switcher, and adding one is an argument to have against ADR-0003
// first.
//
import Quickshell
import Quickshell.Io
import QtQuick
import "modules"
import "services"

ShellRoot {
    id: root

    // ---- Drop-in parts -----------------------------------------------------
    //
    // The bar grows with what is installed and stays this small when nothing
    // is. ADR-0003 constrains the *base image*; it does not say Strata may never
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
        onTriggered: if (!partScan.running) partScan.running = true
    }

    // ---- Shared state ------------------------------------------------------
    // One notification server, one nmcli poll and one backlight probe for the
    // session, however many monitors are attached.
    Services { id: svc }

    // ---- Per-monitor surfaces ----------------------------------------------
    // Variants instantiates the delegate for each screen, so plugging in a
    // display gets a bar without restarting the shell.

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            services: svc
            partPaths: root.partPaths
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Dock { services: svc }
    }

    Variants {
        model: Quickshell.screens
        delegate: Toasts { services: svc }
    }

    Variants {
        model: Quickshell.screens
        delegate: Osd { services: svc }
    }
}
