//
// Output volume, with a slider that works and a mute that is visible.
//
// Pipewire is read through Quickshell's service rather than by shelling out to
// wpctl, so the icon follows a change made anywhere — a media key, another
// application, pavucontrol if someone installs it.
//
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"

Item {
    id: audio

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var av: sink && sink.audio ? sink.audio : null
    readonly property real volume: av ? av.volume : 0
    readonly property bool muted: av ? av.muted : false

    PwObjectTracker { objects: sink ? [sink] : [] }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    function glyph() {
        if (muted || volume <= 0) return "volume_off";
        if (volume < 0.34) return "volume_mute";
        if (volume < 0.67) return "volume_down";
        return "volume_up";
    }

    BarPill {
        id: pill
        icon: audio.glyph()
        label: audio.av ? Math.round(audio.volume * 100) + "%" : ""
        tint: audio.muted ? Theme.muted : Theme.text
        active: menu.open
        onClicked: button => {
            // Middle-ground behaviour people expect from a volume icon:
            // left opens the panel, right toggles mute without opening anything.
            if (button === Qt.RightButton && audio.av) audio.av.muted = !audio.av.muted;
            else menu.toggle();
        }
    }

    Popout {
        id: menu
        anchor: pill
        contentWidth: 230

        Column {
            id: content
            width: parent.width
            spacing: 8

            Text {
                text: audio.sink ? (audio.sink.description || audio.sink.name || "Output") : "No output device"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 12
                width: parent.width
                elide: Text.ElideRight
            }

            Slider {
                width: parent.width
                value: audio.volume
                enabled: audio.av !== null
                onMoved: v => { if (audio.av) audio.av.volume = v; }
            }

            MenuRow {
                icon: audio.muted ? "volume_off" : "volume_up"
                text_: audio.muted ? "Unmute" : "Mute"
                tint: audio.muted ? Theme.warn : Theme.text
                onActivated: if (audio.av) audio.av.muted = !audio.av.muted
            }
        }
    }
}
