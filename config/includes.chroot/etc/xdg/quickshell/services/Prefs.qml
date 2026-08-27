//
// The handful of shell settings that must survive a logout.
//
// Stored as one small file per setting under ~/.config/strata, which is the
// convention the agent bar element already established. No format, no parser,
// and readable from a shell when something goes wrong.
//
import Quickshell.Io
import QtQuick

Item {
    id: root

    property bool dnd: false
    property bool dockEnabled: true

    readonly property string dir: "${XDG_CONFIG_HOME:-$HOME/.config}/strata"

    Runner { id: sh }

    Process {
        id: load
        running: true
        command: ["sh", "-c",
            "d=" + root.dir + "; " +
            "printf '%s %s' \"$(cat \"$d\"/dnd 2>/dev/null || echo 0)\" " +
            "\"$(cat \"$d\"/dock 2>/dev/null || echo 1)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/);
                root.dnd = f[0] === "1";
                root.dockEnabled = f[1] !== "0";
            }
        }
    }

    function store(key, value) {
        sh.run("mkdir -p " + root.dir + " && printf '%s\\n' " + (value ? "1" : "0")
               + " > " + root.dir + "/" + key);
    }

    function setDnd(v) { root.dnd = v; store("dnd", v); }
    function setDockEnabled(v) { root.dockEnabled = v; store("dock", v); }
}
