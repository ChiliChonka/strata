//
// The one panel that every popout is drawn in.
//
// Because there is only one, switching from one bar element to another is a
// move rather than a close and an open: the panel slides along the bar to sit
// under whatever was clicked, and resizes to what that thing wants to show.
// Two panels can never be open at once, because there is only one panel.
//
// The shape is a single filled path — two concave fillets where it meets the
// bar, then a rounded body — so the bar and the panel read as one surface with
// a piece carved out of it rather than two rectangles that happen to touch.
//
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import "root:/"

PanelWindow {
    id: host

    required property var barWindow

    readonly property var active: Popouts.current
    readonly property bool shown: active !== null

    // Kept after `active` goes null so the closing animation has something to
    // draw; cleared once it has finished.
    property Component held: null
    property int heldWidth: 220
    property real heldX: 0

    onActiveChanged: {
        if (active) {
            held = active.content;
            heldWidth = active.contentWidth;
            heldX = centreOf(active.anchor);
        }
    }

    function centreOf(item) {
        if (!item || !barWindow) return width / 2;
        const p = item.mapToItem(barWindow.contentItem, 0, 0);
        return p.x + item.width / 2;
    }

    visible: shown || reveal > 0.01

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    margins.top: Theme.barHeight

    // Tall enough for the panel, never shorter. A fixed guess cut the session
    // menu off at the bottom — and with it the rounded corners, which is how it
    // was noticed. The extra beyond the panel is the strip that catches a click
    // meant to dismiss it.
    implicitHeight: Math.max(Theme.barHeight * 6, panel.height + Theme.gap)

    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: Theme.duration; easing.type: Theme.easing }
    }
    onRevealChanged: if (reveal < 0.01 && !shown) held = null

    // Where the panel sits, clamped so it never hangs off either edge.
    // Not readonly: a Behavior cannot animate a readonly property, and these
    // two are exactly what has to be animated for the panel to travel along the
    // bar instead of jumping. The bindings still drive them; the Behaviors just
    // smooth the result.
    property real panelWidth: heldWidth + Theme.joint * 2
    property real panelX: Math.max(Theme.gap,
        Math.min(width - panelWidth - Theme.gap, heldX - panelWidth / 2))

    // The slide. Animating x is what makes switching read as one surface
    // moving; without it the panel would blink from place to place.
    Behavior on panelX {
        NumberAnimation { duration: Theme.duration; easing.type: Theme.easing }
    }
    Behavior on panelWidth {
        NumberAnimation { duration: Theme.duration; easing.type: Theme.easing }
    }

    Item {
        id: panel
        x: host.panelX
        width: host.panelWidth
        height: body.implicitHeight + Theme.pad * 2 + Theme.radius
        opacity: host.reveal
        transform: Translate { y: (1 - host.reveal) * -8 }

        // The shadow: three copies of the same outline behind the real one,
        // each a little larger and fainter. There is no blur — the image ships
        // no effects module — but three steps is enough to lift the panel off
        // the wallpaper, which is what it was missing.
        //
        // Scaled from the top edge, so the panel stays welded to the bar and
        // the shadow only spreads sideways and down.
        Repeater {
            model: 4
            PopoutShape {
                required property int index
                anchors.fill: parent
                joint: Theme.joint
                radius: Theme.radius
                bodyHeight: parent.height
                fill: Qt.rgba(0, 0, 0, 0.34 - index * 0.07)
                transform: Scale {
                    origin.x: panel.width / 2
                    origin.y: 0
                    xScale: 1 + (4 - index) * 0.010
                    yScale: 1 + (4 - index) * 0.018
                }
            }
        }

        PopoutShape {
            anchors.fill: parent
            joint: Theme.joint
            radius: Theme.radius
            bodyHeight: parent.height
            fill: Theme.surface
        }

        Loader {
            id: body
            x: Theme.joint + Theme.pad
            y: Theme.pad
            width: host.heldWidth - Theme.pad * 2
            sourceComponent: host.held
        }
    }

    // Clicking anywhere else closes it.
    //
    // A MouseArea in this window could only see clicks inside this window, so
    // clicking a terminal — the normal way to dismiss a menu — did nothing at
    // all. The compositor is the only thing that sees a click on another
    // surface, and Hyprland exposes exactly that.
    HyprlandFocusGrab {
        windows: [host]
        active: host.shown
        onCleared: Popouts.close()
    }
}
