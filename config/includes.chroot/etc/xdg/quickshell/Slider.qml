//
// A drag-anywhere slider, written rather than imported.
//
// QtQuick.Controls would bring a Slider, but it also brings a style that has
// its own opinion about colour and would need overriding in six places to
// match Theme. Forty lines is cheaper than fighting that, and it stays readable
// for someone adapting it.
//
import QtQuick
import "root:/"

Item {
    id: slider

    property real value: 0            // 0..1
    property bool enabled: true
    signal moved(real value)

    implicitHeight: 18

    function setFromX(x) {
        if (!slider.enabled) return;
        const v = Math.max(0, Math.min(1, x / slider.width));
        slider.value = v;
        slider.moved(v);
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 5
        radius: height / 2
        color: Theme.hover

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * slider.value
            radius: height / 2
            color: slider.enabled ? Theme.accent : Theme.dim
        }
    }

    Rectangle {
        x: slider.width * slider.value - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 12
        radius: 6
        color: slider.enabled ? Theme.text : Theme.dim
        visible: slider.enabled
        scale: area.pressed ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: Theme.duration / 2 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: slider.enabled
        cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => slider.setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) slider.setFromX(mouse.x); }
    }
}
