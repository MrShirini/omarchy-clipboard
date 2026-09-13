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
- 🎯 **Type Filters & Detection**: Automatic content classification (`Classify.js`) categorizes entries into **Text**, **Links**, **Code**, **Images**, **Files**, and **Colors** with quick <kbd>Ctrl</kbd>+<kbd>1</kbd>..<kbd>7</kbd> filter chips and inline color swatches.
- 🔎 **Fuzzy Search Engine**: High-performance fuzzy matching (`Fuzzy.js`) with exact substring bonuses, word-boundary heuristics, and latency benchmarking (< 5ms over 500+ items).
- 🔒 **Sensitive Data Privacy Masking**: Automatic regex detection (`Sanitize.js`) for API keys (OpenAI, Anthropic, GitHub, AWS, Google), JWTs, private keys, and passwords. Secrets are masked in the list view (e.g. `sk-••••••1234`) with click-to-reveal to prevent shoulder surfing while preserving full unmasked text for pasting.
- 💾 **Hardened Persistence & Eviction**:
  - Atomic, debounced disk writes (300ms) with immediate flush on exit/mutation.
  - Corrupt JSON auto-recovery with automatic `.bak-<timestamp>` snapshots.
  - 64 KiB per-entry text cap with UI truncated badges.
  - 1 MiB total history cap and 32 MiB image store cap with oldest-unstarred eviction.
  - SHA-256 content-addressed image deduplication and background orphan image cleaner.
- 🖥️ **Multi-Monitor & Safe Edge Clamping**: Dynamically follows the active focused monitor (`Hyprland.focusedMonitor`) and prevents screen clipping or overlapping the bar.
- ⚙️ **User Configuration (`settings.json`)**: Configurable placement (`top-right`, `top-center`, `top-left`, `center`), custom offsets, shortcut overrides, and default tag palettes.
- 🎨 **Omarchy Theming Compliant**: Fully integrated with Omarchy theme tokens (`Color.accent`, `Color.menu.*`, `BorderSurface`) with instant reactive reload on theme change.
- 📊 **Status Bar Widget**: Includes a companion status bar widget (`󰅌`) with tooltips and click-to-toggle support.

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
| <kbd>Ctrl</kbd> + <kbd>1</kbd> .. <kbd>7</kbd> | Filter by type: All, Text, Links, Code, Images, Files, Colors |
| <kbd>Tab</kbd> | Switch between **All History** and **★ Favorites** |
| <kbd>Delete</kbd> | Delete selected entry |
| <kbd>Shift</kbd> + <kbd>Delete</kbd> | Clear unstarred history (favorites are kept) |
| <kbd>Esc</kbd> | Clear search filter (or close overlay if search is empty) |

---

## ⚙️ Configuration (`settings.json`)

You can customize the plugin by creating `~/.config/omarchy/plugins/mrshirini.clipboard/settings.json`:

```json
{
  "position": "top-right",
  "customOffset": { "x": 0, "y": 0 },
  "shortcuts": {
    "favorite": "Alt+F",
    "toggleFavoritesView": "Tab"
  },
  "defaultTagSet": ["Code", "Links", "Tokens", "Todo"],
  "maskSensitiveText": true
}
```

- `position`: `"top-right"` (default), `"top-center"`, `"top-left"`, or `"center"`.
- `customOffset`: Fine-tune pixel offset `{ "x": 0, "y": 0 }`.
- `shortcuts`: Custom key bindings matching your workflow.
- `defaultTagSet`: List of category tags suggested and shown in the tag selector.
- `maskSensitiveText`: `true` (default) to mask secrets in list view; `false` to disable masking.

---

## 🛠️ Development & Testing

```bash
# Clone the repository
git clone https://github.com/MrShirini/omarchy-clipboard.git ~/Projects/omarchy-clipboard
cd ~/Projects/omarchy-clipboard

# Run Node.js unit test suite (33 tests covering history, classifier, fuzzy, settings, sanitize)
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
