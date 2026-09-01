# Symbolic icon set

The six regular SVG files in this directory are original desktop-ui artwork,
created on 2026-08-31 and licensed under `GPL-3.0-only`:

- `avatar1-symbolic.svg`
- `circle-symbolic.svg`
- `crosshair-symbolic.svg`
- `desktop-symbolic.svg`
- `network-symbolic.svg`
- `spark-symbolic.svg`

The remaining SVG names are relative symbolic links to those generic designs.
They preserve compatibility with existing shell settings while avoiding bundled
third-party brand and distribution logos whose exact-file provenance was not
established. A compatibility filename does not mean that its target depicts,
is licensed by, or is endorsed by the named product or project.

Each regular SVG uses a `0 0 24 24` view box and a single monochrome fill. This
keeps sizing and colorization consistent in `CustomIcon.qml` and avoids the
misaligned geometry found in the previous mixed-source icon collection.
