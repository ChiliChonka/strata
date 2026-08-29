//
// One clickable line inside a popout: icon, text, optional trailing text.
//
import QtQuick
import "root:/"

Rectangle {
    id: rowItem

    property string icon: ""
    property string text_: ""
    property string trailing: ""
    property color tint: Theme.text
    property bool selected: false
    signal activated()

    width: parent ? parent.width : 200
    height: 30
    radius: Theme.radiusSmall
    color: selected ? Theme.hover : (hover.containsMouse ? Theme.raised : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.duration / 2 } }

    Text {
        id: ic
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        text: rowItem.icon
        font.family: Theme.fontIcon
        font.pixelSize: 15
        color: rowItem.tint
        visible: rowItem.icon !== ""
    }
    Text {
        anchors { left: ic.visible ? ic.right : parent.left
                  leftMargin: ic.visible ? 8 : 10
                  right: tr.left; rightMargin: 8
                  verticalCenter: parent.verticalCenter }
        text: rowItem.text_
        font.family: Theme.fontUi
        font.pixelSize: 12
        color: Theme.text
        elide: Text.ElideRight
    }
    Text {
        id: tr
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: rowItem.trailing
        font.family: Theme.fontUi
        font.pixelSize: 11
        color: Theme.muted
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: rowItem.activated()
    }
}
