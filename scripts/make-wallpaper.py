#!/usr/bin/env python3
"""Generate Strata's default wallpaper.

The wallpaper is a section through rock: horizontal bands of cool stone,
separated by the same hairline the shell uses between its planes, lit faintly
from the lower left.  It is calm, text-free and has no focal point, because
everything worth looking at on this desktop is a tiled window on top of it
(BRANDING.md).

The image is generated rather than drawn by hand so that it is reproducible,
reviewable as a diff, and trivially re-rendered at another resolution:

    scripts/make-wallpaper.py [WIDTH HEIGHT OUTPUT]

Only the standard library is used — no Pillow, no ImageMagick, nothing that
would have to be installed to rebuild it.  hyprpaper reads PNG, so PNG is what
this writes.
"""

import math
import struct
import sys
import zlib

# Band boundaries as a fraction of the height, and the colour each band starts
# from.  Uneven on purpose: evenly spaced bands read as a chart.
BANDS = [
    (0.00, (0x09, 0x0c, 0x0f)),
    (0.17, (0x0c, 0x10, 0x15)),
    (0.30, (0x0a, 0x0d, 0x11)),
    (0.43, (0x10, 0x16, 0x1e)),
    (0.54, (0x0d, 0x12, 0x18)),
    (0.65, (0x13, 0x1a, 0x22)),
    (0.74, (0x0f, 0x15, 0x1c)),
    (0.84, (0x17, 0x1f, 0x28)),
    (0.93, (0x12, 0x19, 0x21)),
]

# Ordered dithering.  Smooth gradients over this small a range of dark values
# band badly on an 8-bit display; a sub-LSB pattern costs a little PNG size and
# removes the banding completely.
BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def build(width, height):
    rows = []

    # Per-band geometry, resolved to pixels once.
    edges = [int(f * height) for f, _ in BANDS] + [height]
    colors = [c for _, c in BANDS]

    # Light from the lower left, warm and very weak: enough to keep the
    # bottom-left corner from reading as flat black, not enough to notice.
    glow_x, glow_y = width * 0.24, height * 0.88
    glow_r = width * 0.62
    glow_tint = (7.0, 5.0, 2.5)

    band = 0
    for y in range(height):
        while band + 1 < len(edges) - 1 and y >= edges[band + 1]:
            band += 1

        top, bottom = edges[band], edges[band + 1]
        base = colors[band]
        span = max(1, bottom - top)
        into = (y - top) / span

        # Each band lightens slightly towards its own base.
        lift = 3.0 * into

        # The bedding plane: a bright hairline at the top of the band, and a
        # short shadow above it.  Its strength varies slowly along the width so
        # that the boundary reads as a seam in rock rather than a ruled line.
        dist = y - top
        edge = 11.0 * (1.0 - dist / 3.0) if dist < 3 else 0.0
        above = top - y
        if 0 < above <= 7:
            lift -= 3.0 * (1.0 - above / 7.0)

        dy2 = (y - glow_y) ** 2
        row = bytearray()
        row.append(0)  # PNG filter type: none

        bayer_row = BAYER[y & 3]

        phase = band * 1.7
        for x in range(width):
            # A very shallow falloff to the right, so the two halves of a
            # wide screen are not identical.
            u = x / width
            shade = lift - 2.2 * u
            if edge > 0.0:
                shade += edge * (0.55 + 0.45 * math.sin(u * 5.5 + phase))

            d = ((x - glow_x) ** 2 + dy2) ** 0.5 / glow_r
            g = 0.0
            if d < 1.0:
                g = (1.0 - d) ** 2

            dither = bayer_row[x & 3] / 16.0 - 0.5

            for c in range(3):
                v = base[c] + shade + glow_tint[c] * g + dither
                row.append(0 if v < 0 else (255 if v > 255 else int(v + 0.5)))

        rows.append(bytes(row))

    return b"".join(rows)


def chunk(tag, data):
    out = struct.pack(">I", len(data)) + tag + data
    return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path, width, height, raw):
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", header))
        fh.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        fh.write(chunk(b"IEND", b""))


def main():
    width = int(sys.argv[1]) if len(sys.argv) > 1 else 2560
    height = int(sys.argv[2]) if len(sys.argv) > 2 else 1440
    out = sys.argv[3] if len(sys.argv) > 3 else (
        "config/includes.chroot/usr/share/strata/wallpapers/strata-layers.png")

    write_png(out, width, height, build(width, height))
    print("wrote %s (%dx%d)" % (out, width, height))


if __name__ == "__main__":
    main()
