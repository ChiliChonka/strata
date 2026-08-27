//
// A section label.
//
// Small, spaced capitals — the way a stratigraphic column labels its layers.
// Used as the heading of every group inside a panel.
//
import QtQuick
import "../theme.js" as Theme

Text {
    font.family: Theme.font
    font.pixelSize: Theme.sizeMicro
    font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
    color: Theme.subtle
}
