//
// Network state, read from nmcli.
//
// ADR-0009 chose NetworkManager with no graphical applet: the shell shows
// state, nmtui configures. This keeps that split — everything here is a read,
// except the two actions a bar is genuinely expected to offer (toggle the Wi-Fi
// radio, join a network), and joining a protected network hands over to nmcli's
// own interactive prompt in a terminal rather than reimplementing a password
// dialog.
//
import Quickshell.Io
import QtQuick

Item {
    id: root

    // "wifi", "ethernet", "none"
    property string kind: "none"
    property bool connected: false
    property bool wifiRadio: true
    property string ssid: ""
    property string device: ""
    property int signalStrength: 0                 // 0..100, Wi-Fi only
    property string connectivity: ""
    property var accessPoints: []

    // Scanning is expensive and only interesting while the panel is open.
    property bool wantScan: false

    readonly property real level: signalStrength / 100

    readonly property string label: {
        if (kind === "wifi") return ssid !== "" ? ssid : "Wi-Fi";
        if (kind === "ethernet") return "Wired";
        return "Offline";
    }

    readonly property string icon: {
        if (kind === "ethernet") return "ethernet";
        if (kind === "wifi") return "wifi";
        return wifiRadio ? "network-off" : "wifi-off";
    }

    Runner { id: sh }

    // nmcli's terse output escapes a literal colon as "\:" and a backslash as
    // "\\". Splitting on ":" without accounting for that mangles any SSID
    // containing one.
    function split(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line.charAt(i);
            if (c === "\\" && i + 1 < line.length) { cur += line.charAt(i + 1); i++; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c",
            "command -v nmcli >/dev/null 2>&1 || exit 0; " +
            "printf 'RADIO:%s\\n' \"$(nmcli -t radio wifi 2>/dev/null)\"; " +
            "printf 'CONN:%s\\n' \"$(nmcli -t -f CONNECTIVITY general status 2>/dev/null)\"; " +
            "nmcli -t -f TYPE,STATE,CONNECTION,DEVICE device status 2>/dev/null " +
            "  | sed 's/^/DEV:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kind = "none", ssid = "", device = "", connected = false;

                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const raw = lines[i];
                    if (raw.length === 0) continue;
                    const tag = raw.slice(0, raw.indexOf(":"));
                    const rest = raw.slice(raw.indexOf(":") + 1);

                    if (tag === "RADIO") {
                        root.wifiRadio = rest.trim() === "enabled";
                    } else if (tag === "CONN") {
                        root.connectivity = rest.trim();
                    } else if (tag === "DEV") {
                        const f = root.split(rest);
                        if (f.length < 4 || f[1] !== "connected") continue;
                        // Wired wins over Wi-Fi when both are up: it is the one
                        // actually carrying the traffic.
                        if (f[0] === "ethernet" && kind !== "ethernet") {
                            kind = "ethernet"; device = f[3]; ssid = f[2]; connected = true;
                        } else if (f[0] === "wifi" && kind === "none") {
                            kind = "wifi"; device = f[3]; ssid = f[2]; connected = true;
                        }
                    }
                }

                root.kind = kind;
                root.ssid = ssid;
                root.device = device;
                root.connected = connected;
                if (kind !== "wifi") root.signalStrength = 0;
            }
        }
    }

    Process {
        id: scan
        command: ["sh", "-c",
            "command -v nmcli >/dev/null 2>&1 || exit 0; " +
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0) continue;
                    const f = root.split(lines[i]);
                    if (f.length < 4) continue;
                    const name = f[1];
                    if (name === "" || seen[name] !== undefined) continue;
                    seen[name] = true;
                    const entry = {
                        inUse: f[0].trim() === "*",
                        ssid: name,
                        strength: parseInt(f[2], 10) || 0,
                        secure: f[3].trim() !== "" && f[3].trim() !== "--"
                    };
                    if (entry.inUse) root.signalStrength = entry.strength;
                    out.push(entry);
                }
                out.sort((a, b) => b.strength - a.strength);
                root.accessPoints = out;
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    Timer {
        interval: 8000
        running: root.wantScan
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!scan.running) scan.running = true
    }

    function toggleWifi() {
        sh.run("nmcli radio wifi " + (root.wifiRadio ? "off" : "on"));
        root.wifiRadio = !root.wifiRadio;
    }

    function connect(ssid) {
        // Try it silently first: a network whose secret NetworkManager already
        // holds should just join. Only when that fails is a terminal opened, so
        // nmcli can ask for the password itself — Strata does not reimplement a
        // secret dialog, and a wrong one here would be a security question, not
        // a design one.
        sh.runWith(
            "nmcli device wifi connect \"$1\" >/dev/null 2>&1 || " +
            "foot -T 'Strata network' sh -c 'nmcli --ask device wifi connect \"$1\"; " +
            "printf \"\\npress enter \"; read _' sh \"$1\"",
            [ssid]);
    }

    function openEditor() {
        sh.run("foot -T 'Strata network' nmtui");
    }
}
