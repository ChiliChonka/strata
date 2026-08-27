//
// The overlay that appears when volume or brightness changes.
//
// It exists for the keyboard: the media keys change a value with nothing on
// screen to confirm it, and the bar is at the top where nobody is looking while
// pressing them.
//
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PanelWindow {
    id: root

    required property var modelData
    property var services: null

    readonly property var brightness: services ? services.brightness : null
    readonly property var sink: Pipewire.defaultAudioSink

    readonly property bool focusedHere: Hyprland.focusedMonitor
        ? Hyprland.focusedMonitor.name === modelData.name : true

    property string mode: "volume"
    property bool showing: false

    // Bindings settle during startup, and every one of them looks like a
    // change. Nothing is shown until they have.
    property bool ready: false
    Timer { interval: 1500; running: true; onTriggered: root.ready = true }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    onVolumeChanged: root.flash("volume")
    onMutedChanged: root.flash("volume")

    Connections {
        target: root.brightness
        function onChanged() { root.flash("brightness"); }
    }

    function flash(which) {
        if (!root.ready) return;
        root.mode = which;
        root.showing = true;
        hide.restart();
    }

    Timer { id: hide; interval: Theme.osdHold; onTriggered: root.showing = false }

    readonly property real level: mode === "brightness"
        ? (brightness ? brightness.value : 0)
        : (muted ? 0 : volume)

    screen: modelData
    anchors { bottom: true }
    margins { bottom: 120 }
    implicitWidth: 230
    implicitHeight: 54
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.showing && root.focusedHere

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.fade(Theme.surface, 0.96)
        border.width: 1
        border.color: Theme.line

        Icon {
            id: osdIcon
            anchors { left: parent.left; leftMargin: Theme.padLg; verticalCenter: parent.verticalCenter }
            name: root.mode === "brightness"
                  ? "brightness"
                  : (root.muted ? "volume-muted" : "volume")
            size: 20
            level: root.level
            color: root.mode === "brightness" ? Theme.ochre : Theme.accent
        }

        Text {
            id: osdValue
            anchors { right: parent.right; rightMargin: Theme.padLg; verticalCenter: parent.verticalCenter }
            text: root.muted && root.mode === "volume"
                  ? "muted" : Math.round(root.level * 100) + "%"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.sizeSm
        }

        Rectangle {
            anchors {
                left: osdIcon.right; leftMargin: Theme.pad
                right: osdValue.left; rightMargin: Theme.pad
                verticalCenter: parent.verticalCenter
            }
            height: 5
            radius: 2.5
            color: Theme.raised

            Rectangle {
                width: Math.max(0, Math.min(1, root.level)) * parent.width
                height: parent.height
                radius: parent.radius
                color: root.mode === "brightness" ? Theme.ochre : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.anim } }
            }
        }
    }
}
