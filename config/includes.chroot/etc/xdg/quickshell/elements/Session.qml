//
// Lock, log out, suspend, restart, shut down.
//
// Until this existed the only way out of a Strata session was a terminal, which
// is the least defensible gap a desktop can have. The actions are Hyprland's and
// systemd's; nothing here reimplements them.
//
// Restart and shut down are one click with no confirmation, deliberately: they
// are labelled, they sit behind a popout that takes a click to open, and a
// confirmation dialog that is always answered "yes" teaches people to click
// through dialogs.
//
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "root:/"

Item {
    id: session

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    BarPill {
        id: pill
        icon: "power_settings_new"
        tint: menu.open ? Theme.danger : Theme.text
        active: menu.open
        onHoveredChanged: if (hovered) menu.hoverOpen()
        onClicked: menu.toggle()
    }

    Popout {
        id: menu
        anchor: pill
        contentWidth: 190

        Column {
            id: content
            width: parent.width
            spacing: 2

            MenuRow {
                icon: "lock"
                text_: "Lock"
                onActivated: { menu.close(); Quickshell.execDetached(["hyprlock"]); }
            }
            MenuRow {
                icon: "bedtime"
                text_: "Suspend"
                onActivated: {
                    menu.close();
                    // Locked first, so the screen does not come back unlocked.
                    Quickshell.execDetached(["sh", "-c", "hyprlock & sleep 1; systemctl suspend"]);
                }
            }
            MenuRow {
                icon: "logout"
                text_: "Log out"
                onActivated: { menu.close(); Hyprland.dispatch("exit"); }
            }

            Rectangle {
                width: parent.width; height: 1
                color: Theme.hover
            }

            MenuRow {
                icon: "restart_alt"
                text_: "Restart"
                tint: Theme.warn
                onActivated: { menu.close(); Quickshell.execDetached(["systemctl", "reboot"]); }
            }
            MenuRow {
                icon: "power_settings_new"
                text_: "Shut down"
                tint: Theme.danger
                onActivated: { menu.close(); Quickshell.execDetached(["systemctl", "poweroff"]); }
            }
        }
    }
}
