//
// Bluetooth: what is connected, and how to connect something else.
//
// The last row of ADR-0012's table that needed a package. bluez is in the base
// image as of ADR-0014; before that this element could not have worked.
//
// Connecting is a property assignment, not a method call — the module exposes
// no methods beyond toString, and `connected`, `enabled` and `discovering` were
// each confirmed writable in its type information before this was written.
//
// Pairing is attempted here, but only the kind that needs no passkey — a
// headset or a speaker, which is what people actually pair. Setting `bonded`
// asks bluez to pair; devices that need a code shown on screen will fail,
// because nothing here can show one, and for those the panel still points at
// bluetoothctl.
//
// The first version listed only already-paired devices, which meant a machine
// that had never paired anything showed an empty list and a switch — a dead end
// that sent the user to a terminal they did not want to learn.
//
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import "root:/"

Item {
    id: bt

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool on: present && adapter.enabled

    readonly property var devices: {
        if (!present || !adapter.devices) return [];
        return adapter.devices.values;
    }
    readonly property var connectedDevices: devices.filter(d => d.connected)

    // Set while a pairing attempt is in flight, so the row can say so instead
    // of looking like nothing happened.
    property string pairing: ""

    Timer {
        id: pairTimeout
        interval: 20000
        onTriggered: bt.pairing = ""
    }

    // Discovery and pairing go through bluetoothctl rather than the properties.
    //
    // `discovering` and `bonded` are both writable according to the module's
    // type information, and assigning to `discovering` was measured to do
    // nothing at all — the adapter stayed put. bluetoothctl was measured
    // finding eight devices on the same machine a minute earlier, so that is
    // what runs. The properties are still read; only the writes were the lie.
    Process { id: scanner }
    Process { id: pairer }

    property bool searching: false
    Timer {
        id: scanWindow
        interval: 15000
        onTriggered: bt.searching = false
    }

    function search() {
        searching = true;
        scanWindow.restart();
        scanner.command = ["sh", "-c", "bluetoothctl --timeout 15 scan on >/dev/null 2>&1"];
        scanner.running = true;
    }

    function pair(addr) {
        pairing = addr;
        pairTimeout.restart();
        pairer.command = ["sh", "-c",
            "bluetoothctl pair " + addr + " >/dev/null 2>&1 && " +
            "bluetoothctl trust " + addr + " >/dev/null 2>&1; " +
            "bluetoothctl connect " + addr + " >/dev/null 2>&1"];
        pairer.running = true;
    }

    // Hidden entirely on a machine with no Bluetooth radio, like the battery
    // element on a desktop. An icon for hardware that is not there is noise.
    visible: present
    implicitWidth: present ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    function label(d) {
        return d.deviceName && d.deviceName !== "" ? d.deviceName : d.address;
    }

    BarPill {
        id: pill
        icon: !bt.on ? "bluetooth_disabled"
            : bt.connectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth"
        tint: !bt.on ? Theme.muted
            : bt.connectedDevices.length > 0 ? Theme.accent : Theme.text
        active: menu.open
        onClicked: menu.toggle()
        onHoveredChanged: if (hovered) menu.hoverOpen()
    }

    Popout {
        id: menu
        anchor: pill
        contentWidth: 250

        Column {
            width: parent.width
            spacing: 3

            Text {
                text: bt.on
                    ? (bt.connectedDevices.length > 0
                        ? bt.label(bt.connectedDevices[0])
                        : "No device connected")
                    : "Bluetooth is off"
                color: bt.on ? Theme.text : Theme.muted
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: 600
                width: parent.width
                elide: Text.ElideRight
            }
            Text {
                visible: bt.on && bt.connectedDevices.length > 1
                text: (bt.connectedDevices.length - 1) + " more connected"
                color: Theme.muted
                font.family: Theme.fontUi
                font.pixelSize: 11
                bottomPadding: 4
            }

            MenuRow {
                icon: bt.on ? "bluetooth" : "bluetooth_disabled"
                text_: bt.on ? "Bluetooth on" : "Bluetooth off"
                tint: bt.on ? Theme.accent : Theme.muted
                onActivated: if (bt.present) bt.adapter.enabled = !bt.adapter.enabled
            }

            MenuRow {
                visible: bt.on
                height: bt.on ? 30 : 0
                icon: bt.searching ? "sync" : "search"
                text_: bt.searching ? "Searching…" : "Search for devices"
                tint: bt.searching ? Theme.accent : Theme.text
                onActivated: if (!bt.searching) bt.search()
            }

            // Paired devices first, then whatever the search turned up. An
            // unpaired one is not hidden: a machine that has never paired
            // anything would otherwise show an empty list and a switch, which
            // is where this element used to leave people.
            Repeater {
                model: {
                    if (!bt.on) return [];
                    var d = bt.devices.filter(x => x.deviceName || x.bonded);
                    d.sort(function (a, b) {
                        if (a.connected !== b.connected) return a.connected ? -1 : 1;
                        if (a.bonded !== b.bonded) return a.bonded ? -1 : 1;
                        return 0;
                    });
                    return d.slice(0, 7);
                }
                MenuRow {
                    required property var modelData
                    icon: modelData.connected ? "bluetooth_connected"
                        : modelData.bonded ? "bluetooth" : "bluetooth_searching"
                    text_: bt.label(modelData)
                    tint: modelData.bonded ? Theme.text : Theme.muted
                    trailing: bt.pairing === modelData.address ? "pairing…"
                        : modelData.batteryAvailable
                            ? Math.round(modelData.battery * 100) + " pct"
                            : (modelData.bonded ? "" : "new")
                    selected: modelData.connected
                    onActivated: {
                        if (modelData.bonded) {
                            modelData.connected = !modelData.connected;
                            return;
                        }
                        // Ask bluez to pair. This works for anything that does
                        // not need a code typed or confirmed; the rest fail,
                        // and the row goes back to "new" rather than pretending.
                        bt.pair(modelData.address);
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hover }

            MenuRow {
                icon: "tune"
                text_: "Pairing that needs a code"
                onActivated: {
                    menu.close();
                    Quickshell.execDetached(["foot", "bluetoothctl"]);
                }
            }
        }
    }
}
