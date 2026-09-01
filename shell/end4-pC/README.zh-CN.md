



<div align="center">

# 💠 end4-pC

**[illogical-impulse](https://github.com/end-4/dots-hyprland)（作者：[@end-4](https://github.com/end-4)）的个人分支**
由 **pctrade** 定制并维护

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

</div>

> [!IMPORTANT]
> 此目录是经过修改并内置于 desktop-ui 的上游快照，固定来源为
> [pctrade/end4-pC commit `369554b62de8d659875de828c779b83b28ae9ada`](https://github.com/pctrade/end4-pC/commit/369554b62de8d659875de828c779b83b28ae9ada)。
> 它包含 desktop-ui 于 2026-08-31 所做的修改，并非未经修改的官方上游版本。

---

## 🎬 展示

<p align="center">
  <a href="https://www.youtube.com/watch?v=o0Vsh7eVchs">
    <img src="https://img.youtube.com/vi/o0Vsh7eVchs/maxresdefault.jpg" alt="Material 3 Expressive x Linux" width="85%" style="border-radius: 12px; box-shadow: 0px 10px 30px rgba(0,0,0,0.5);"/>
  </a>
</p>

</div>

---

## 📸 截图
<div align="center">

| 桌面 | 锁屏 |
|:---:|:---:|
| ![desktop-ui 桌面](../../assets/showcase/desktop.webp) | ![desktop-ui 锁屏](../../assets/showcase/lock-screen.webp) |
| 通知 | |
| ![desktop-ui 通知](../../assets/showcase/notifications.webp) | |

</div>

这些是 desktop-ui 下游整合的实际截图；来源与隐私遮盖记录见
[`assets/showcase/README.md`](../../assets/showcase/README.md)。

---

## ⚡ 安装

> [!IMPORTANT]
> 此目录是 desktop-ui 内置的组件，不应单独安装。请勿将上游仓库直接
> clone 到正在使用的 Quickshell 配置中；请从仓库根目录按照
> [快速开始](../../README.md#quick-start) 操作。项目安装器默认仅预览，
> 并会说明备份与私有配置覆盖层。

---

### ⚙️ 设置快捷键

要打开设置面板，请将以下内容添加到 Hyprland 配置中：

```lua
hl.bind("SUPER + escape", hl.dsp.global("quickshell:settingsToggle"), {description = "Toggle settings"})
```

> **注意：** 设置是一个覆盖面板，而不是普通窗口，因此 `Super + Q` 无法将其关闭。请使用同一个快捷键进行切换，或按 `Escape`。

## 🙏 致谢

衷心感谢促成此项目的人们：

- **[@end-4](https://github.com/end-4)** — 创建了原始的 [dots-hyprland](https://github.com/end-4/dots-hyprland) / illogical-impulse shell。这个 dotfiles 项目堪称杰作 🫡
- **[@gh0stzk](https://github.com/gh0stzk)** — 提供了天气 API 集成，让天气小组件得以实现 🙌
- **[@StarS2112](https://github.com/StarS2112)** — 展示了此分支 🙌

---

<div align="center">

用 ❤️ 制作——欢迎自由分支并打造属于你自己的版本

</div>
