# Omarchy Clipboard (Favorites, Tags & Type Filters)

[![CI](https://github.com/MrShirini/omarchy-clipboard/actions/workflows/ci.yml/badge.svg)](https://github.com/MrShirini/omarchy-clipboard/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An advanced clipboard manager plugin for [Omarchy Linux](https://omarchy.org/) running on Quickshell and Hyprland.

Featuring **favorites & pinning**, **category tags**, **type filtering & fuzzy search**, **sensitive data privacy masking**, **user-configurable placement**, and an **optional status bar widget**, while seamlessly overriding the default Omarchy clipboard without breaking any existing workflows.

---

## ✨ Features

- ⭐ **Favorites & Pinning**: Click the star icon (`★` / `☆`) or press <kbd>Alt</kbd>+<kbd>F</kbd> / <kbd>Ctrl</kbd>+<kbd>D</kbd> to star important snippets, links, and text.
- 🏷️ **Category Tags**: Tag favorited clips (`#Code`, `#Links`, `#Tokens`, `#Todo`) with one-click toggles in the preview pane and filter by tag directly in the Favorites view.
- 🛡️ **Protected History Clear**: Clearing history (<kbd>Shift</kbd>+<kbd>Delete</kbd>) retains all starred items so you never lose frequently used clips.
- ⏸️ **Incognito Mode & History Pause**: Temporarily halt clipboard recording (<kbd>Alt</kbd>+<kbd>P</kbd>, the header button, or right-clicking the status bar widget `󰅌` / `󰏤`) so sensitive passwords and confidential tokens are never stored to disk.
- ⏳ **Auto-Purge & Retention Policy**: Automatically purge non-starred clips older than a configured period (e.g. 24 hours, 7 days, 14 days, 30 days, 90 days, or keep forever). Starred (★) favorites are permanently protected from auto-purge.
- 💾 **Configurable Savings & Storage Limits**: Customize maximum saved history entries (50 to 1000 items), total JSON store size cap (1 to 10 MB), and image store cache limit (16 to 128 MB) with oldest-unstarred eviction.
- ⚙️ **In-Overlay Settings GUI**: Click the **⚙ Settings** button in the header or press <kbd>Ctrl</kbd>+<kbd>,</kbd> to configure overlay window dimensions (presets + custom width/height), placement, capacity, retention, privacy masking, and paste behavior directly without editing JSON.
- 🎯 **Type Filters & Detection**: Automatic content classification (`Classify.js`) categorizes entries into **Text**, **Links**, **Code**, **Images**, **Files**, and **Colors** with quick <kbd>Ctrl</kbd>+<kbd>1</kbd>..<kbd>7</kbd> filter chips and inline color swatches.
- 🔎 **Fuzzy Search Engine**: High-performance fuzzy matching (`Fuzzy.js`) with exact substring bonuses, word-boundary heuristics, and latency benchmarking (< 5ms over 500+ items).
- 🔒 **Sensitive Data Privacy Masking**: Automatic regex detection (`Sanitize.js`) for API keys (OpenAI, Anthropic, GitHub, AWS, Google), JWTs, private keys, and passwords. Secrets are masked in the list view (e.g. `sk-••••••1234`) with click-to-reveal to prevent shoulder surfing while preserving full unmasked text for pasting.
- 💾 **Hardened Persistence & Eviction**:
  - Atomic, debounced disk writes (300ms) with immediate flush on exit/mutation.
  - Corrupt JSON auto-recovery with automatic `.bak-<timestamp>` snapshots.
  - 64 KiB per-entry text cap with UI truncated badges.
  - Bounded text and image stream reader (1 MiB text ceiling, 10 MiB image cap per entry, configurable via `CLIPBOARD_MAX_TEXT_BYTES` and `CLIPBOARD_MAX_IMAGE_BYTES`) with immediate stream abort and temp file cleanup.
  - Configurable total history cap and image store cap with oldest-unstarred eviction.
  - SHA-256 content-addressed image deduplication and background orphan image cleaner.
- 🖥️ **Multi-Monitor & Safe Edge Clamping**: Dynamically follows the active focused monitor (`Hyprland.focusedMonitor`) and prevents screen clipping or overlapping the bar.
- ⚙️ **User Configuration (`settings.json`)**: Configurable placement (`top-right`, `top-center`, `top-left`, `center`), custom offsets, shortcut overrides, retention policy, capacity limits, and default tag palettes.
- 🎨 **Omarchy Theming Compliant**: Fully integrated with Omarchy theme tokens (`Color.accent`, `Color.menu.*`, `BorderSurface`) with instant reactive reload on theme change.
- 📊 **Status Bar Widget**: Includes a companion status bar widget (`󰅌` active / `󰏤` paused) with tooltips, click-to-toggle, and right-click pause toggle.

---

## 📦 Installation

Install directly using Omarchy's built-in plugin manager:

```bash
omarchy plugin add https://github.com/MrShirini/omarchy-clipboard.git --enable
```

To add the clipboard widget to your status bar, place it into your `~/.config/omarchy/shell.json` in the `bar.layout.right` section:

```json
{
  "bar": {
    "layout": {
      "right": [
        { "id": "mrshirini.clipboard" }
      ]
    }
  }
}
```

Or move it interactively:
```bash
omarchy bar move mrshirini.clipboard --section right
```

### 🗑️ Removal & Disabling

```bash
# Temporarily disable the plugin
omarchy plugin disable mrshirini.clipboard

# Completely uninstall the plugin
omarchy plugin remove mrshirini.clipboard --yes
```

### 📋 Prerequisites & Dependencies

Standard Omarchy utilities (pre-installed by default on Omarchy Linux):
- `wl-clipboard` (`wl-paste`, `wl-copy`)
- `jq`
- `perl`

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>V</kbd> | Toggle clipboard manager overlay |
| <kbd>↑</kbd> / <kbd>↓</kbd> | Navigate clipboard items |
| <kbd>Enter</kbd> | Paste selected item |
| <kbd>Shift</kbd> + <kbd>Enter</kbd> | Copy selected item to clipboard (without pasting) |
| <kbd>Alt</kbd> + <kbd>Enter</kbd> | Open item / URI in default application |
| <kbd>Alt</kbd> + <kbd>F</kbd> or <kbd>Alt</kbd> + <kbd>S</kbd> | Toggle favorite on selected item |
| <kbd>Ctrl</kbd> + <kbd>D</kbd> | Toggle favorite on selected item |
| <kbd>Alt</kbd> + <kbd>P</kbd> | Toggle **Incognito / Pause Recording** mode |
| <kbd>Ctrl</kbd> + <kbd>,</kbd> | Toggle in-overlay **Settings & Preferences** view |
| <kbd>Ctrl</kbd> + <kbd>1</kbd> .. <kbd>7</kbd> | Filter by type: All, Text, Links, Code, Images, Files, Colors |
| <kbd>Tab</kbd> | Switch between **All History** and **★ Favorites** |
| <kbd>Delete</kbd> | Delete selected entry |
| <kbd>Shift</kbd> + <kbd>Delete</kbd> | Clear unstarred history (favorites are kept) |
| <kbd>Esc</kbd> | Close settings / clear search filter / close overlay |
| Click item | Copy item to clipboard (or auto-paste if configured) |
| <kbd>Alt</kbd> + Click item | Open item / URI in default application |
| Right-click bar widget | Toggle **Incognito / Pause Recording** mode |

---

## ⚙️ Configuration (`settings.json`)

Settings can be managed interactively via the **⚙ Settings** button in the overlay or by creating `~/.config/omarchy/plugins/mrshirini.clipboard/settings.json`:

```json
{
  "position": "top-right",
  "customOffset": { "x": 0, "y": 0 },
  "shortcuts": {
    "favorite": "Alt+F",
    "toggleFavoritesView": "Tab",
    "togglePause": "Alt+P",
    "openSettings": "Ctrl+,"
  },
  "defaultTagSet": ["Code", "Links", "Tokens", "Todo"],
  "maskSensitiveText": true,
  "pasteOnClick": false,
  "maxHistoryEntries": 300,
  "retentionDays": 0,
  "maxTotalHistoryMB": 1,
  "maxImageStoreMB": 32
}
```

- `position`: `"top-right"` (default), `"top-center"`, `"top-left"`, or `"center"`.
- `customOffset`: Fine-tune pixel offset `{ "x": 0, "y": 0 }`.
- `shortcuts`: Custom key bindings matching your workflow (`favorite`, `toggleFavoritesView`, `togglePause`, `openSettings`).
- `defaultTagSet`: List of category tags suggested and shown in the tag selector.
- `maskSensitiveText`: `true` (default) to mask secrets in list view; `false` to disable masking.
- `pasteOnClick`: `false` (default) copies item to clipboard on click without pasting; `true` automatically pastes on click.
- `maxHistoryEntries`: `300` (default) maximum entries preserved in history (oldest unstarred entries evicted first).
- `retentionDays`: `0` (default, disabled) or positive integer (e.g. `14` days) to auto-purge unstarred entries older than the threshold. Starred favorites are always kept.
- `maxTotalHistoryMB`: `1` (default) total JSON history file ceiling in megabytes.
- `maxImageStoreMB`: `32` (default) total disk space allocated for cached clipboard images.
- `windowSize`: `"medium"` (default), `"compact"`, `"large"`, `"expanded"`, or `"custom"`.
- `windowWidth`: `720` (default) base overlay width in pixels.
- `windowHeight`: `520` (default) base overlay height in pixels.

---

## 🛠️ Development & Testing

```bash
# Navigate to the repository directory
cd ~/Projects/omarchy-clipboard

# Run Node.js unit test suite (47 tests covering history, retention, capture, fuzzy, settings, sanitize)
npm test

# Validate manifest schema and plugin syntax
omarchy plugin validate .

# Symlink into Omarchy user plugins
ln -s ~/Projects/omarchy-clipboard ~/.config/omarchy/plugins/mrshirini.clipboard

# Rescan plugins and reload shell
omarchy-shell shell rescanPlugins
omarchy restart shell
```

---

## 📄 License & Attribution

- Released under the [MIT License](LICENSE) © 2026 Amir Shirini.
- Forked and enhanced from `omarchy.clipboard` © 2024–2026 Omacom under MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for full details.
