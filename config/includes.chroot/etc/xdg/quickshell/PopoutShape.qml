//
// The popout's outline: two concave fillets where it meets the bar, then a
// rounded body.
//
// In its own file because it is drawn more than once — the shadow is several
// copies of this shape behind the real one, since the image ships no effects
// module and there is no blur to be had. Repeating the path by hand four times
// would mean four places to get the arc directions wrong.
//
import QtQuick
import QtQuick.Shapes

Shape {
    id: shape

    property int joint: 18
    property int radius: 16
    property real bodyHeight: 100
    property color fill: "#16191d"

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: shape.fill
        strokeWidth: 0

        startX: 0
        startY: 0
        // Clockwise: with the same radius and the same endpoints there are two
        // possible circles, and the other one bulges outward into an ear.
        PathArc {
            x: shape.joint; y: shape.joint
            radiusX: shape.joint; radiusY: shape.joint
            direction: PathArc.Clockwise
        }
        PathLine { x: shape.joint; y: shape.bodyHeight - shape.radius }
        PathArc {
            x: shape.joint + shape.radius; y: shape.bodyHeight
            radiusX: shape.radius; radiusY: shape.radius
            direction: PathArc.Counterclockwise
        }
        PathLine { x: shape.width - shape.joint - shape.radius; y: shape.bodyHeight }
        PathArc {
            x: shape.width - shape.joint; y: shape.bodyHeight - shape.radius
            radiusX: shape.radius; radiusY: shape.radius
            direction: PathArc.Counterclockwise
        }
        PathLine { x: shape.width - shape.joint; y: shape.joint }
        PathArc {
            x: shape.width; y: 0
            radiusX: shape.joint; radiusY: shape.joint
            direction: PathArc.Clockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
