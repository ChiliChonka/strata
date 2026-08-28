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

    implicitHeight: Theme.barHeight * 6

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

        Shape {
            // Referenced by id below: PathArc and PathLine are not visual
            // items, so `parent` does not resolve inside a ShapePath.
            id: shape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property int j: Theme.joint
            readonly property int r: Theme.radius
            readonly property real h: parent.height

            ShapePath {
                fillColor: Theme.surface
                strokeWidth: 0
                startX: 0
                startY: 0
                // Clockwise, not counter: with the same radius and the same two
                // endpoints there are two possible circles, and the other one
                // bulges outward into an ear instead of cutting the corner in.
                PathArc {
                    x: shape.j; y: shape.j
                    radiusX: shape.j; radiusY: shape.j
                    direction: PathArc.Clockwise
                }
                PathLine { x: shape.j; y: shape.h - shape.r }
                PathArc {
                    x: shape.j + shape.r; y: shape.h
                    radiusX: shape.r; radiusY: shape.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: shape.width - shape.j - shape.r; y: shape.h }
                PathArc {
                    x: shape.width - shape.j; y: shape.h - shape.r
                    radiusX: shape.r; radiusY: shape.r
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: shape.width - shape.j; y: shape.j }
                PathArc {
                    x: shape.width; y: 0
                    radiusX: shape.j; radiusY: shape.j
                    direction: PathArc.Clockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }

        Loader {
            id: body
            x: Theme.joint + Theme.pad
            y: Theme.pad
            width: host.heldWidth - Theme.pad * 2
            sourceComponent: host.held
        }
    }

    // Clicking anywhere else in this window closes it. The window covers the
    // strip under the bar, so this catches the common "click away" without
    // grabbing input from the whole screen.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: host.shown
        onClicked: Popouts.close()
    }
}
