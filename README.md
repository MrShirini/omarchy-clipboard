# Omarchy Clipboard (Top-Right & Favorites)

An enhanced clipboard manager plugin for [Omarchy Linux](https://omarchy.org/) running on Quickshell and Hyprland.

Featuring **top-right positioning**, **favorites / starring**, **favorites filtering**, and an **optional status bar widget**, while seamlessly overriding the default Omarchy clipboard without breaking any existing workflows.

---

## ✨ Features

- ⭐ **Favorites & Pinning**: Click the star icon (`★` / `☆`) on any item or press <kbd>Alt</kbd>+<kbd>F</kbd> to mark important snippets, links, and text.
- 🛡️ **Protected History Clear**: Clearing history (<kbd>Shift</kbd>+<kbd>Delete</kbd>) preserves all starred items so you never lose frequently used clips.
- 🔄 **Re-Copy Persistence**: If you copy an item that was previously favorited, its favorite status is automatically preserved.
- ↗️ **Top-Right Screen Placement**: Positioned neatly under the top bar in the top-right corner, leaving your active workspace and windows visible.
- 🔍 **Favorites-Only View**: Click the **`★ Favorites`** button or press <kbd>Tab</kbd> to toggle between your full history and starred items.
- 📊 **Status Bar Widget**: Includes a companion status bar widget (`󰅌`) with tooltips and click-to-toggle support.
- ⚡ **Full Compatibility**: Cloned cleanly from `omarchy.clipboard`, automatically taking over <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>V</kbd>.

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
| <kbd>Alt</kbd> + <kbd>Enter</kbd> | Open item / URI in default app |
| <kbd>Alt</kbd> + <kbd>F</kbd> or <kbd>Alt</kbd> + <kbd>S</kbd> | Toggle favorite on selected item |
| <kbd>Ctrl</kbd> + <kbd>D</kbd> | Toggle favorite on selected item |
| <kbd>Tab</kbd> | Switch between **All History** and **★ Favorites** |
| <kbd>Delete</kbd> | Delete selected entry |
| <kbd>Shift</kbd> + <kbd>Delete</kbd> | Clear unstarred history (favorites are kept) |
| <kbd>Esc</kbd> | Clear search filter (or close overlay if search is empty) |

---

## 🛠️ Development & Manual Setup

If you want to clone and link the repository locally for development:

```bash
# Clone the repository
git clone https://github.com/MrShirini/omarchy-clipboard.git ~/Projects/omarchy-clipboard

# Symlink into Omarchy user plugins
ln -s ~/Projects/omarchy-clipboard ~/.config/omarchy/plugins/mrshirini.clipboard

# Validate the manifest schema
omarchy plugin validate ~/.config/omarchy/plugins/mrshirini.clipboard

# Rescan plugins and reload shell
omarchy-shell shell rescanPlugins
omarchy restart shell
```

---

## 📄 License

[MIT License](LICENSE) © 2026 Amir Shirini
