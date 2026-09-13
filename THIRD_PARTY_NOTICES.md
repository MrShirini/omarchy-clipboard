# Third-Party Notices & Attribution

This project is an enhanced fork of the official `omarchy.clipboard` plugin from [Omarchy Linux](https://omarchy.org/) by [Omacom](https://github.com/omacom).

### `omarchy.clipboard`
- Source: https://github.com/omacom/omarchy (licensed under MIT License)
- Copyright (c) 2024–2026 Omacom and Omarchy Contributors

Modifications and enhancements made by Amir Shirini:
- Favorited/pinned clipboard history and retention across clears
- Content-addressed image deduplication with SHA-256 and automatic orphan sweeping
- MIME type discrimination and safe RFC 2483 percent-decoding for `text/uri-list`
- Type classification (`Classify.js`) and interactive filter chips (Text, Links, Code, Images, Files, Colors)
- Scoring and ranking fuzzy search engine (`Fuzzy.js`)
- Configurable settings via `settings.json` (`Settings.js`) for positioning (`top-right`, `top-center`, `top-left`, `center`) and custom offsets
- Category tagging (`#Code`, `#Links`, `#Tokens`, `#Todo`) for favorited entries with tag-based filtering
- Sensitive credential detection and list-view privacy masking (`Sanitize.js`) with click-to-reveal
- Multi-monitor dynamic screen binding and bounds clamping
- Fully compliant with Omarchy design system tokens (`Color.accent`, `Color.menu.*`, `BorderSurface`)
