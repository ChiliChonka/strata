//
// The desktop background.
//
// hyprpaper is in the image and was the obvious tool, but it cannot draw in this
// session. Its line-form `wallpaper = ,path` is silently ignored by 0.8.4 — the
// man page documents a block — and once the block form gives it a monitor target
// it allocates its buffer through KMS/GBM, as though it were the compositor.
// Hyprland already holds DRM master, so that fails: DRM_IOCTL_MODE_CREATE_DUMB
// returned Permission denied and the process segfaulted. Forcing software
// rendering changed nothing, so it is not a missing GPU either.
//
// Quickshell is already on screen in that same session, so the background is one
// more layer-shell surface, below everything else. It costs no package, and the
// colour behind the image is the one the rest of the desktop uses.
//
import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: root

    // Cover the output and take nothing from it.
    //
    // Anchoring all four edges is only half of that. Without Ignore, the bar's
    // own exclusive zone pushed this surface down and the top 28 pixels of the
    // desktop were not wallpaper at all — `xywh: 0 28 1280 772` in
    // `hyprctl layers`. Ignore is not paired with `exclusiveZone: 0`, which
    // looks like it belongs here and quietly undoes it: assigning the zone puts
    // the window back into Normal mode, and the surface was pushed down again.
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "strata-wallpaper"

    // Clicks belong to whatever is underneath, not to this surface.
    mask: Region {}

    // Shows before the image has loaded, and instead of it if the file is gone:
    // a missing wallpaper leaves the theme's colour, not a black screen.
    color: Theme.surface

    Image {
        anchors.fill: parent
        source: Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        onStatusChanged: {
            if (status === Image.Error)
                console.warn("wallpaper failed to load:", source);
        }
    }
}
