//
// Charge, time remaining, and which way the machine is leaning on power.
//
// Hidden on anything without a battery, which includes desktops and the QEMU
// smoke test — so its absence in a screenshot is not evidence of a fault.
//
// Power profiles come from power-profiles-daemon over D-Bus. That package is
// not in the base image yet (ADR-0012 defers the selection), so the section
// appears only when something is answering, and says nothing when not.
//
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "root:/"

Item {
    id: batt

    readonly property var device: UPower.displayDevice
    readonly property bool present: device !== null && device.isLaptopBattery
    readonly property real level: present ? device.percentage : 0
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging

    property string profile: ""

    visible: present
    implicitWidth: present ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    function glyph() {
        if (charging) return "battery_charging_full";
        if (level >= 0.95) return "battery_full";
        if (level >= 0.60) return "battery_5_bar";
        if (level >= 0.40) return "battery_3_bar";
        if (level >= 0.15) return "battery_2_bar";
        return "battery_alert";
    }

    function tint() {
        if (charging) return Theme.ok;
        if (level < 0.10) return Theme.danger;
        if (level < 0.20) return Theme.warn;
        return Theme.text;
    }

    Process {
        id: readProfile
        running: true
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || true"]
        stdout: StdioCollector { onStreamFinished: batt.profile = text.trim() }
    }
    Timer { interval: 10000; running: batt.present; repeat: true; onTriggered: readProfile.running = true }

    Process { id: setProfile }

    BarPill {
        id: pill
        icon: batt.glyph()
        label: batt.present ? Math.round(batt.level * 100) + "%" : ""
        tint: batt.tint()
        active: menu.open
        onClicked: menu.open = !menu.open
    }

    Popout {
        id: menu
        contentWidth: 220
        contentHeight: col.implicitHeight + Theme.pad * 2

        Column {
            id: col
            anchors { fill: parent; margins: Theme.pad }
            spacing: 3

            Text {
                text: Math.round(batt.level * 100) + "%  "
                    + (batt.charging ? "charging" : "on battery")
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: 600
            }
            Text {
                readonly property real secs: batt.present
                    ? (batt.charging ? batt.device.timeToFull : batt.device.timeToEmpty) : 0
                visible: secs > 0
                text: {
                    const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
                    return (h > 0 ? h + " h " : "") + m + " min "
                         + (batt.charging ? "until full" : "remaining");
                }
                color: Theme.muted
                font.family: Theme.fontUi
                font.pixelSize: 11
                bottomPadding: 6
            }

            Repeater {
                model: batt.profile !== "" ? ["power-saver", "balanced", "performance"] : []
                MenuRow {
                    required property string modelData
                    icon: modelData === "power-saver" ? "eco"
                        : modelData === "performance" ? "bolt" : "balance"
                    text_: modelData.charAt(0).toUpperCase() + modelData.slice(1).replace("-", " ")
                    selected: modelData === batt.profile
                    onActivated: {
                        setProfile.command = ["powerprofilesctl", "set", modelData];
                        setProfile.running = true;
                        batt.profile = modelData;
                    }
                }
            }
        }
    }
}
