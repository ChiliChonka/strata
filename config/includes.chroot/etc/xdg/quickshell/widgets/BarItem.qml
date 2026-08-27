//
// One element in the bar.
//
// Everything clickable in the bar is one of these, so hover feedback, hit area,
// height and corner radius are decided once. Children are laid out in a row and
// the element sizes itself around them.
//
import QtQuick
import "../theme.js" as Theme

Rectangle {
    id: root

    // Drawn as "open": the element whose panel is currently showing.
    property bool active: false
    property bool marked: false          // a thin accent rule underneath
    property alias hovered: ma.containsMouse
    property int spacing: Theme.padSm
    default property alias content: box.data

    signal clicked(int button)
    signal scrolled(real steps)

    implicitWidth: box.implicitWidth + 2 * Theme.padSm
    implicitHeight: Theme.itemH
    radius: Theme.radiusSm
    color: active ? Theme.overlay
                  : (ma.containsMouse ? Theme.raised : "transparent")

    Behavior on color { ColorAnimation { duration: Theme.anim } }

    // Fixed height, so that children can simply anchor their vertical centre
    // to it without the Row's own height depending on them.
    Row {
        id: box
        anchors.centerIn: parent
        height: root.implicitHeight
        spacing: root.spacing
    }

    Rectangle {
        visible: root.marked || root.active
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins: 3
        height: 1.5
        radius: 1
        color: Theme.accent
        opacity: root.active ? 1.0 : 0.55
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse.button)
        onWheel: wheel => root.scrolled(wheel.angleDelta.y / 120)
    }
}
