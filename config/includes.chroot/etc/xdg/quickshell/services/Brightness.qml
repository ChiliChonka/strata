//
// Display backlight, via brightnessctl.
//
// There is no Quickshell service for backlights, and writing to
// /sys/class/backlight directly needs privileges the session does not have.
// brightnessctl is a 40 KB Debian package that ships the udev rule granting the
// video group write access, which is exactly the Debian-native answer ADR-0001
// asks for.
//
// A machine with no backlight — a desktop, the QEMU test — reports no device,
// and the bar element hides itself rather than showing a control that does
// nothing.
//
import Quickshell.Io
import QtQuick

Item {
    id: root

    property bool available: false
    property real value: 1.0                       // 0..1
    readonly property int percent: Math.round(value * 100)

    // Set by the OSD so it can tell a change made here from one made with the
    // brightness keys.
    signal changed()

    Runner { id: sh }

    Process {
        id: probe
        running: true
        // -m is the machine-readable form: device,class,current,percent,max
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length < 5) { root.available = false; return; }
                const cur = parseInt(f[2], 10);
                const max = parseInt(f[4], 10);
                if (!(max > 0)) { root.available = false; return; }
                root.available = true;
                const v = Math.max(0, Math.min(1, cur / max));
                if (Math.abs(v - root.value) > 0.005) {
                    root.value = v;
                    root.changed();
                }
            }
        }
    }

    // Picks up changes made with the brightness keys or by another tool.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: if (!probe.running) probe.running = true
    }

    function set(v) {
        if (!root.available) return;
        // Never all the way to zero: a black screen with no visible cause is
        // indistinguishable from a crash.
        const pct = Math.max(1, Math.min(100, Math.round(v * 100)));
        root.value = pct / 100;
        root.changed();
        sh.run("brightnessctl -q -c backlight set " + pct + "%");
    }

    function nudge(steps) { root.set(root.value + steps * 0.05); }
}
