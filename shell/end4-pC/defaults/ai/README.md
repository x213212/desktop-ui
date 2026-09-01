# Assistant prompt provenance

The prompt templates in `prompts/` are selectable local defaults. Runtime
placeholders such as `{DISTRO}`, `{DE}`, `{DATETIME}`, and `{WINDOWCLASS}` are
expanded by the shell.

| File | Origin | License / status |
| --- | --- | --- |
| `NoPrompt.md` | Empty template | No expressive content |
| `ii-Default.md` | end-4/dots-hyprland | GPL-3.0-only, unmodified snapshot |
| `ii-Imouto.md` | end-4/dots-hyprland | GPL-3.0-only, unmodified snapshot |
| `nyarch-Acchan.md` | Modified from NyarchAssistant | GPL-3.0-or-later; see repository notices |
| `w-FourPointedSparkle.md` | Original desktop-ui clean-room template | GPL-3.0-only |
| `w-OpenMechanicalFlower.md` | Original desktop-ui clean-room template | GPL-3.0-only |

The two `w-*` templates were replaced on 2026-08-31. Their previous upstream
versions did not identify a redistributable source and are not part of the
current release tree. Full upstream revisions and copyright statements are in
the repository-level `THIRD_PARTY_NOTICES.md`.
