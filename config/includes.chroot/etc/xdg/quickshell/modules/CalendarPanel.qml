//
// The clock's panel: the time in full, the month, and how long the machine has
// been up.
//
import Quickshell
import Quickshell.Io
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PopupPanel {
    id: root

    property var bar: null
    title: "Calendar"

    // Any date inside the month being shown. Reset to today whenever the panel
    // is opened, because it is created fresh each time.
    property date shown: new Date()

    SystemClock { id: clock; precision: SystemClock.Seconds }

    readonly property int firstDow: Qt.locale().firstDayOfWeek

    readonly property var cells: {
        const y = root.shown.getFullYear();
        const m = root.shown.getMonth();
        const lead = (new Date(y, m, 1).getDay() - root.firstDow + 7) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const today = new Date();
        const isThisMonth = today.getFullYear() === y && today.getMonth() === m;

        const out = [];
        for (let i = 0; i < 42; i++) {
            const n = i - lead + 1;
            out.push({
                day: n >= 1 && n <= days ? n : 0,
                today: isThisMonth && n === today.getDate()
            });
        }
        return out;
    }

    // ---- The time itself ---------------------------------------------------
    Column {
        width: parent.width
        spacing: 2

        Text {
            text: clock.date.toLocaleString(Qt.locale(), "HH:mm:ss")
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: Theme.sizeXl
        }

        Text {
            text: clock.date.toLocaleString(Qt.locale(), "dddd, d MMMM yyyy")
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.size
        }
    }

    Divider { width: parent.width }

    // ---- Month header ------------------------------------------------------
    Item {
        width: parent.width
        height: 20

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.shown.toLocaleString(Qt.locale(), "MMMM yyyy")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.size
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 2

            Repeater {
                model: [{ d: -1, r: 90 }, { d: 0, r: 0 }, { d: 1, r: -90 }]
                delegate: Rectangle {
                    required property var modelData
                    width: 20
                    height: 20
                    radius: Theme.radiusSm
                    color: step.containsMouse ? Theme.raised : "transparent"

                    Icon {
                        anchors.centerIn: parent
                        name: modelData.d === 0 ? "calendar" : "chevron-down"
                        size: modelData.d === 0 ? 13 : 15
                        color: Theme.muted
                        rotation: modelData.r
                    }

                    MouseArea {
                        id: step
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.modelData.d === 0) {
                                root.shown = new Date();
                            } else {
                                const d = new Date(root.shown);
                                d.setDate(1);
                                d.setMonth(d.getMonth() + parent.modelData.d);
                                root.shown = d;
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Weekday headings --------------------------------------------------
    Row {
        width: parent.width
        Repeater {
            model: 7
            delegate: Caption {
                required property int index
                width: root.width / 7 - Theme.pad * 2 / 7
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDow + index) % 7, Locale.ShortFormat).slice(0, 2)
            }
        }
    }

    // ---- The grid ----------------------------------------------------------
    Grid {
        width: parent.width
        columns: 7

        Repeater {
            model: root.cells
            delegate: Item {
                required property var modelData
                width: root.width / 7 - Theme.pad * 2 / 7
                height: 24

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 20
                    radius: Theme.radiusSm
                    visible: parent.modelData.today
                    color: Theme.accentDim
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.modelData.day > 0
                    text: parent.modelData.day
                    color: parent.modelData.today ? Theme.bright : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.sizeSm
                    font.bold: parent.modelData.today
                }
            }
        }
    }

    Divider { width: parent.width }

    // ---- Uptime ------------------------------------------------------------
    Item {
        width: parent.width
        height: 14

        Caption { anchors.left: parent.left; text: "Uptime" }

        Text {
            anchors.right: parent.right
            text: uptime.pretty
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.sizeSm
        }
    }

    QtObject {
        id: uptime
        property string pretty: "—"
    }

    Process {
        id: readUptime
        running: true
        command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const secs = parseFloat(text.trim());
                if (!(secs > 0)) return;
                const d = Math.floor(secs / 86400);
                const h = Math.floor((secs % 86400) / 3600);
                const m = Math.floor((secs % 3600) / 60);
                uptime.pretty = d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: if (!readUptime.running) readUptime.running = true
    }
}
