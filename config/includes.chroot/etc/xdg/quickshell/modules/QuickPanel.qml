//
// Sound and display: the sliders people reach for most often, in one panel.
//
// Output and input are both here because a call needs both, and the microphone
// is the one control that is invisible until it is urgently needed. Output
// devices are listed so that plugging in headphones does not mean opening a
// mixer.
//
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PopupPanel {
    id: root

    property var bar: null
    readonly property var brightness: bar && bar.services ? bar.services.brightness : null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    title: "Sound and display"

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // Every sink that is a real device rather than an application's stream.
    readonly property var sinks: {
        const all = Pipewire.nodes ? Pipewire.nodes.values : [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }

    function nodeLabel(n) {
        if (!n) return "";
        return n.description || n.nickname || n.name || "audio device";
    }

    function selectSink(node) {
        // The Quickshell-native way, with wpctl as the fallback for a build
        // that does not expose it.
        try {
            Pipewire.preferredDefaultAudioSink = node;
            return;
        } catch (e) {
            // fall through
        }
        if (bar && bar.services && node)
            bar.services.exec("wpctl set-default " + node.id);
    }

    // ---- Brightness --------------------------------------------------------
    Column {
        width: parent.width
        spacing: 4
        visible: root.brightness !== null && root.brightness.available

        Caption { text: "Brightness" }

        Row {
            width: parent.width
            spacing: Theme.gap

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "brightness"
                size: 16
                color: Theme.muted
            }

            Slider {
                width: parent.width - 16 - 38 - Theme.gap * 2
                anchors.verticalCenter: parent.verticalCenter
                value: root.brightness ? root.brightness.value : 0
                fill: Theme.ochre
                onMoved: v => { if (root.brightness) root.brightness.set(v); }
            }

            Text {
                width: 38
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: root.brightness ? root.brightness.percent + "%" : ""
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.sizeSm
            }
        }
    }

    // ---- Output ------------------------------------------------------------
    Column {
        width: parent.width
        spacing: 4

        Caption { text: "Output" }

        Row {
            width: parent.width
            spacing: Theme.gap

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.sink && root.sink.audio && root.sink.audio.muted
                      ? "volume-muted" : "volume"
                size: 16
                level: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                color: Theme.muted

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                    }
                }
            }

            Slider {
                width: parent.width - 16 - 38 - Theme.gap * 2
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.sink !== null
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                onMoved: v => {
                    if (!root.sink || !root.sink.audio) return;
                    root.sink.audio.muted = false;
                    root.sink.audio.volume = v;
                }
            }

            Text {
                width: 38
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: root.sink && root.sink.audio
                      ? Math.round(root.sink.audio.volume * 100) + "%" : "—"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.sizeSm
            }
        }
    }

    // ---- Input -------------------------------------------------------------
    Column {
        width: parent.width
        spacing: 4
        visible: root.source !== null

        Caption { text: "Microphone" }

        Row {
            width: parent.width
            spacing: Theme.gap

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.source && root.source.audio && root.source.audio.muted
                      ? "mic-muted" : "mic"
                size: 16
                color: Theme.muted

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.source && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;
                    }
                }
            }

            Slider {
                width: parent.width - 16 - 38 - Theme.gap * 2
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.source !== null
                fill: Theme.good
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                onMoved: v => {
                    if (!root.source || !root.source.audio) return;
                    root.source.audio.muted = false;
                    root.source.audio.volume = v;
                }
            }

            Text {
                width: 38
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: root.source && root.source.audio
                      ? Math.round(root.source.audio.volume * 100) + "%" : "—"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.sizeSm
            }
        }
    }

    // ---- Output devices ----------------------------------------------------
    Column {
        width: parent.width
        spacing: 2
        visible: root.sinks.length > 1

        Caption { text: "Output device" }

        Repeater {
            model: root.sinks

            delegate: Rectangle {
                id: deviceRow
                required property var modelData
                readonly property bool current: root.sink === modelData

                width: parent.width
                height: 26
                radius: Theme.radiusSm
                color: pick.containsMouse ? Theme.raised : "transparent"

                Rectangle {
                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 6
                    height: 6
                    radius: 3
                    color: deviceRow.current ? Theme.accent : Theme.subtle
                }

                Text {
                    anchors {
                        left: parent.left; leftMargin: 20
                        right: parent.right; rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.nodeLabel(deviceRow.modelData)
                    elide: Text.ElideRight
                    color: deviceRow.current ? Theme.text : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.sizeSm
                }

                MouseArea {
                    id: pick
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectSink(deviceRow.modelData)
                }
            }
        }
    }
}
