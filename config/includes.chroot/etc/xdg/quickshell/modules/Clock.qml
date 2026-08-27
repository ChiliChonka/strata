//
// Date and time, and the way into the calendar.
//
import Quickshell
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null

    SystemClock { id: clock; precision: SystemClock.Seconds }

    active: bar && bar.panelSource === "CalendarPanel.qml"
    onClicked: if (bar) bar.openPanel("CalendarPanel.qml", root, 280)

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: clock.date.toLocaleString(Qt.locale(), "ddd d MMM")
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.size
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 10
        color: Theme.line
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: clock.date.toLocaleString(Qt.locale(), "HH:mm")
        color: Theme.bright
        font.family: Theme.font
        font.pixelSize: Theme.sizeMd
    }
}
