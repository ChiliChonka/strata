pragma Singleton
//
// One place for every value that decides how Strata looks.
//
// Drop-in parts reach this with `import "root:/"`, which is the only import form
// that resolves from /etc/xdg/quickshell/parts — a relative import and a bare
// reference were both measured to fail. A part that uses these tokens looks like
// it belongs without copying any numbers.
//
import Quickshell
import QtQuick

Singleton {
    // ---- Colour -----------------------------------------------------------
    // Names, not values. The values live in the active scheme and arrive through
    // Colors.qml, which apply-theme generates — so the same scheme drives the
    // bar, the launcher, notifications, window borders and the terminal.
    //
    // bar and surface are deliberately the same colour: the concave joint in
    // Popout only reads as one carved surface if there is no step between them.
    readonly property color bar:      Colors.base00
    readonly property color surface:  Colors.base00
    readonly property color raised:   Colors.base01
    readonly property color hover:    Colors.base02

    readonly property color text:     Colors.base05
    readonly property color muted:    Colors.base04
    readonly property color dim:      Colors.base03
    readonly property color accent:   Colors.base0D
    readonly property color ok:       Colors.base0B
    readonly property color warn:     Colors.base0A
    readonly property color danger:   Colors.base08

    // ---- Type ---------------------------------------------------------------
    readonly property string fontUi:   "Inter Variable"
    readonly property string fontMono: "JetBrains Mono"
    readonly property string fontIcon: "Material Icons"

    // ---- The desktop background --------------------------------------------
    //
    // Drawn by Wallpaper.qml. It lives here with the other looks-tokens so that
    // changing the desktop's picture is the same kind of edit as changing its
    // colours.
    readonly property url wallpaper: "file:///usr/share/backgrounds/strata/strata.png"

    // ---- Shape ------------------------------------------------------------
    readonly property int radius:      16   // popouts and cards
    readonly property int radiusSmall:  6   // pills inside the bar
    readonly property int joint:       18   // the concave curve into the bar

    readonly property int barHeight:   28
    readonly property int gap:          6
    readonly property int pad:         10

    // ---- Motion -----------------------------------------------------------
    // Short enough not to be in the way, long enough to read as one surface
    // moving rather than a window appearing.
    readonly property color shadow:   "#000000"

    // How far a shadow reaches below its surface, and how dark it starts.
    //
    // Ten pixels at 0.28 was reported as too hard, too thick and too dark, and
    // it was: a band that deep reads as a second surface rather than as light
    // falling short.
    //
    // Six at 0.14 with a square falloff was then reported as still not soft,
    // which it also was. Softness is reach — there is no soft six-pixel shadow —
    // and a square curve falls off fastest exactly where it meets the surface,
    // which is where a blurred edge is flattest. Both are now eight pixels of
    // smoothstep: level at both ends, half strength in the middle, and lighter
    // at every distance than the ten-pixel version that was rejected.
    readonly property int  shadowDrop:      8
    readonly property real shadowStrength:  0.16

    readonly property int duration:    180
    readonly property var easing:      Easing.OutCubic
}
