//
// The open windows, for the dock.
//
// The Wayland foreign-toplevel protocol rather than Hyprland's own client list:
// it reports the same windows, and asking the compositor through a standard
// protocol keeps the dock from depending on hyprctl output staying the shape it
// is today.
//
// Loaded through a Loader, like the notification server: no dock is better than
// no shell.
//
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    readonly property var items: ToplevelManager.toplevels
                                 ? ToplevelManager.toplevels.values : []
    readonly property var active: ToplevelManager.activeToplevel
}
