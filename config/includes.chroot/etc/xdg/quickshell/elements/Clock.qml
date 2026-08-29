//
// The time, and a month when you click it.
//
// Anchored to the middle of the bar by whoever instantiates it, not placed in
// the row: sitting between two stretching spacers centres a clock in the space
// the other groups leave, so it drifts whenever either side changes width.
//
import Quickshell
import QtQuick
import "root:/"

Item {
    id: clockEl

    // The month being looked at, as an offset from the current one, so paging
    // back and forth does not need date arithmetic scattered around.
    property int monthOffset: 0

    readonly property date now: sysClock.date
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)

    SystemClock { id: sysClock; precision: SystemClock.Minutes }

    implicitWidth: label.implicitWidth + Theme.pad
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: menu.open ? Theme.hover : (area.containsMouse ? Theme.raised : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.duration / 2 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: clockEl.now.toLocaleString(Qt.locale(), "ddd dd MMM  HH:mm")
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { clockEl.monthOffset = 0; menu.toggle(); }
        onEntered: menu.hoverOpen()
    }

    Popout {
        id: menu
        anchor: clockEl
        contentWidth: 260

        Column {
            width: parent.width
            spacing: 8

            // Month, with a way back and forward. Clicking the name returns to
            // today, which is the only thing anyone wants after paging away.
            Row {
                width: parent.width
                height: 24

                Text {
                    width: 24; height: 24
                    text: "chevron_left"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: leftHover.containsMouse ? Theme.text : Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    MouseArea {
                        id: leftHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockEl.monthOffset--
                    }
                }

                Text {
                    width: parent.width - 48
                    height: 24
                    text: clockEl.shown.toLocaleString(Qt.locale(), "MMMM yyyy")
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: 600
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockEl.monthOffset = 0
                    }
                }

                Text {
                    width: 24; height: 24
                    text: "chevron_right"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: rightHover.containsMouse ? Theme.text : Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    MouseArea {
                        id: rightHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockEl.monthOffset++
                    }
                }
            }

            // Weekday initials, taken from the locale rather than written out,
            // so a system set to another language does not get English ones.
            Row {
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        width: 36
                        text: Qt.locale().dayName((index + 1) % 7, Locale.NarrowFormat)
                        color: Theme.dim
                        font.family: Theme.fontUi
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Six rows of seven, always: a month that needs six does not change
            // the panel's height halfway through the year.
            Grid {
                columns: 7

                Repeater {
                    model: 42

                    Rectangle {
                        required property int index

                        // Monday-first, which is what the locale here uses.
                        readonly property int firstWeekday:
                            (new Date(clockEl.shown.getFullYear(), clockEl.shown.getMonth(), 1).getDay() + 6) % 7
                        readonly property date cell:
                            new Date(clockEl.shown.getFullYear(), clockEl.shown.getMonth(),
                                     1 + index - firstWeekday)
                        readonly property bool thisMonth: cell.getMonth() === clockEl.shown.getMonth()
                        readonly property bool isToday:
                            cell.toDateString() === clockEl.now.toDateString()

                        width: 36
                        height: 28
                        radius: Theme.radiusSmall
                        color: isToday ? Theme.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.cell.getDate()
                            font.family: Theme.fontUi
                            font.pixelSize: 11
                            color: parent.isToday ? Theme.bar
                                 : parent.thisMonth ? Theme.text : Theme.dim
                        }
                    }
                }
            }
        }
    }
}
