pragma Singleton
//
// Which popout is open. Exactly one, ever.
//
// Each bar element used to own a popout window, all anchored to the same corner,
// so opening a second one left two panels stacked on top of each other and
// neither knew about the other. One place has to decide, and this is it.
//
// Elements register a declaration (Popout.qml) and ask to be shown; PopoutHost
// draws whichever is current, in one window that moves.
//
import Quickshell
import QtQuick

Singleton {
    id: popouts

    property var current: null      // the Popout declaration being shown

    function toggle(p) { current = (current === p) ? null : p; }

    // Hovering another element switches to it, but only while something is
    // already open. Otherwise moving the mouse across the bar would open menus
    // nobody asked for.
    function hover(p) { if (current !== null && current !== p) current = p; }
    function show(p)   { current = p; }
    function close()   { current = null; }
}
