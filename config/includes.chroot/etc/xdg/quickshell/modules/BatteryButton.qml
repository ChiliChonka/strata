//
// Battery, on machines that have one.
//
import Quickshell.Services.UPower
import QtQuick
import "../theme.js" as Theme
import "../widgets"

BarItem {
    id: root

    property var bar: null

    readonly property var battery: UPower.displayDevice
    readonly property bool present: battery !== null
                                    && battery.isLaptopBattery
                                    && battery.isPresent
    readonly property real level: present ? battery.percentage : 0
    readonly property bool charging: present
                                     && battery.state === UPowerDeviceState.Charging

    visible: present

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        name: root.charging ? "battery-charging" : "battery"
        size: 17
        level: root.level
        color: root.charging ? Theme.good : Theme.levelColor(root.level)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.level * 100) + "%"
        color: root.level <= 0.15 && !root.charging ? Theme.bad : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.size
    }
}
