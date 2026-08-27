//
// The dock: what is running, and a way back to it.
//
// Hyprland tiles and has no window list, so a window on another workspace is
// out of sight with nothing pointing at it. This is that pointer — one entry
// per application, not per window, because ten terminals are one thing you
// think about.
//
// It stays hidden. A permanently visible dock either eats screen space from
// every tiled window (an exclusive zone) or covers them (no exclusive zone),
// and neither is acceptable on a tiling desktop. Four pixels at the bottom edge
// reveal it on hover; the input region is masked to match, so the rest of the
// bottom edge belongs to whatever window is there.
//
import Quickshell
import QtQuick
import "../theme.js" as Theme
import "../widgets"

PanelWindow {
    id: root

    required property var modelData
    property var services: null

    readonly property var toplevels: services ? services.toplevels : null
    readonly property var prefs: services ? services.prefs : null

    // One entry per application id, in the order the windows first appeared.
    readonly property var apps: {
        const wins = root.toplevels ? root.toplevels.items : [];
        const active = root.toplevels ? root.toplevels.active : null;
        const order = [];
        const byId = {};

        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (!w) continue;
            const id = (w.appId && w.appId !== "") ? w.appId : "unknown";
            if (byId[id] === undefined) {
                byId[id] = { appId: id, windows: [], active: false, title: "" };
                order.push(id);
            }
            byId[id].windows.push(w);
            if (w === active) {
                byId[id].active = true;
                byId[id].title = w.title || id;
            }
        }

        const out = [];
        for (let i = 0; i < order.length; i++) {
            const e = byId[order[i]];
            if (e.title === "") e.title = e.windows[0].title || e.appId;
            out.push(e);
        }
        return out;
    }

    readonly property bool wanted: (prefs ? prefs.dockEnabled : true) && apps.length > 0
    property bool revealed: false

    Timer {
        id: leaveDelay
        interval: 350
        onTriggered: root.revealed = false
    }

    function lookup(appId) {
        const list = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        const want = (appId || "").toLowerCase();
        if (want === "") return null;

        for (let pass = 0; pass < 2; pass++) {
            for (let i = 0; i < list.length; i++) {
                const e = list[i];
                if (!e) continue;
                const id = String(e.id || "").toLowerCase().replace(/\.desktop$/, "");
                const name = String(e.name || "").toLowerCase();
                if (pass === 0 && id === want) return e;
                // Second pass is deliberately looser: application ids and
                // desktop file names agree far less often than they should.
                if (pass === 1 && (name === want || id.endsWith("." + want)))
                    return e;
            }
        }
        return null;
    }

    function iconFor(appId) {
        const entry = root.lookup(appId);
        if (!entry || !entry.icon) return "";
        try {
            return Quickshell.iconPath(entry.icon, "");
        } catch (e) {
            return "";
        }
    }

    function focus(entry) {
        // Repeated clicks walk through that application's windows, which is
        // what a taskbar entry standing for four terminals has to do.
        const wins = entry.windows;
        if (wins.length === 0) return;
        let next = wins[0];
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].activated) { next = wins[(i + 1) % wins.length]; break; }
        }
        try { next.activate(); } catch (e) { }
    }

    screen: modelData
    anchors { bottom: true; left: true; right: true }
    // Room above the dock for the hovered application's name.
    readonly property int bodyHeight: Theme.dockIcon + Theme.dockPad * 2
    implicitHeight: bodyHeight + 30
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.wanted

    // Only the dock itself, or the reveal strip while it is hidden, takes
    // pointer input. Everything else falls through to the window underneath.
    mask: Region {
        x: root.revealed ? body.x : 0
        y: root.revealed ? body.y : root.height - 4
        width: root.revealed ? body.width : root.width
        height: root.revealed ? body.height : 4
    }

    // A HoverHandler rather than a MouseArea: the icons below have MouseAreas
    // of their own, and a MouseArea here would take the hover away from them
    // and then hide the dock out from under the pointer.
    Item {
        anchors.fill: parent
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { leaveDelay.stop(); root.revealed = true; }
                else leaveDelay.restart();
            }
        }
    }

    Rectangle {
        id: body

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.revealed ? root.height - height : root.height - 4
        width: row.implicitWidth + Theme.dockPad * 2
        height: root.bodyHeight
        radius: Theme.radiusLg
        color: Theme.fade(Theme.surface, 0.97)
        border.width: 1
        border.color: Theme.line

        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.apps

                delegate: Item {
                    id: appItem
                    required property var modelData

                    width: Theme.dockIcon
                    height: Theme.dockIcon

                    readonly property string iconSource: root.iconFor(modelData.appId)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: appHover.containsMouse ? Theme.overlay
                             : (appItem.modelData.active ? Theme.raised : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.anim } }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        visible: appItem.iconSource !== ""
                        source: appItem.iconSource
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    // No icon theme entry: the Strata mark with the
                    // application's initial, rather than an empty square.
                    Icon {
                        anchors.centerIn: parent
                        visible: appItem.iconSource === ""
                        name: "layers"
                        size: 20
                        color: Theme.subtle
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: appItem.iconSource === ""
                        text: String(appItem.modelData.appId).charAt(0).toUpperCase()
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: Theme.sizeSm
                        font.bold: true
                    }

                    // Running marker, and a second one when there is more than
                    // one window.
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                        spacing: 3
                        Repeater {
                            model: Math.min(2, appItem.modelData.windows.length)
                            delegate: Rectangle {
                                width: appItem.modelData.active ? 8 : 4
                                height: 3
                                radius: 1.5
                                color: appItem.modelData.active ? Theme.accent : Theme.subtle
                                Behavior on width { NumberAnimation { duration: Theme.anim } }
                            }
                        }
                    }

                    MouseArea {
                        id: appHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                const wins = appItem.modelData.windows;
                                for (let i = 0; i < wins.length; i++) {
                                    try { wins[i].close(); } catch (e) { }
                                }
                            } else {
                                root.focus(appItem.modelData);
                            }
                        }
                    }

                    // The name, above the icon, while hovering.
                    Rectangle {
                        visible: appHover.containsMouse
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 6 }
                        width: tip.implicitWidth + 14
                        height: 22
                        radius: Theme.radiusSm
                        color: Theme.base
                        border.width: 1
                        border.color: Theme.line

                        Text {
                            id: tip
                            anchors.centerIn: parent
                            text: appItem.modelData.title
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.sizeSm
                        }
                    }
                }
            }
        }
    }
}
