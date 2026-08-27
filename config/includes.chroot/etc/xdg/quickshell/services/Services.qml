//
// Everything the shell reads from the system, in one place.
//
// The bar, the dock, the toasts and the OSD all need the same state, and each
// of them exists once per monitor. Instantiating the services here and handing
// the object down means one nmcli poll and one notification server for the
// whole session, not one per screen.
//
// The two services that depend on optional Quickshell modules are behind
// Loaders. Their consumers must therefore expect null, which is also what they
// get on a machine where the feature genuinely is not there.
//
import Quickshell
import QtQuick

Item {
    id: root

    readonly property alias prefs: prefsObj
    readonly property alias brightness: brightnessObj
    readonly property alias network: networkObj
    readonly property var notifications: notificationLoader.item
    readonly property var toplevels: toplevelLoader.item

    Runner { id: sh }

    Prefs { id: prefsObj }
    Brightness { id: brightnessObj }
    NetworkService { id: networkObj }

    Loader {
        id: notificationLoader
        source: "NotificationService.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("strata: notification service unavailable");
        }
    }

    // Keep do-not-disturb in one place rather than storing it twice. Outside
    // the Loader: a Loader's default property is its sourceComponent, so a
    // Binding declared inside one is not a child, it is the thing to load.
    Binding {
        target: notificationLoader.item
        property: "dnd"
        value: prefsObj.dnd
        when: notificationLoader.item !== null
    }

    Loader {
        id: toplevelLoader
        source: "Toplevels.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("strata: toplevel service unavailable, dock disabled");
        }
    }

    // ---- Session actions ---------------------------------------------------
    //
    // systemctl rather than a DBus call: logind's polkit rules already allow an
    // active local session to do all four without a password, and shelling out
    // is one line instead of a DBus client.

    function lock()     { sh.run("/usr/lib/strata/lock"); }
    function logout()   { sh.run("hyprctl dispatch exit"); }
    function suspend()  { sh.run("/usr/lib/strata/lock & systemctl suspend"); }
    function reboot()   { sh.run("systemctl reboot"); }
    function poweroff() { sh.run("systemctl poweroff"); }

    function exec(cmd)  { sh.run(cmd); }
}
