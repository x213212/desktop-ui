# Third-party notices

This document identifies material in the desktop-ui source tree that originated
outside this repository. It records the source revision where one can be
established, the local modification state, and the license that continues to
apply. The repository-level `LICENSE` does not replace any separately listed
terms or copyright notices.

Paths are relative to the repository root. A source described as **modified**
may contain desktop-ui changes in addition to the identified upstream work.
Project names are used only for attribution; no endorsement is implied.

## GPL-licensed foundations and components

### pctrade/end4-pC and end-4/dots-hyprland

- **Files:** `shell/end4-pC/**`, except separately identified components and
  original replacements below
- **Source:** [pctrade/end4-pC at
  `369554b62de8d659875de828c779b83b28ae9ada`](https://github.com/pctrade/end4-pC/tree/369554b62de8d659875de828c779b83b28ae9ada)
- **Lineage:** based on [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- **Copyright / attribution:** pctrade/end4-pC and end-4/dots-hyprland
  contributors
- **License:** GPL-3.0-only; see `LICENSES/GPL-3.0-only.txt`
- **State:** modified downstream snapshot

The vendored shell also retains the upstream GPL text at
`shell/end4-pC/LICENSE`.

### Hyprland configuration

- **Files:** `config/hypr/**`, except separately identified scripts below
- **Source:** [end-4/dots-hyprland at
  `97c5bc651f68092351b24aaa935af708b1e04514`](https://github.com/end-4/dots-hyprland/tree/97c5bc651f68092351b24aaa935af708b1e04514/dots/.config/hypr)
- **Copyright / attribution:** end-4/dots-hyprland contributors
- **License:** GPL-3.0-only
- **State:** a mixture of exact, modified, and desktop-ui-only files

### Caelestia shell-derived QML

- **Files:**
  - `shell/end4-pC/services/Brightness.qml`
  - `shell/end4-pC/services/Network.qml`
  - `shell/end4-pC/modules/common/Icons.qml`
  - `shell/end4-pC/modules/common/widgets/DirectoryIcon.qml`
- **Source:** [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
- **Copyright / attribution:** Caelestia shell contributors; upstream does not
  state a separate copyright holder for these files
- **License:** GPL-3.0-only
- **State:** modified. The exact revision imported by the intermediate fork was
  not recorded, so this notice intentionally does not invent one.

### Levenshtein scoring helper

- **File:** `shell/end4-pC/modules/common/functions/levendist.js`
- **Source:** [`hypryou/utils_cy/levenshtein.pyx` at
  `5c7688c0358cd386b5681f80f00b1eda99269c1a`](https://github.com/koeqaife/hyprland-material-you/blob/5c7688c0358cd386b5681f80f00b1eda99269c1a/hypryou/utils_cy/levenshtein.pyx)
- **Copyright / attribution:** Danik `<retikadni@gmail.com>` and
  hyprland-material-you contributors
- **License:** GPL-3.0-only
- **State:** translated from Cython to JavaScript with an LLM, reviewed, and
  modified as a subset for QML use

### Assistant prompt templates

- **Files:** `shell/end4-pC/defaults/ai/prompts/ii-Default.md` and
  `ii-Imouto.md`
- **Source:** [end-4/dots-hyprland at
  `97c5bc651f68092351b24aaa935af708b1e04514`](https://github.com/end-4/dots-hyprland/tree/97c5bc651f68092351b24aaa935af708b1e04514/dots/.config/quickshell/ii/defaults/ai/prompts)
- **Copyright / attribution:** end-4/dots-hyprland contributors
- **License:** GPL-3.0-only
- **State:** exact prompt bodies with local attribution comments

- **File:** `shell/end4-pC/defaults/ai/prompts/nyarch-Acchan.md`
- **Source:** [`NyarchAssistant/src/constants.py` at
  `053505ff5ba44ec08043e79f02d2c3449bdf55a1`](https://github.com/NyarchLinux/NyarchAssistant/blob/053505ff5ba44ec08043e79f02d2c3449bdf55a1/src/constants.py)
- **Copyright notice:** © 2025 qwersyk & NyarchLinux
- **Contributor attribution:** Francesco Caracciolo
- **License:** GPL-3.0-or-later; see `LICENSES/GPL-3.0-or-later.txt`
- **State:** personality text extracted and modified for the shell template

`NoPrompt.md` contains no expressive prompt. The two `w-*` prompts are original
desktop-ui clean-room replacements under GPL-3.0-only.

## Apache-2.0 components

### Rounded polygon QML-JavaScript port

- **Files:** `shell/end4-pC/modules/common/widgets/shapes/**`
- **Source:** [end-4/rounded-polygon-qmljs at
  `e31ec4cb4ebf6a46b267f5c42eabf6874916fa16`](https://github.com/end-4/rounded-polygon-qmljs/tree/e31ec4cb4ebf6a46b267f5c42eabf6874916fa16)
- **Copyright / attribution:** end-4; [Knugel / Florian Hofmair's
  rounded-polygon-ts](https://github.com/Knugel/rounded-polygon-ts); and
  AndroidX Graphics Shapes contributors
- **AndroidX notice:** Copyright 2022 The Android Open Source Project
- **License:** Apache-2.0; see the retained `shapes/LICENSE` and
  `LICENSES/Apache-2.0.txt`
- **State:** exact vendored tree. It is a QML-JavaScript port of the TypeScript
  port of AndroidX Graphics Shapes and includes the Material Design shape set.

### Material Symbols Rounded

- **Files:**
  - `shell/end4-pC/assets/fonts/MaterialSymbolsRounded.ttf`
  - `shell/end4-pC/assets/material_symbols_rounded.codepoints`
  - `shell/end4-pC/assets/material_symbols_rounded.json`
- **Source:** [google/material-design-icons at
  `50f0603134ce7b70b2d71b686cc13e8b57ccb74c`](https://github.com/google/material-design-icons/tree/50f0603134ce7b70b2d71b686cc13e8b57ccb74c/variablefont)
- **Copyright notice embedded in the font:** Copyright 2026 Google LLC. All
  Rights Reserved.
- **License:** Apache-2.0
- **State:** the font and codepoint list are exact pinned files. The JSON is a
  deterministic desktop-ui transformation containing 4,268 symbol names;
  `scripts/generate-material-symbols.py --check` reproduces it.

### Ollama loaded-model helper

- **File:** `config/hypr/hyprland/scripts/ai/show-loaded-ollama-models.sh`
- **Source:** [`LLM_Scripts/Ollama/show_loaded_models.sh` at
  `d0a9f86d9b6e6ed8103764803ed0209c4e38a82d`](https://github.com/strikeoncmputrz/LLM_Scripts/blob/d0a9f86d9b6e6ed8103764803ed0209c4e38a82d/Ollama/show_loaded_models.sh)
- **Copyright / attribution:** strikeoncmputrz / LLM_Scripts contributors;
  upstream states no separate copyright notice
- **License:** Apache-2.0; a copy is also retained beside the script
- **State:** modified

### FastPriorityQueue code embedded in fuzzysort

- **Containing file:** `shell/end4-pC/modules/common/functions/fuzzysort.js`
- **Source:** [lemire/FastPriorityQueue.js](https://github.com/lemire/FastPriorityQueue.js),
  through the pinned fuzzysort source listed below
- **Copyright / attribution:** Daniel Lemire `<lemire@gmail.com>` and
  FastPriorityQueue.js contributors
- **License:** Apache-2.0
- **State:** compact modified implementation embedded by fuzzysort

## MIT components

### fuzzysort

- **File:** `shell/end4-pC/modules/common/functions/fuzzysort.js`
- **Source:** [fuzzysort v3.0.2 at
  `6c134dbda39940c87097183954ef080972888668`](https://github.com/farzher/fuzzysort/blob/6c134dbda39940c87097183954ef080972888668/fuzzysort.js)
- **Copyright notice:** Copyright (c) 2018 Stephen Kamenar
- **License:** MIT, plus Apache-2.0 for the embedded FastPriorityQueue code
- **State:** modified for the QML JavaScript environment

### thumbnail-generator-ubuntu

- **File:** `shell/end4-pC/scripts/thumbnails/thumbgen.py`
- **Source:** [`thumbgen/thumbgen.py` at
  `cfee770c1b7811ea8ce49d5defc4b714eeb006c5`](https://github.com/difference-engine/thumbnail-generator-ubuntu/blob/cfee770c1b7811ea8ce49d5defc4b714eeb006c5/thumbgen/thumbgen.py)
- **Copyright notice:** Copyright (c) 2019 Functional Paradigms Pvt Ltd
- **License:** MIT
- **State:** modified for the GNOME 4 factory API, selectable sizes, and
  machine-readable progress output

### fuzzel-emoji data lineage

- **File:** `config/hypr/hyprland/scripts/fuzzel-emoji.sh`
- **Immediate source:** [end-4/dots-hyprland at
  `97c5bc651f68092351b24aaa935af708b1e04514`](https://github.com/end-4/dots-hyprland/blob/97c5bc651f68092351b24aaa935af708b1e04514/dots/.config/hypr/hyprland/scripts/fuzzel-emoji.sh)
- **Earlier sources:** [dln/wofi-emoji at
  `d73ed5e48660ae4d02ea5ff53c4cc1b64b6deb9f`](https://github.com/dln/wofi-emoji/tree/d73ed5e48660ae4d02ea5ff53c4cc1b64b6deb9f)
  and [muan/emojilib v3.0.6 at
  `45fd86d4b94ff94ea9c4600c39a14e60d64a9905`](https://github.com/muan/emojilib/tree/45fd86d4b94ff94ea9c4600c39a14e60d64a9905)
- **Copyright notices:** Copyright (c) 2020 Daniel Lundin; Copyright (c) 2014
  Mu-An Chiou
- **Licenses:** the earlier shell/data are MIT; end-4 additions and the combined
  local script are distributed under GPL-3.0-only
- **State:** functional content exact to the cited end-4 revision, with local
  attribution comments; modified downstream of the two MIT sources

The following MIT permission notice applies separately to the four copyright
notices above (Stephen Kamenar, Functional Paradigms Pvt Ltd, Daniel Lundin,
and Mu-An Chiou):

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to
> deal in the Software without restriction, including without limitation the
> rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
> sell copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The applicable copyright notice and this permission notice shall be included
> in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

The canonical MIT template is also retained at `LICENSES/MIT.txt`.

## CC BY 4.0 runtime weather data

### Open-Meteo

- **Consumers:** `shell/end4-pC/services/Weather.qml`, `bin/update-lock-weather`,
  and the weather views backed by those services
- **Service:** [Open-Meteo.com](https://open-meteo.com/)
- **Data license:** [Creative Commons Attribution 4.0 International
  (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/), as documented on
  Open-Meteo's [licence page](https://open-meteo.com/en/licence); the canonical
  text is retained at `LICENSES/CC-BY-4.0.txt`
- **State:** fetched at runtime and adapted by desktop-ui; forecast data is not
  committed to the repository

desktop-ui converts units, rounds values, translates WMO weather codes,
calculates rolling-hour interval overlap and aggregates rain/showers, applies
notification and animation thresholds, and presents localized summaries.
These transformations are changes to the source data; neither Open-Meteo nor
its upstream weather-model providers endorse the resulting presentation.

The default `api.open-meteo.com` endpoint is subject to Open-Meteo's current
[terms of use](https://open-meteo.com/en/terms), including its non-commercial
free-API limits. Commercial deployments must use an appropriate customer plan
and endpoint or self-host the service while complying with Open-Meteo's AGPL
and the applicable upstream-data licences.

Weather requests disclose the selected latitude and longitude to Open-Meteo
over HTTPS and expose ordinary connection metadata such as the source IP. The
repository seed disables GPS/GeoClue weather location; a request is made only
after the user opts in or supplies coordinates in the private `weather.env`.

## Runtime wallpaper services (content not bundled)

The optional online wallpaper selector queries
[Wallhaven](https://wallhaven.cc/help/api) and
[Unsplash](https://unsplash.com/documentation) at runtime. Search results and
downloads are not part of the repository and retain the rights and restrictions
specified by their creators and providers.

Unsplash results display linked photographer and Unsplash attribution with the
application referral parameters. Each user-initiated Unsplash download first
calls the API-provided download endpoint. Wallhaven results retain their source
page and uploader link. API credentials are read from the user's keyring, sent
in request headers, and are not source files.

## Public-domain geographic data

- **File:** `shell/end4-pC/modules/common/widgets/WorldMapDots.js`
- **Source:** [Natural Earth 1:110m Admin 0 – Countries](https://www.naturalearthdata.com/downloads/110m-cultural-vectors/)
- **Creators / attribution:** Tom Patterson, Nathaniel Vaughn Kelso, and Natural
  Earth contributors
- **Status:** Natural Earth states that its vector and raster map data are in
  the public domain
- **State:** generated and modified JavaScript representation

## Unsplash photograph

- **File:** `assets/wallpapers/uíos-landscape.jpg`
- **Work:** [“aerial view of village on mountain cliff during orange
  sunset”](https://unsplash.com/photos/aerial-view-of-village-on-mountain-cliff-during-orange-sunset-cYrMQA7a3Wc)
- **Copyright:** Anders Jildén
- **License:** [Unsplash License](https://unsplash.com/license)
- **State:** resized/cropped copy

The Unsplash License is not replaced by the repository GPL and does not grant
trademark, identifiable-person, or depicted-work rights beyond its own terms.

## Original and project-captured desktop-ui assets

The following replacements were created for this repository and are offered
under GPL-3.0-only to the extent licensable rights exist:

- `shell/end4-pC/assets/icons/`: six original generic SVG masters and their
  compatibility-name symlinks. No third-party logo artwork is bundled.
- `shell/end4-pC/assets/images/default_wallpaper.svg`: original vector artwork;
  `default_wallpaper.png` is its reproducibly rendered artifact.
- `shell/end4-pC/modules/ii/background/shaders/*.frag`: fourteen original
  shader sources; the neighboring `.qsb` files are reproducible Qt Shader Baker
  artifacts.
- `assets/showcase/*.webp`: real captures of the desktop-ui interface made on
  2026-08-31. The notification capture contains explicit opaque privacy covers;
  the lock component was rendered in an isolated preview because session-lock
  capture is intentionally unavailable. Capture method, modification boundaries,
  and checksums are recorded in `assets/showcase/README.md`. The visible Anders
  Jildén wallpaper remains under the separately listed Unsplash License.

Several UI, lock, media, keyring, and system-theming files also carry explicit
2026 desktop-ui clean-room headers. They replace earlier material and do not
retain source from the no-license references excluded by `scripts/verify.sh`.

## Referenced but not bundled

The manifests pin Quickshell and hyprland-plugins source revisions for optional
local builds. Their source is not vendored in this repository. Anyone
distributing resulting binaries must separately comply with the applicable
Quickshell LGPL-3.0 and hyprland-plugins BSD-3-Clause terms and provide any
required corresponding source or notices.
