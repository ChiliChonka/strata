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

    // Hidden along with the bar: a panel hanging off a bar that is not there
    // would float in the middle of a fullscreen window.
    visible: (shown || reveal > 0.01) && !barWindow.fullscreenHere

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    margins.top: Theme.barHeight

    // Tall enough for the panel, never shorter. A fixed guess cut the session
    // menu off at the bottom — and with it the rounded corners, which is how it
    // was noticed. The extra beyond the panel is the strip that catches a click
    // meant to dismiss it.
    //
    // Measured against the height the panel is heading for, not the height it
    // currently has: the window must already be big enough when the animation
    // starts, or a panel growing taller would be cut off by its own surface on
    // the way. The window is transparent, so being early costs nothing.
    // Padding, not padding plus a corner radius. The height used to carry an
    // extra Theme.radius so the last row would clear the rounded bottom corners,
    // which left 26 pixels below the contents against 10 at the sides — enough
    // to read as lopsided. The clearance was not needed: with a 10 pixel inset
    // the contents' bottom corners sit 8.5 pixels from the corner circle's
    // centre, well inside a radius of 16, so they are still on the panel.
    readonly property real targetHeight: body.implicitHeight + Theme.pad * 2
    // Room for the shadow as well as the panel. Reserving only Theme.gap left
    // exactly as many pixels below the panel as the shadow needs, so a tall
    // popout had its shadow cut off by the edge of its own window while a short
    // one did not — the same shadow, a different thickness, depending on what
    // was in it.
    implicitHeight: Math.max(Theme.barHeight * 6,
                             targetHeight + Theme.shadowDrop + Theme.gap)

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
    //
    // Held a shadow's width away from the screen edge, not a gap's. The
    // rightmost bar elements push their panel against the clamp, and with only
    // Theme.gap to spare the shadow on that side was cut off by the screen while
    // the other side kept all of it.
    property real panelX: Math.max(Theme.gap + Theme.shadowDrop,
        Math.min(width - panelWidth - Theme.gap - Theme.shadowDrop,
                 heldX - panelWidth / 2))

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
        height: host.targetHeight
        opacity: host.reveal
        transform: Translate { y: (1 - host.reveal) * -8 }

        // Height was the one dimension that was never animated. Switching from
        // one bar element to another slid the panel sideways and resized its
        // width over 180ms while its height changed in a single frame, so the
        // new contents were fully there before the surface holding them had
        // arrived. That is the flicker: content first, then size.
        Behavior on height {
            NumberAnimation { duration: Theme.duration; easing.type: Theme.easing }
        }

        // The shadow, which is the same shadow the bar casts and has to look
        // like it.
        //
        // The bar throws a straight band across the whole width; this panel
        // hangs off it and throws its own. They were a different strength, a
        // different reach and a different shape, so beside the panel you saw two
        // unrelated shadows meeting instead of one wrapping around a silhouette.
        // Everything here now comes from the same two tokens the bar's gradient
        // uses. Where they overlap at the joint the darkness adds up, which is
        // what a shadow does in an inside corner.
        //
        // Stacked copies of the outline, not a blur: the image ships no effects
        // module. The trick is that no single step may be visible on its own.
        //
        // The alpha has to fall off outward, and it used to rise — the largest
        // copy carried the largest alpha and the innermost almost none. What
        // that accumulates to is not a gradient but a slab: measured below the
        // panel, five pixels of constant darkness and then a drop, so the shadow
        // had a hard outer edge of its own.
        readonly property int shadowSteps: 16

        // Each step's share of the total, so that the steps accumulate to a
        // smoothstep rather than to a square curve: the weights are that
        // curve's own slope, 6t(1-t), which is small at both ends and largest
        // in the middle. Summed here rather than in closed form so that
        // changing shadowSteps cannot silently change how dark the shadow is.
        readonly property real shadowNorm: {
            var sum = 0;
            for (var i = 1; i <= shadowSteps; i++) {
                var t = (i - 0.5) / shadowSteps;
                sum += 6 * t * (1 - t);
            }
            return sum;
        }

        Repeater {
            model: panel.shadowSteps
            PopoutShape {
                required property int index

                // 1 sits against the panel, shadowSteps is the outermost and
                // faintest. Spread in pixels rather than as a fraction of the
                // panel, so a long menu does not cast a bigger shadow than a
                // short one.
                readonly property int step: index + 1
                readonly property real spread:
                    Theme.shadowDrop * step / panel.shadowSteps

                anchors.fill: parent
                joint: Theme.joint
                radius: Theme.radius
                bodyHeight: parent.height
                // The alphas sum to exactly Theme.shadowStrength, so the
                // darkness where this shadow meets the panel is the same as
                // where the bar's band meets the bar.
                readonly property real t: (step - 0.5) / panel.shadowSteps
                fill: Qt.rgba(0, 0, 0, Theme.shadowStrength
                    * 6 * t * (1 - t) / panel.shadowNorm)
                // Scaled from the top edge, so the panel stays welded to the bar
                // and the shadow only spreads sideways and down.
                transform: Scale {
                    origin.x: panel.width / 2
                    origin.y: 0
                    xScale: (panel.width + spread * 2) / panel.width
                    yScale: (panel.height + spread) / panel.height
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

        // The contents follow the panel, not the target.
        //
        // The Loader used to take its width from heldWidth, which is not
        // animated, so new contents snapped to their final width inside a box
        // that was still travelling to meet them. Clipped, because for those
        // 180ms the contents can be wider or taller than what holds them, and
        // drawing them outside the rounded shape is worse than cutting them.
        Item {
            id: bodyClip
            x: Theme.joint + Theme.pad
            y: Theme.pad
            width: panel.width - Theme.joint * 2 - Theme.pad * 2
            height: Math.max(0, panel.height - Theme.pad * 2)
            clip: true

            // Starts invisible and is faded in by the animation below, so
            // contents arrive with the panel rather than ahead of it.
            opacity: 0

            Loader {
                id: body
                width: bodyClip.width
                sourceComponent: host.held
                onLoaded: fadeIn.restart()
            }

            NumberAnimation {
                id: fadeIn
                target: bodyClip
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.duration
                easing.type: Theme.easing
            }
        }
    }

    // Clicking anywhere else closes it.
    //
    // A MouseArea in this window could only see clicks inside this window, so
    // clicking a terminal — the normal way to dismiss a menu — did nothing at
    // all. The compositor is the only thing that sees a click on another
    // surface, and Hyprland exposes exactly that.
    HyprlandFocusGrab {
        // The bar belongs in this list too. A grab covering only the panel
        // takes the pointer away from the bar, so hovering the next icon
        // stopped doing anything and the open menu just sat there — the
        // click-away fix broke the hover-to-switch behaviour it shipped
        // alongside.
        windows: [host, host.barWindow]
        active: host.shown
        onCleared: Popouts.close()
    }
}
