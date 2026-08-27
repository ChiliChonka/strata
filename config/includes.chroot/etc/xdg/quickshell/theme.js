//
// Strata design tokens.
//
// One place for every colour, radius and size the shell uses, so the look can
// be changed without hunting through twenty QML files.
//
// This is a plain JavaScript library rather than a QML singleton on purpose:
// `.pragma library` needs no qmldir, no import path setup and no Quickshell
// singleton machinery, and the values here never change at runtime.
//
// The palette is the Strata identity from BRANDING.md expressed in colour:
// stacked planes of cool stone, separated by hairlines, with one restrained
// accent. Nothing glows, nothing is neon, and the accent is used for state —
// never for decoration.
//
.pragma library

// ---- Planes ---------------------------------------------------------------
// Darkest at the bottom, lightest at the top, like a section through rock.
var base      = "#0c0f12";   // behind everything
var mantle    = "#11151a";   // the bar
var surface   = "#171c22";   // popups, dock
var raised    = "#1e242b";   // rows, inactive chips
var overlay   = "#28303a";   // hover
var line      = "#333d48";   // borders
var lineSoft  = "#212830";   // hairlines inside a surface

// ---- Ink ------------------------------------------------------------------
var subtle    = "#4d5761";   // disabled, empty markers
var muted     = "#7b8792";   // secondary text
var text      = "#c2cad2";   // normal text
var bright    = "#e9eff4";   // emphasis

// ---- Accents --------------------------------------------------------------
// One cool accent for state and focus, one warm for anything that wants
// attention without being an error. Used sparingly, per ADR-0004.
var accent    = "#8fb6c9";
var accentDim = "#3d515c";
var ochre     = "#c9a06a";

var good      = "#83ae87";
var warn      = "#d0a05e";
var bad       = "#c97b72";

// ---- Metrics --------------------------------------------------------------
var barHeight = 32;
var itemH     = 22;          // height of a bar element
var radius    = 6;
var radiusSm  = 4;
var radiusLg  = 10;
var padSm     = 6;
var pad       = 10;
var padLg     = 14;
var gap       = 8;
var gapLg     = 14;

var dockIcon  = 40;
var dockPad   = 8;

// ---- Type -----------------------------------------------------------------
// fonts-dejavu-core is the only font the image ships (ADR-0009), so it is named
// rather than left to a fontconfig guess.
var font      = "DejaVu Sans";
var fontMono  = "DejaVu Sans Mono";
var sizeMicro = 9;
var sizeSm    = 10;
var size      = 11;
var sizeMd    = 13;
var sizeLg    = 17;
var sizeXl    = 26;

// ---- Timing ---------------------------------------------------------------
var anim      = 120;         // short enough to feel instant, long enough to read
var osdHold   = 1400;

// Add an alpha channel to a "#rrggbb" literal. QML accepts "#aarrggbb".
function fade(hex, a) {
    var v = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16);
    if (v.length < 2) v = "0" + v;
    return "#" + v + hex.slice(1);
}

// Pick a colour for a 0..1 level: fine, getting low, low.
function levelColor(level) {
    if (level > 0.4) return text;
    if (level > 0.15) return warn;
    return bad;
}
