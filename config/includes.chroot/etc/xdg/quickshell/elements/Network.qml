//
// Network: what you are on, and how to get on something else.
//
// Quickshell reads NetworkManager directly, so this reacts to a link change
// without polling. Picking a visible network and connecting to it happens here
// (ADR-0012 asks for that inline); everything rarer — static addresses, VPN,
// a captive portal that needs a browser — is handed to nmtui, because the
// alternative is growing a second network settings application.
//
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import "root:/"

Item {
    id: net

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: deviceOfType(DeviceType.Wifi)
    readonly property var wiredDevice: deviceOfType(DeviceType.Wired)
    readonly property var activeWifi: connectedWifi()

    readonly property bool wired: wiredDevice !== null && wiredDevice.connected
    readonly property bool wifiOn: Networking.wifiEnabled

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    function deviceOfType(t) {
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === t) return devices[i];
        return null;
    }

    function connectedWifi() {
        if (!wifiDevice || !wifiDevice.networks) return null;
        const list = wifiDevice.networks.values;
        for (var i = 0; i < list.length; i++)
            if (list[i].connected) return list[i];
        return null;
    }

    // signalStrength is a double with no documented range. Treating a 0..100
    // scale as 0..1 would print "8000%" and peg the icon at full bars, so the
    // value is normalised rather than trusted.
    function strength(n) {
        if (!n) return 0;
        var s = n.signalStrength;
        if (s > 1.0) s = s / 100.0;
        return Math.max(0, Math.min(1, s));
    }

    function bars(s) {
        if (s >= 0.75) return "signal_wifi_4_bar";
        if (s >= 0.5)  return "network_wifi_3_bar";
        if (s >= 0.25) return "network_wifi_2_bar";
        if (s > 0)     return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    BarPill {
        id: pill
        icon: net.wired ? "settings_ethernet"
            : net.activeWifi ? net.bars(net.strength(net.activeWifi))
            : net.wifiOn ? "signal_wifi_0_bar" : "wifi_off"
        tint: (net.wired || net.activeWifi) ? Theme.text : Theme.muted
        active: menu.open
        onClicked: menu.toggle()
    }

    Popout {
        id: menu
        anchor: pill
        contentWidth: 250

        Column {
            id: content
            width: parent.width
            spacing: 3

            Text {
                text: net.wired ? "Ethernet"
                    : net.activeWifi ? net.activeWifi.name
                    : "Not connected"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: 600
            }
            Text {
                text: net.wired && net.wiredDevice ? net.wiredDevice.name
                    : net.activeWifi ? Math.round(net.strength(net.activeWifi) * 100) + "% signal"
                    : net.wifiOn ? "Wi-Fi is on" : "Wi-Fi is off"
                color: Theme.muted
                font.family: Theme.fontUi
                font.pixelSize: 11
                bottomPadding: 6
            }

            MenuRow {
                icon: net.wifiOn ? "wifi" : "wifi_off"
                text_: net.wifiOn ? "Wi-Fi on" : "Wi-Fi off"
                tint: net.wifiOn ? Theme.accent : Theme.muted
                onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            // Visible networks, strongest first, the current one excluded
            // because it is already named above.
            Repeater {
                model: {
                    if (!net.wifiOn || !net.wifiDevice || !net.wifiDevice.networks) return [];
                    var out = net.wifiDevice.networks.values.filter(n => !n.connected && n.name);
                    out.sort((a, b) => net.strength(b) - net.strength(a));
                    return out.slice(0, 5);
                }
                MenuRow {
                    required property var modelData
                    icon: net.bars(net.strength(modelData))
                    text_: modelData.name
                    trailing: modelData.known ? "saved" : ""
                    onActivated: {
                        // Only a saved network can be joined without asking for
                        // a passphrase, and a passphrase prompt is a dialog this
                        // element deliberately does not have.
                        if (modelData.known) modelData.connectWithSettings();
                        else Quickshell.execDetached(["foot", "nmtui-connect", modelData.name]);
                        menu.close();
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1
                color: Theme.hover
                anchors.horizontalCenter: parent.horizontalCenter
            }

            MenuRow {
                icon: "tune"
                text_: "Network settings"
                onActivated: { menu.close(); Quickshell.execDetached(["foot", "nmtui"]); }
            }
        }
    }
}
