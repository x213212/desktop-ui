



<div align="center">

# 💠 end4-pC

**A personal fork of [illogical-impulse](https://github.com/end-4/dots-hyprland) by [@end-4](https://github.com/end-4)**  
Customized and maintained by **pctrade**

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

</div>

> [!IMPORTANT]
> This directory is a modified vendored snapshot of
> [pctrade/end4-pC commit `369554b62de8d659875de828c779b83b28ae9ada`](https://github.com/pctrade/end4-pC/commit/369554b62de8d659875de828c779b83b28ae9ada),
> committed upstream on 2026-08-24. The desktop-ui snapshot contains x213212's
> modifications dated 2026-08-31; it is not an unmodified or official upstream
> release.

---

## 🎬 Showcase

<p align="center">
  <a href="https://www.youtube.com/watch?v=o0Vsh7eVchs">
    <img src="https://img.youtube.com/vi/o0Vsh7eVchs/maxresdefault.jpg" alt="Material 3 Expressive x Linux" width="85%" style="border-radius: 12px; box-shadow: 0px 10px 30px rgba(0,0,0,0.5);"/>
  </a>
</p>

</div>

---

## 📸 Screenshots
<div align="center">

| Desktop | Lock screen |
|:---:|:---:|
| ![desktop-ui desktop](../../assets/showcase/desktop.webp) | ![desktop-ui lock screen](../../assets/showcase/lock-screen.webp) |
| Notifications | |
| ![desktop-ui notifications](../../assets/showcase/notifications.webp) | |

</div>

These are captures of the downstream desktop-ui integration. Their provenance
and redaction record are documented in
[`assets/showcase/README.md`](../../assets/showcase/README.md).

---

## ⚡ Installation

> [!IMPORTANT]
> This directory is a vendored component of desktop-ui, not a standalone
> checkout. Do not install it by cloning the upstream repository into your live
> Quickshell configuration. Follow the project-level
> [Quick start](../../README.md#quick-start) from the repository root; its
> installer is dry-run by default and documents backups and private overlays.

---

### ⚙️ Settings keybind

To open the settings panel, add this to your Hyprland config:

```lua
hl.bind("SUPER + escape", hl.dsp.global("quickshell:settingsToggle"), {description = "Toggle settings"})
```

> **Note:** Settings is an overlay panel, not a regular window — `Super + Q` won't close it. Use the same keybind to toggle it or press `Escape`.

---

## ❓ FAQ

### How do I see my keybinds?

Open the launcher (`SUPER`) and type `<` — it'll show you the full list of configured keybinds.

### Why doesn't Settings have a search bar?

It doesn't need one — the launcher already does that job. Open the launcher (`SUPER`) and just type what you're looking for (e.g. `wallpaper`, `bar`, `blur`); it'll match against page names and section keywords and jump you straight to the right Settings page, so there's no need for a separate search inside Settings itself.

---

## 🙏 Credits

Huge thanks to the people who made this possible:

- **[@end-4](https://github.com/end-4)** — for creating the original [dots-hyprland](https://github.com/end-4/dots-hyprland) / illogical-impulse shell. An absolute masterpiece of a dotfiles project 🫡
- **[@gh0stzk](https://github.com/gh0stzk)** — for providing the weather API integration that made the weather widget possible 🙌
- **[@StarS2112](https://github.com/StarS2112)** — for showcasing this fork 🙌
- **[@simeulinuxkaliaiwr](https://github.com/simeulinuxkaliaiwr)** — for some shader transitions 🎨
- **[Anders Jildén](https://unsplash.com/photos/aerial-view-of-village-on-mountain-cliff-during-orange-sunset-cYrMQA7a3Wc)** — for the bundled Vernazza wallpaper, used under the [Unsplash License](https://unsplash.com/license).

The upstream shell and this modified snapshot use GPLv3; see [`LICENSE`](LICENSE)
here and the repository-level [`LICENSE`](../../LICENSE). Separately identified
third-party files remain under their own notices and license terms.

---

<div align="center">

Made with ❤️ — feel free to fork and make it your own

</div>
