//
// Display brightness, for the machines that have it.
//
// The element hides itself entirely on hardware with no backlight — a desktop
// with an external monitor has nothing here to control, and an inert slider is
// worse than no slider.
//
// brightnessctl is not in the base image yet; until it is, this writes through
// the sysfs interface the kernel already exposes. That needs the user to be in
// the `video` group, which udev grants on a normal Debian install.
//
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Item {
    id: bright

    property int current: 0
    property int maximum: 0
    property string device: ""
    readonly property bool available: device !== "" && maximum > 0
    readonly property real fraction: maximum > 0 ? current / maximum : 0

    visible: available
    implicitWidth: available ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            "d=$(ls -1 /sys/class/backlight 2>/dev/null | head -1); " +
            "[ -n \"$d\" ] || exit 0; " +
            "printf '%s %s %s' \"$d\" " +
            "\"$(cat /sys/class/backlight/$d/brightness)\" " +
            "\"$(cat /sys/class/backlight/$d/max_brightness)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/);
                if (p.length === 3) {
                    bright.device = p[0];
                    bright.current = parseInt(p[1]);
                    bright.maximum = parseInt(p[2]);
                }
            }
        }
    }

    // Someone may change brightness with a function key; without this the bar
    // would keep showing the value from login.
    Timer { interval: 4000; running: bright.available; repeat: true; onTriggered: probe.running = true }

    Process { id: setter }

    function apply(f) {
        const v = Math.max(1, Math.round(f * bright.maximum));
        bright.current = v;
        setter.command = ["sh", "-c",
            "printf '%s' " + v + " > /sys/class/backlight/" + bright.device + "/brightness"];
        setter.running = true;
    }

    BarPill {
        id: pill
        icon: bright.fraction > 0.6 ? "brightness_7"
            : bright.fraction > 0.3 ? "brightness_6" : "brightness_5"
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
            spacing: 8

            Text {
                text: "Brightness  " + Math.round(bright.fraction * 100) + "%"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 12
            }
            Slider {
                width: parent.width
                value: bright.fraction
                onMoved: v => bright.apply(v)
            }
        }
    }
}
