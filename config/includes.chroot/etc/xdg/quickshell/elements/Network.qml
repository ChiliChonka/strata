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

    // The interface the traffic is actually on — the device's name (enp0s2,
    // wlan0), not the network's.
    readonly property var activeDevice: wired ? wiredDevice : wifiDevice
    readonly property string ifname: activeDevice ? (activeDevice.name || "") : ""
    // NetworkDevice.address is the MAC — measured on real hardware, where it
    // returned 2C:F0:5D:E0:23:32 for a wired link. The address a person opens
    // this panel to read is the IPv4 one, and the API does not expose it, so it
    // is read from `ip` alongside the throughput counters.
    property string ipv4: ""

    property real rxRate: 0      // bytes per second
    property real txRate: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastAt: 0

    // Throughput is not in the networking API, so it is differentiated from the
    // kernel's byte counters. Sampled only while the panel is open: a shell that
    // polls the network every second whether or not anyone is looking is exactly
    // the kind of cost this project keeps saying it does not want.
    Process {
        id: traffic
        command: ["sh", "-c",
            "cat /sys/class/net/" + net.ifname + "/statistics/rx_bytes " +
            "    /sys/class/net/" + net.ifname + "/statistics/tx_bytes 2>/dev/null; " +
            "ip -4 -brief addr show " + net.ifname + " 2>/dev/null " +
            "  | awk '{print $3}' | cut -d/ -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split(/\s+/);
                net.ipv4 = lines.length > 2 ? lines[2] : "";
                const v = [Number(lines[0]), Number(lines[1])];
                if (isNaN(v[0]) || isNaN(v[1])) return;
                const now = Date.now() / 1000;
                if (net.lastRx >= 0 && now > net.lastAt) {
                    const dt = now - net.lastAt;
                    net.rxRate = Math.max(0, (v[0] - net.lastRx) / dt);
                    net.txRate = Math.max(0, (v[1] - net.lastTx) / dt);
                }
                net.lastRx = v[0]; net.lastTx = v[1]; net.lastAt = now;
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: menu.open && net.ifname !== ""
        // Fire once as soon as the panel opens, so the address is there
        // immediately rather than a second and a half later.
        triggeredOnStart: true
        onTriggered: traffic.running = true
    }

    // Reset when the panel closes, so reopening does not show a rate averaged
    // over the minutes it was shut.
    onIfnameChanged: { lastRx = -1; rxRate = 0; txRate = 0; }

    function rate(bytesPerSecond) {
        const b = bytesPerSecond;
        if (b < 1024)        return Math.round(b) + " B/s";
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " kB/s";
        return (b / 1024 / 1024).toFixed(1) + " MB/s";
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
        onHoveredChanged: if (hovered) menu.hoverOpen()
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
                text: {
                    var parts = [];
                    if (net.ifname) parts.push(net.ifname);
                    if (net.activeWifi) parts.push(Math.round(net.strength(net.activeWifi) * 100) + "%");
                    if (!net.wired && !net.activeWifi) parts.push(net.wifiOn ? "Wi-Fi is on" : "Wi-Fi is off");
                    return parts.join("  ·  ");
                }
                color: Theme.muted
                font.family: Theme.fontUi
                font.pixelSize: 11
            }

            // Address and throughput, shown only when there is a link. Both are
            // what someone opens this panel to find out; neither is worth a row
            // when there is nothing connected.
            Item {
                width: parent.width
                height: (net.wired || net.activeWifi) ? 40 : 6
                visible: true

                Column {
                    visible: net.wired || net.activeWifi
                    width: parent.width
                    spacing: 2
                    topPadding: 6

                    Text {
                        text: net.ipv4 !== "" ? net.ipv4 : "no address yet"
                        color: net.ipv4 !== "" ? Theme.text : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                    // The glyph and the number are separate Texts because they
                    // are in different fonts: writing "down_arrow" in the UI
                    // font prints the word, not the arrow.
                    Row {
                        spacing: 14
                        Repeater {
                            model: [["arrow_downward", net.rate(net.rxRate)],
                                    ["arrow_upward",   net.rate(net.txRate)]]
                            Row {
                                required property var modelData
                                spacing: 3
                                Text {
                                    text: parent.modelData[0]
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 13
                                    color: Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: parent.modelData[1]
                                    font.family: Theme.fontUi
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
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
