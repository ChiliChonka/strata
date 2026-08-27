# Strata Visual Assets

Planned structure:

```text
assets/
├── brand/
│   ├── logo-mark.svg
│   ├── wordmark.svg
│   └── logo.svg
├── wallpapers/
│   └── default.*
└── greeter/
    └── background.*
```

## The wallpaper is generated

The default wallpaper is not stored here. It is rendered by
`scripts/make-wallpaper.py` straight into the image tree at
`config/includes.chroot/usr/share/strata/wallpapers/strata-layers.png`, so the
script is the editable source and the PNG is the only copy.

Rebuild it, at any resolution, with:

```bash
scripts/make-wallpaper.py [WIDTH HEIGHT OUTPUT]
```

Only the Python standard library is used — nothing has to be installed to
re-render it, and a change to the design shows up in review as a diff of the
code that draws it rather than as an opaque binary blob.

## Policy

- Prefer SVG for logos.
- Keep editable source assets.
- Document licenses.
- Do not embed branding directly into functional scripts or binaries.
- Functional code must not depend on visual assets being present.
