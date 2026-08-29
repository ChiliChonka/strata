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
// Pairing a new device is not done here. It needs a passkey exchange and a
// dialog to show it in, and a half-built pairing flow is worse than sending
// someone to bluetoothctl, which does it properly.
//
import Quickshell
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

            // Devices this machine already knows, connected ones first. An
            // unpaired device is not listed: connecting to one needs a passkey
            // exchange this element cannot show.
            Repeater {
                model: {
                    if (!bt.on) return [];
                    var known = bt.devices.filter(d => d.bonded);
                    known.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));
                    return known.slice(0, 6);
                }
                MenuRow {
                    required property var modelData
                    icon: modelData.connected ? "bluetooth_connected" : "bluetooth"
                    text_: bt.label(modelData)
                    trailing: modelData.batteryAvailable
                        ? Math.round(modelData.battery * 100) + " pct" : ""
                    selected: modelData.connected
                    onActivated: modelData.connected = !modelData.connected
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.hover }

            MenuRow {
                icon: "tune"
                text_: "Pair a device"
                onActivated: {
                    menu.close();
                    Quickshell.execDetached(["foot", "bluetoothctl"]);
                }
            }
        }
    }
}
