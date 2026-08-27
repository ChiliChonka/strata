//
// A value between 0 and 1, dragged with the mouse or nudged with the wheel.
//
// QtQuick.Controls would provide one, but that is a separate Debian package
// (qml6-module-qtquick-controls) that nothing else in the image needs. A track,
// a fill and a MouseArea are cheaper than a dependency.
//
import QtQuick
import "../theme.js" as Theme

Item {
    id: root

    property real value: 0
    property color fill: Theme.accent
    property real step: 0.05

    // Emitted while dragging as well as on a wheel notch, so the caller can
    // apply the value live.
    signal moved(real value)

    // `enabled` is Item's own: setting it false both greys the track and stops
    // the MouseArea from seeing anything.
    implicitHeight: 20

    function apply(x) {
        if (!root.enabled) return;
        const v = Math.max(0, Math.min(1, x / Math.max(1, track.width)));
        root.moved(v);
    }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6
        radius: 3
        color: Theme.raised

        Rectangle {
            width: Math.max(0, Math.min(1, root.value)) * parent.width
            height: parent.height
            radius: parent.radius
            color: root.enabled ? root.fill : Theme.subtle
            Behavior on width { NumberAnimation { duration: Theme.anim } }
        }
    }

    Rectangle {
        id: knob
        width: 12
        height: 12
        radius: 6
        y: (root.height - height) / 2
        x: Math.max(0, Math.min(1, root.value)) * (track.width - width)
        color: root.enabled ? Theme.bright : Theme.subtle
        opacity: ma.containsMouse || ma.pressed ? 1 : 0.85
        Behavior on x { NumberAnimation { duration: Theme.anim } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => root.apply(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.apply(mouse.x); }
        onWheel: wheel => {
            if (!root.enabled) return;
            const dir = wheel.angleDelta.y > 0 ? 1 : -1;
            root.moved(Math.max(0, Math.min(1, root.value + dir * root.step)));
        }
    }
}
