//
// Output volume in the bar.
//
// Scroll to change it, middle-click to mute, left-click for the panel — the
// three things people try on a volume indicator without reading anything.
//
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property real volume: audio ? audio.volume : 0

    // Without a tracker the sink's properties are read once and never update.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    visible: sink !== null
    active: bar && bar.panelSource === "QuickPanel.qml"

    onClicked: button => {
        if (button === Qt.MiddleButton) {
            if (root.audio) root.audio.muted = !root.audio.muted;
        } else if (bar) {
            bar.openPanel("QuickPanel.qml", root, 300);
        }
    }

    onScrolled: steps => {
        if (!root.audio) return;
        root.audio.muted = false;
        root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + steps * 0.05));
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.muted ? "volume-muted" : "volume"
        size: 15
        level: root.volume
        color: root.muted ? Theme.muted : Theme.text
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
        color: root.muted ? Theme.muted : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.size
    }
}
