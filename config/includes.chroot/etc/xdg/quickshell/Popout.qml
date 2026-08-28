//
// A panel that grows out of the bar instead of appearing next to it.
//
// The shape is one filled path: two concave fillets at the top, where the panel
// meets the bar, then a rounded body. Because the fillets are drawn in the same
// colour and curve outward, the bar and the panel read as one surface with a
// piece carved out of it, rather than as two rectangles that happen to touch.
//
// Usage — the content is whatever is put inside:
//
//     Popout {
//         id: menu
//         contentWidth: 220
//         Column { ... }
//     }
//
import Quickshell
import QtQuick
import QtQuick.Shapes
import "root:/"

PanelWindow {
    id: popout

    default property alias content: body.data
    property int contentWidth: 220
    property int contentHeight: 100
    property int rightMargin: Theme.gap
    property bool open: false

    visible: open || anim.running

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Theme.barHeight; right: popout.rightMargin }

    // The window is wider than the content on both sides, because the fillets
    // curve outward past the panel edge and still have to be inside the window.
    implicitWidth: contentWidth + Theme.joint * 2
    implicitHeight: contentHeight + Theme.radius

    // Grown from the bar rather than faded in: the panel is a part of the bar
    // that moved, so it should look like it moved.
    property real reveal: 0
    Behavior on reveal {
        NumberAnimation {
            id: anim
            duration: Theme.duration
            easing.type: Theme.easing
        }
    }
    onOpenChanged: reveal = open ? 1 : 0

    Item {
        anchors.fill: parent
        opacity: popout.reveal

        Shape {
            id: shape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property int j: Theme.joint
            readonly property int r: Theme.radius
            readonly property real h: Math.max(shape.r + shape.j,
                                               popout.implicitHeight * popout.reveal)

            ShapePath {
                fillColor: Theme.surface
                strokeWidth: 0

                // Left fillet: starts on the bar's edge, curves down into the
                // panel's side. The filled side is to the lower right, so the
                // curve reads as a cove rather than a bump.
                startX: 0
                startY: 0
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

        Item {
            id: body
            x: Theme.joint
            width: popout.contentWidth
            y: 0
            height: popout.contentHeight
            clip: true
        }
    }
}
