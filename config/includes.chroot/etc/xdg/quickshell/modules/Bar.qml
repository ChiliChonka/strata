//
// One bar, on one monitor, plus the panel that drops out of it.
//
// The clock is anchored to the centre of the screen rather than placed between
// two stretching spacers, so it stays put as the window title on the left grows
// and shrinks. Everything else hangs off an edge.
//
// Panels are one shared full-screen window rather than one window each: it is
// what makes "click anywhere else to close" work, and it means only one panel
// can ever be open. Its input region deliberately excludes the bar, so the next
// element can still be clicked while a panel is open.
//
import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../theme.js" as Theme
import "../widgets"

Scope {
    id: bar

    required property var modelData          // the ShellScreen
    property var services: null
    property var partPaths: []

    // ---- The open panel ----------------------------------------------------
    property string panelSource: ""
    property real panelAnchor: 0             // screen x of the opening element
    property real panelWidth: 300

    function openPanel(source, item, width) {
        if (bar.panelSource === source) { bar.closePanel(); return; }
        const p = item.mapToItem(null, 0, 0);
        bar.panelAnchor = p.x + item.width / 2;
        bar.panelWidth = width;
        bar.panelSource = source;
    }

    function closePanel() { bar.panelSource = ""; }

    // ---- The bar -----------------------------------------------------------
    PanelWindow {
        id: panel
        screen: bar.modelData

        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barHeight
        color: Theme.mantle

        // The bedding plane between the bar and everything below it.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.lineSoft
        }

        Row {
            id: leftGroup
            anchors {
                left: parent.left; leftMargin: Theme.pad
                verticalCenter: parent.verticalCenter
            }
            spacing: Theme.gap

            Workspaces { bar: bar; anchors.verticalCenter: parent.verticalCenter }
            WindowTitle { bar: bar; anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            Clock { bar: bar }
        }

        Row {
            id: rightGroup
            anchors {
                right: parent.right; rightMargin: Theme.pad
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            // ---- Drop-in parts -------------------------------------------
            //
            // Loaded one at a time: a part that fails leaves a gap rather than
            // taking the bar down with it. A broken optional extra must not
            // cost someone their clock.
            Repeater {
                model: bar.partPaths

                delegate: Loader {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file://" + modelData
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Loader.Error)
                            console.warn("strata: bar part failed to load:", modelData);
                    }
                }
            }

            Item {
                // Keeps the project's own elements from touching a part's edge.
                width: bar.partPaths.length > 0 ? Theme.gap : 0
                height: 1
            }

            NotificationButton { bar: bar; anchors.verticalCenter: parent.verticalCenter }
            NetworkButton      { bar: bar; anchors.verticalCenter: parent.verticalCenter }
            AudioButton        { bar: bar; anchors.verticalCenter: parent.verticalCenter }
            BrightnessButton   { bar: bar; anchors.verticalCenter: parent.verticalCenter }
            BatteryButton      { bar: bar; anchors.verticalCenter: parent.verticalCenter }
            PowerButton        { bar: bar; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- The panel host ----------------------------------------------------
    PanelWindow {
        id: host
        screen: bar.modelData
        visible: bar.panelSource !== ""

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // Everything below the bar closes the panel; the bar itself is left out
        // of the input region so its elements stay reachable.
        mask: Region {
            x: 0
            y: Theme.barHeight
            width: host.width
            height: Math.max(0, host.height - Theme.barHeight)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: bar.closePanel()
        }

        Loader {
            id: content
            width: bar.panelWidth
            height: item ? item.implicitHeight : 0
            y: Theme.barHeight + Theme.padSm
            x: Math.max(Theme.gap,
                        Math.min(host.width - width - Theme.gap,
                                 bar.panelAnchor - width / 2))
            source: bar.panelSource
            onLoaded: if (item) item.bar = bar
            onStatusChanged: {
                if (status === Loader.Error)
                    console.warn("strata: panel failed to load:", source);
            }

            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        }
    }
}
