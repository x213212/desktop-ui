# desktop-ui

A reproducible downstream desktop shell for Quickshell and Hyprland, designed
for deterministic multi-monitor workspace ownership and high-window-count
sessions.

This repository contains source code, declarative configuration, user services,
helper programs, and non-private assets. It intentionally excludes credentials,
notifications, chats, location values, and mutable session state.

Development and disclosure guidance is documented in
[`CONTRIBUTING.md`](CONTRIBUTING.md) and [`SECURITY.md`](SECURITY.md).

| Project scope | Status |
| --- | --- |
| Primary environment | Personal Linux desktop; Ubuntu 24.04 / Linux Mint baseline |
| Configuration model | Version-pinned source with machine-local private overlays |
| Deployment model | User-scoped, dry-run first, recoverable replacement |
| Upstream relationship | Independent downstream; no upstream support or endorsement |

> [!IMPORTANT]
> This is a substantially modified downstream snapshot of
> [pctrade/end4-pC commit `369554b62de8d659875de828c779b83b28ae9ada`](https://github.com/pctrade/end4-pC/commit/369554b62de8d659875de828c779b83b28ae9ada),
> committed upstream on 2026-08-24. That project is itself based on
> [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).
> desktop-ui is not an official release of, or endorsed by, either upstream.

![desktop-ui real desktop capture](assets/showcase/desktop.webp)

| Lock screen | Expanded notification panel |
| :---: | :---: |
| ![Actual lock-screen component](assets/showcase/lock-screen.webp) | ![Actual notification sidebar with private content covered](assets/showcase/notifications.webp) |

> These are captures of the actual desktop-ui interface on 2026-08-31, not
> generated mockups. Private notification, account, network, and location text
> is explicitly covered. The lock-screen component was rendered through a safe
> preview layer because Wayland correctly blocks capture while a session lock is
> active. Full capture provenance is in [`assets/showcase/README.md`](assets/showcase/README.md).

## Strengthening scope

The figures below describe reviewable engineering coverage in this revision,
not an estimated speed-up or a synthetic benchmark score.

| Area | Hardened scope | Reproducible evidence |
| --- | ---: | --- |
| Primary dual-output layout | 2 independent monitor roles; 20 primary workspace slots | 10 deterministic workspace IDs per role, with the same allocation rule extending to additional managed roles |
| Topology and restore guards | 9 regression tests across 2 suites | `python3 -m unittest discover -s tests -v` |
| Transition shaders | 14 readable fragment sources and 14 matching Qt Shader Baker artifacts | `bash scripts/build-shaders.sh --check` |
| Symbol search metadata | 4,268 names generated from a revision-pinned Google codepoint file | `python3 scripts/generate-material-symbols.py --check` |
| Project icon layer | 6 original generic SVG masters and 24 compatibility aliases | All 30 public icon paths resolve locally without bundling third-party brand artwork |
| Avoided UI work | 1 shared demand-driven MPRIS timer; reload diagnostics loaded on demand; 1 compatibility shadow pass removed | Review `MprisController.qml` and `ReloadPopup.qml` |

These counts make the extent of the hardening visible while keeping performance
claims honest. Actual frame time still depends on the compositor, GPU driver,
display topology, effects, and the content drawn inside each client window.

## Design objectives and implemented mechanisms

- Each monitor keeps an independent focus and workspace group. Switching on
  display A does not switch the UI on display B.
- Monitor role `N` owns workspaces `N*10+1..N*10+10`. Roles 0 and 1 support
  deterministic dual-output collapse and expansion after hotplug events.
- Workspace dragging, cross-monitor window moves, output removal, merge, and
  session restoration reject ambiguous or colliding routes.
- MPRIS position sampling uses one demand-driven timer shared by visible media
  consumers. Reload diagnostics are instantiated asynchronously, and their
  previous compatibility shadow pass has been removed.
- Fcitx5 runs under a restartable user service, replacing an earlier legacy
  autostart instance instead of competing with it.
- Installation, removal, and build tools are dry-run by default. They change
  user state only when explicitly given `--apply`.

No frame-rate or latency number is claimed without a reproducible benchmark.
The performance statements above describe mechanisms that can be reviewed in
source and verified under load on the target system.

## Workspace ownership model

| Monitor role | Owned workspaces | Hotplug behavior |
| --- | --- | --- |
| `0` | `1..10` | Participates in the managed two-output collapse/expand path |
| `1` | `11..20` | Participates in the managed two-output collapse/expand path |
| `N >= 2` | `N*10+1..N*10+10` | Retains stable ownership; no implicit merge |
| Unmanaged connector | None | Display-only until explicitly mapped |

Pointer focus, active workspace, stored session ownership, and move targets are
resolved against the physical output role. This prevents an action on one
display from silently changing another display's workspace state.

## Compatibility baseline

| Component | Pinned baseline |
| --- | --- |
| Hyprland | `0.56.2` |
| Quickshell | `0.2.1` at `7511545ee20664e3b8b8d3322c0ffe7567c56f7a` |
| Qt | `6.10.3` |
| Reference distribution | Ubuntu 24.04 / Linux Mint |

Exact source revisions and observed package versions are recorded in
[`manifests/versions.env`](manifests/versions.env). These pins are reproducibility
metadata. The repository does not add a PPA or run `apt install` automatically.

## Quick start

```bash
git clone https://github.com/x213212/desktop-ui.git
cd desktop-ui

bash scripts/check-deps.sh --all
bash scripts/verify.sh
bash scripts/install.sh          # preview only
bash scripts/install.sh --apply  # deploy after reviewing the plan
```

Existing static targets are not overwritten by default. If replacement is
intentional, use:

```bash
bash scripts/install.sh --apply --force
```

The installer first moves conflicting files to
`${XDG_STATE_HOME:-~/.local/state}/desktop-ui/backups/<timestamp>/`.
Shell-writable configuration, translations, Hyprland overrides, and lock-theme
files are installed as regular seed copies rather than symlinks back into Git.

### Optional components

```bash
# Create the pinned Quickshell helper environment.
bash scripts/bootstrap-python.sh
bash scripts/bootstrap-python.sh --apply

# Build the pinned Quickshell revision against the matching Qt installation.
bash scripts/build-quickshell.sh \
  --qt-prefix "$HOME/.local/opt/Qt/6.10.3/gcc_64"

# Build hyprbars only when the installed Hyprland ABI matches the lock.
bash scripts/build-hyprbars.sh

# Install optional integration units without enabling them.
bash scripts/install.sh --apply --include-integrations
```

Waynergy and Deskflow are mutually exclusive. EasyEffects, P14s lid debounce,
and other integration units are also opt-in; enable only the selected unit with
`systemctl --user enable --now ...` after reviewing it.

### Online wallpaper providers

Online search is optional and fetches previews at runtime; downloaded provider
content is never committed automatically. Wallhaven works with its public API
and accepts an optional key. Unsplash requires a developer access key stored in
the user's keyring. The UI keeps the photographer and provider links visible,
adds the required application referral parameters, and calls Unsplash's
download-tracking endpoint before every download. Provider content and API use
remain subject to the current [Wallhaven API rules](https://wallhaven.cc/help/api)
and [Unsplash API guidelines](https://unsplash.com/documentation).

## Monitor and private configuration

Machine connectors, cities, coordinates, and credentials do not belong in Git.
Create local configuration from the empty examples:

```bash
mkdir -p ~/.config/desktop-ui
cp private.example/host.env ~/.config/desktop-ui/host.env
cp private.example/weather.env ~/.config/desktop-ui/weather.env
```

- Use `hyprctl monitors -j` to map physical connectors to stable roles in
  `host.env`.
- GPS/GeoClue weather location is disabled in the repository seed and must be
  explicitly enabled in Settings. `weather.env` is an optional manual fallback.
  No weather request is sent when GPS is disabled and its coordinates are unset.
- When weather is enabled, the selected latitude and longitude are sent over
  HTTPS to Open-Meteo along with ordinary network metadata such as the source IP.
  Do not enable it or populate `weather.env` if that disclosure is unwanted.
- Defining any monitor role enables managed mode. List every output that should
  participate. An unknown connector may display a desktop, but it is not allowed
  to save, move, or merge managed workspaces.

## Repository layout

| Path | Purpose / deployment target |
| --- | --- |
| `shell/end4-pC/` | Quickshell UI -> `$XDG_CONFIG_HOME/quickshell/end4-pC` |
| `config/hypr/` | Hyprland, hypridle, and hyprlock configuration |
| `config/illogical-impulse/` | UI seed configuration and translations |
| `bin/` | Project helpers -> `$HOME/.local/bin` |
| `systemd/user/` | Core and optional integration user units |
| `assets/` | Wallpaper, project artwork, and optional fonts |
| `private.example/` | Empty, non-secret machine-specific templates |
| `system/` | PAM, LightDM, and hardware references; never auto-installed to `/etc` |
| `manifests/` | Versions, dependencies, and immutable asset checksums |

## Validation and removal

```bash
# Read-only repository validation.
bash scripts/verify.sh

# Also verify deployed symlinks and seed-copy types.
bash scripts/verify.sh --deployed

# Preview and then perform a scoped uninstall.
bash scripts/uninstall.sh
bash scripts/uninstall.sh --apply
```

The verifier checks JSON, shell syntax, user units, immutable assets, broken
links, provenance requirements, common secret signatures, and portability. It
rejects hard-coded `/home/<user>` and `/run/user/<uid>` paths.

## Security boundaries

- No GOA, keyring, Remmina, Waynergy TLS, API-token, or other credential data is
  stored or inspected.
- Quickshell caches, notifications, todos, notes, chats, and session state are
  not source-of-truth files and are excluded.
- Repository tools do not write to `/etc`, load a Hyprland plugin, restart the
  compositor, or enable a network integration automatically.
- Quickshell and hyprbars build paths verify the pinned source revision and ABI
  before installation.

## Licensing and provenance

desktop-ui's original contributions are offered under
[`GPL-3.0-only`](LICENSE). The combined modified GPL work is distributed under
the GPL, while separately identified third-party files and assets retain their
own copyright notices and license terms. A repository-level license does not
replace those terms.

The authoritative component-to-file mapping, upstream URLs, revision notes,
copyright statements, and modification status are in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Canonical license texts are
kept in [`LICENSES/`](LICENSES/). The vendored shell also retains its upstream
[`shell/end4-pC/LICENSE`](shell/end4-pC/LICENSE).

Weather data is provided by [Open-Meteo.com](https://open-meteo.com/) under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); see Open-Meteo's
[licence page](https://open-meteo.com/en/licence). desktop-ui adapts the API
response through unit conversion, rounding, WMO-code translation, rolling-hour
overlap and aggregation, rain thresholds, and localized presentation; its
output is therefore not an unmodified copy of the API data.
The default `api.open-meteo.com` endpoint is offered for non-commercial use
under Open-Meteo's current [terms](https://open-meteo.com/en/terms). Before a
commercial deployment, use an appropriate customer endpoint and plan, or
self-host Open-Meteo while complying with its AGPL and upstream-data terms.
The weather request includes the latitude and longitude selected through
GeoClue or `weather.env`; GPS is opt-in in the repository seed.

The bundled `assets/wallpapers/uíos-landscape.jpg` is a resized copy of Anders
Jildén's Unsplash photo
["aerial view of village on mountain cliff during orange sunset"](https://unsplash.com/photos/aerial-view-of-village-on-mountain-cliff-during-orange-sunset-cYrMQA7a3Wc),
used under the [Unsplash License](https://unsplash.com/license). Copyright in
the photograph remains with its author.

Product names, service names, and logos remain the property of their respective
owners. The licenses in this repository do not grant additional trademark
rights or imply upstream endorsement.
