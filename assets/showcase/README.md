# Real screenshot provenance

The three images in this directory are captures of the actual desktop-ui QML
interface on 2026-08-31. They are not AI-generated illustrations, stock UI
mockups, benchmark captures, or evidence of a particular frame rate.

The source output was `eDP-1` at 3840x2160 with scale 2. Captures were made with
`grim`, reviewed locally at original resolution, resized to 1920x1080, stripped
of metadata, and encoded as WebP with ImageMagick. No geometry, controls,
wallpaper content, or performance effects were synthesized.

| Repository file | What it shows | Privacy / capture note | SHA-256 |
| --- | --- | --- | --- |
| `desktop.webp` | The running shell bar and an empty workspace | Direct live capture; no client window is visible | `9c50ba4e61de8c956ace25fc6c5e0c0bf6737da48e85776fdbb9c73b73f73b04` |
| `notifications.webp` | The live right sidebar opened from the notification bell | Local account, network name, Gmail content, and location-bearing weather content are covered with explicit privacy labels | `3f401abb5c239d0dc624ff3c0794b40b46c792f40840a5cdd3d1af05c0cf67a1` |
| `lock-screen.webp` | The actual `modules/ii/lock/LockSurface.qml` component | Rendered through a temporary, isolated preview layer with personal toolbars disabled; this avoids weakening or bypassing Wayland session-lock screenshot protection | `1f19e297ee8621cdd0d6332ed99235a3d4c5a25a509564127af663176005aec7` |

The lock-screen image demonstrates the real QML component and its visual state,
but it is intentionally not described as a capture taken while the compositor
was security-locked. The temporary preview source and isolated configuration
were removed after capture.

`notifications.webp` is the only edited screenshot. Its edits are limited to
opaque, clearly labeled privacy covers and the common resize/metadata-removal
pipeline. The unredacted notification capture was kept only in a temporary
directory and deleted after the reviewed derivative was produced.

The visible Vernazza wallpaper is a resized copy of Anders Jildén's photograph
and remains under the Unsplash License; see the repository-level
`THIRD_PARTY_NOTICES.md`. The desktop-ui interface remains under its applicable
GPL and component licenses. The screenshot copyright statement does not replace
the wallpaper or bundled component terms.
