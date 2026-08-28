//
// A popout's declaration: what to show, how wide, and which bar element it
// belongs under. It is not a window.
//
// One window draws all of them (PopoutHost), because a panel cannot slide from
// one place to another if each place is a separate window. Elements say what
// they want shown; the host decides where it goes and how it gets there.
//
//     Popout {
//         id: menu
//         anchor: pill
//         contentWidth: 250
//         content: Component { Column { ... } }
//     }
//
//     BarPill { onClicked: menu.toggle(); active: menu.open }
//
import Quickshell
import QtQuick
import "root:/"

QtObject {
    id: popout

    // Declared as a Component so the element can still write its contents
    // inline: QML wraps an object declaration assigned to a Component property
    // by itself. The contents are then instantiated by PopoutHost, once, when
    // this popout is the one being shown.
    default property Component content: null
    property int contentWidth: 220
    property Item anchor: null          // the bar element it belongs under

    readonly property bool open: Popouts.current === popout

    function toggle() { Popouts.toggle(popout); }
    function hoverOpen() { Popouts.hover(popout); }
    function close()  { if (open) Popouts.close(); }
}
