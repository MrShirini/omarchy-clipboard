# Changelog

All notable changes to `mrshirini.clipboard` will be documented in this file.

## [1.1.0] - 2026-09-21

### ✨ What's New

- ⏸️ **Incognito Mode & History Pause**:
  - Temporarily pause clipboard capture to prevent passwords, API keys, and sensitive tokens from being written to disk.
  - Dynamic header toggle button: displays **`󰏤 Pause`** while active and switches to **`󰐊 Resume`** when paused.
  - Instant toggle via keyboard shortcut (<kbd>Alt</kbd>+<kbd>P</kbd>) or right-clicking the status bar widget (**`󰅌`** / **`󰏤`**).
  - Zero-touch bypass: `capture.sh` immediately aborts without touching disk or reading clipboard streams when paused.
  - Informative in-overlay banner with inline **`󰐊 Resume`** button.

- ⏳ **Auto-Purge & Retention Policy**:
  - Configure automatic expiration for unstarred history entries (e.g. 3 days, 7 days, 14 days, 30 days, 90 days, or disabled).
  - Starred (★) favorite clips are permanently protected and never removed by auto-purge.

- 💾 **Configurable Savings & Storage Limits**:
  - **Max Saved Entries**: Cap history depth to 50, 100, 300, 500, or 1000 items with oldest-unstarred eviction.
  - **Total History Size Cap**: Set disk limits on history data (1 MB, 2 MB, 5 MB, 10 MB).
  - **Image Cache Limit**: Configure image store disk limits (16 MB, 32 MB, 64 MB, 128 MB) with automatic orphan cleanup.

- 📐 **Overlay Window Sizing & Dimensions**:
  - **Preset Dimensions**: Choose between `Compact (600×420)`, `Medium (720×520)`, `Large (880×620)`, and `Expanded (1040×720)`.
  - **Fine-Tuning Adjusters**: Increment or decrement width and height in 40 px steps to fit your monitor setup.
  - Immediate live responsive resizing with automatic multi-monitor edge clamping.

- ⚙️ **In-Overlay Settings Drawer**:
  - Clean configuration panel opened via **⚙ Settings** in the header or <kbd>Ctrl</kbd>+<kbd>,</kbd>.
  - Seamless settings persistence to `settings.json` with immediate history pruning.
  - Header pause button automatically hides when Settings is open for an uncluttered configuration experience.

### 🛡️ Fixes & Improvements

- Updated test suite to 47 passing unit and integration tests covering capture, storage caps, retention, settings schema, and window dimensions.
- Validated with Omarchy plugin manifest schema version 1.

---

## [1.0.0] - 2026-09-17

- Initial release of `mrshirini.clipboard`.
- Top-right placement, favorites starring, category tagging, fuzzy search engine, privacy masking, and companion status bar widget.
