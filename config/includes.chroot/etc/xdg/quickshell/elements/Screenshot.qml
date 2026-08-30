//
// Screenshots, without having to remember which modifier does which.
//
// The keys still work — PRINT for a region, SHIFT+PRINT for the screen — and
// this is the same two commands plus the window case, for the times when
// somebody is looking for the feature rather than recalling it.
//
// Everything lands on the clipboard rather than in a file. A live session has
// nowhere sensible to put files, and a screenshot is almost always on its way
// into something else. Saving to disk is one line away for anyone who wants it.
//
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Item {
    id: shot

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Process { id: runner }

    // The bar is hidden first: it is a layer-shell surface and grim captures
    // it, so a screenshot of "the screen" would otherwise always have this
    // element's own menu in the corner of it.
    //
    // stdin comes from /dev/null, and without that nothing here worked at all.
    // slurp reads a list of candidate boxes from stdin whenever stdin is not a
    // terminal, and Quickshell hands a child process a pipe that is never
    // written to and never closed — so slurp sat in anon_pipe_read waiting for
    // an EOF that could not come. It never reached Wayland, never mapped its
    // selection surface, and printed nothing: clicking Region simply did
    // nothing, for months.
    //
    // Measured, not guessed. Under Quickshell the child had fd 0 on a pipe and
    // zero open Wayland sockets; the identical command from a shell had one,
    // and `hyprctl layers` showed its `selection` surface. With the redirect
    // the surface appears from Quickshell too. Quickshell's own
    // `stdinEnabled: false` was tried first and changed nothing.
    function take(cmd) {
        menu.close();
        runner.command = ["sh", "-c", "exec 0</dev/null; sleep 0.3; " + cmd];
        runner.running = true;
    }

    BarPill {
        id: pill
        icon: "photo_camera"
        active: menu.open
        onClicked: menu.toggle()
        onHoveredChanged: if (hovered) menu.hoverOpen()
    }

    Popout {
        id: menu
        anchor: pill
        contentWidth: 210

        Column {
            width: parent.width
            spacing: 2

            MenuRow {
                icon: "crop_free"
                text_: "Region"
                trailing: "Print"
                onActivated: shot.take("grim -g \"$(slurp)\" - | wl-copy")
            }
            MenuRow {
                icon: "web_asset"
                text_: "Window"
                onActivated: shot.take(
                    "grim -g \"$(hyprctl activewindow -j " +
                    "| grep -E '\\\"(at|size)\\\"' " +
                    "| grep -oE '[0-9]+' | paste -sd' ' " +
                    "| awk '{print $1\",\"$2\" \"$3\"x\"$4}')\" - | wl-copy")
            }
            MenuRow {
                icon: "fullscreen"
                text_: "Whole screen"
                trailing: "Shift+Print"
                onActivated: shot.take("grim - | wl-copy")
            }
        }
    }
}
