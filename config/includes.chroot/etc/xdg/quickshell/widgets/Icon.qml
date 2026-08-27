//
// The shell's icon set, drawn rather than shipped.
//
// Strata installs exactly one font, fonts-dejavu-core (ADR-0009), and DejaVu
// has no speaker, no wifi arc and no power symbol. The usual answer is to add a
// Nerd Font or an icon theme, which is 30-80 MB of image for a dozen glyphs and
// a licence question on top. Drawing them on a 24x24 grid costs nothing, scales
// cleanly, takes its colour from the theme, and matches the geometric visual
// language BRANDING.md asks for.
//
// Icons that show a quantity — volume, wifi, battery — read `level` (0..1) and
// draw the missing part dimmed rather than switching between separate glyphs,
// so the shape stays put as the value changes.
//
import QtQuick
import "../theme.js" as Theme

Item {
    id: root

    property string name: ""
    property real size: 16
    property color color: Theme.text
    property color dimColor: Theme.fade(Theme.subtle, 0.55)
    property real level: 1.0
    property real stroke: 2.0

    implicitWidth: size
    implicitHeight: size

    onNameChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onLevelChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            ctx.scale(width / 24, height / 24);
            ctx.lineWidth = root.stroke;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.strokeStyle = root.color;
            ctx.fillStyle = root.color;

            const on = root.color;
            const off = root.dimColor;

            function line(x1, y1, x2, y2, c) {
                ctx.strokeStyle = c || on;
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.stroke();
            }
            function poly(pts, c, fill) {
                ctx.beginPath();
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
                ctx.closePath();
                if (fill) { ctx.fillStyle = c || on; ctx.fill(); }
                else { ctx.strokeStyle = c || on; ctx.stroke(); }
            }
            function arc(cx, cy, r, a0, a1, c) {
                ctx.strokeStyle = c || on;
                ctx.beginPath();
                ctx.arc(cx, cy, r, a0, a1, false);
                ctx.stroke();
            }
            function box(x, y, w, h, r, c, fill) {
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.arcTo(x + w, y, x + w, y + h, r);
                ctx.arcTo(x + w, y + h, x, y + h, r);
                ctx.arcTo(x, y + h, x, y, r);
                ctx.arcTo(x, y, x + w, y, r);
                ctx.closePath();
                if (fill) { ctx.fillStyle = c || on; ctx.fill(); }
                else { ctx.strokeStyle = c || on; ctx.stroke(); }
            }

            switch (root.name) {

            // ---- Audio ----------------------------------------------------
            case "volume": {
                poly([[3, 9], [7, 9], [12, 4], [12, 20], [7, 15], [3, 15]], on, true);
                // Two arcs, each standing for half the range.
                arc(12.5, 12, 4.2, -0.9, 0.9, root.level > 0.02 ? on : off);
                arc(12.5, 12, 7.6, -0.9, 0.9, root.level > 0.5 ? on : off);
                break;
            }
            case "volume-muted": {
                poly([[3, 9], [7, 9], [12, 4], [12, 20], [7, 15], [3, 15]], off, true);
                line(16, 8.5, 21.5, 15.5, on);
                line(21.5, 8.5, 16, 15.5, on);
                break;
            }
            case "mic": {
                box(9.5, 2.5, 5, 11, 2.5, on, false);
                arc(12, 12, 6, 0, Math.PI, on);
                line(12, 18, 12, 21.5, on);
                break;
            }
            case "mic-muted": {
                box(9.5, 2.5, 5, 11, 2.5, off, false);
                arc(12, 12, 6, 0, Math.PI, off);
                line(12, 18, 12, 21.5, off);
                line(4, 3.5, 20, 20.5, on);
                break;
            }

            // ---- Brightness -----------------------------------------------
            case "brightness": {
                ctx.fillStyle = on;
                ctx.beginPath();
                ctx.arc(12, 12, 4.4, 0, Math.PI * 2);
                ctx.fill();
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4;
                    line(12 + Math.cos(a) * 7.4, 12 + Math.sin(a) * 7.4,
                         12 + Math.cos(a) * 9.8, 12 + Math.sin(a) * 9.8, on);
                }
                break;
            }

            // ---- Network --------------------------------------------------
            case "wifi": {
                arc(12, 17, 9.5, -Math.PI * 0.82, -Math.PI * 0.18, root.level > 0.66 ? on : off);
                arc(12, 17, 6.2, -Math.PI * 0.82, -Math.PI * 0.18, root.level > 0.33 ? on : off);
                arc(12, 17, 3.0, -Math.PI * 0.82, -Math.PI * 0.18, root.level > 0.0 ? on : off);
                ctx.fillStyle = root.level > 0 ? on : off;
                ctx.beginPath();
                ctx.arc(12, 17.5, 1.5, 0, Math.PI * 2);
                ctx.fill();
                break;
            }
            case "wifi-off": {
                arc(12, 17, 6.2, -Math.PI * 0.82, -Math.PI * 0.18, off);
                arc(12, 17, 3.0, -Math.PI * 0.82, -Math.PI * 0.18, off);
                line(4, 4, 20, 20, on);
                break;
            }
            case "ethernet": {
                box(3, 13, 18, 7, 1.5, on, false);
                line(12, 13, 12, 8, on);
                box(8, 3.5, 8, 4.5, 1.2, on, false);
                break;
            }
            case "network-off": {
                box(3, 13, 18, 7, 1.5, off, false);
                line(4, 4, 20, 20, on);
                break;
            }

            // ---- Battery --------------------------------------------------
            case "battery": {
                box(2, 7, 17, 10, 2.2, on, false);
                ctx.fillStyle = on;
                box(20, 10, 2.2, 4, 1, on, true);
                const w = Math.max(0, Math.min(1, root.level)) * 13;
                if (w > 0.5) {
                    ctx.fillStyle = Theme.levelColor(root.level);
                    box(4, 9, w, 6, 1, ctx.fillStyle, true);
                }
                break;
            }
            case "battery-charging": {
                box(2, 7, 17, 10, 2.2, on, false);
                box(20, 10, 2.2, 4, 1, on, true);
                poly([[11.5, 8], [7, 13], [10, 13], [9, 16.5], [13.5, 11.5], [10.5, 11.5]],
                     Theme.good, true);
                break;
            }

            // ---- Notifications --------------------------------------------
            case "bell": {
                ctx.strokeStyle = on;
                ctx.beginPath();
                ctx.moveTo(5.5, 16.5);
                ctx.lineTo(5.5, 11);
                ctx.arc(12, 11, 6.5, Math.PI, 0, false);
                ctx.lineTo(18.5, 16.5);
                ctx.stroke();
                line(3.5, 16.5, 20.5, 16.5, on);
                arc(12, 19, 2.4, 0, Math.PI, on);
                break;
            }
            case "bell-off": {
                ctx.strokeStyle = off;
                ctx.beginPath();
                ctx.moveTo(5.5, 16.5);
                ctx.lineTo(5.5, 11);
                ctx.arc(12, 11, 6.5, Math.PI, 0, false);
                ctx.lineTo(18.5, 16.5);
                ctx.stroke();
                line(3.5, 16.5, 20.5, 16.5, off);
                line(4, 4, 20, 20, on);
                break;
            }

            // ---- Session --------------------------------------------------
            case "power": {
                arc(12, 12.5, 7.5, -Math.PI * 0.35, Math.PI * 1.35, on);
                line(12, 3, 12, 11, on);
                break;
            }
            case "lock": {
                box(4.5, 10.5, 15, 10, 2.2, on, false);
                arc(12, 10.5, 4.2, Math.PI, 0, on);
                break;
            }
            case "restart": {
                arc(12, 12, 8, -Math.PI * 0.75, Math.PI * 0.75, on);
                poly([[18.5, 2.5], [18.5, 8.5], [12.5, 8.5]], on, true);
                break;
            }
            case "suspend": {
                ctx.strokeStyle = on;
                ctx.beginPath();
                ctx.arc(13, 12, 8.2, Math.PI * 0.42, Math.PI * 1.42, false);
                ctx.stroke();
                break;
            }
            case "logout": {
                ctx.strokeStyle = on;
                ctx.beginPath();
                ctx.moveTo(13, 4);
                ctx.lineTo(5, 4);
                ctx.lineTo(5, 20);
                ctx.lineTo(13, 20);
                ctx.stroke();
                line(10.5, 12, 20.5, 12, on);
                poly([[16.5, 8], [20.5, 12], [16.5, 16]], on, false);
                break;
            }

            // ---- Chrome ----------------------------------------------------
            case "chevron-down": {
                poly([[6, 9.5], [12, 15.5], [18, 9.5]], on, false);
                break;
            }
            case "close": {
                line(6.5, 6.5, 17.5, 17.5, on);
                line(17.5, 6.5, 6.5, 17.5, on);
                break;
            }
            case "check": {
                poly([[5, 12.5], [10, 17.5], [19, 6.5]], on, false);
                break;
            }
            case "calendar": {
                box(3.5, 5.5, 17, 15, 2, on, false);
                line(3.5, 10, 20.5, 10, on);
                line(8, 2.5, 8, 6.5, on);
                line(16, 2.5, 16, 6.5, on);
                break;
            }

            // ---- Strata mark ------------------------------------------------
            // Three stacked planes: the project's own shape, used wherever an
            // application has no icon of its own.
            case "layers": {
                ctx.globalAlpha = 0.45; box(4, 4, 16, 4, 1.2, on, true);
                ctx.globalAlpha = 0.7;  box(4, 10, 16, 4, 1.2, on, true);
                ctx.globalAlpha = 1.0;  box(4, 16, 16, 4, 1.2, on, true);
                break;
            }
            }

            ctx.restore();
        }
    }
}
