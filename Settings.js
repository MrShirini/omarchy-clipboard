var DEFAULT_SETTINGS = {
  position: "top-right",
  customOffset: { x: 0, y: 0 },
  shortcuts: {
    favorite: "Alt+F",
    toggleFavoritesView: "Tab",
    togglePause: "Alt+P",
    openSettings: "Ctrl+,"
  },
  defaultTagSet: ["Code", "Links", "Tokens", "Todo"],
  maskSensitiveText: true,
  pasteOnClick: false,
  maxHistoryEntries: 300,
  retentionDays: 0,
  maxTotalHistoryMB: 1,
  maxImageStoreMB: 32,
  windowSize: "medium",
  windowWidth: 720,
  windowHeight: 520
}

var ALLOWED_POSITIONS = ["top-right", "top-center", "top-left", "center"]
var ALLOWED_WINDOW_SIZES = ["compact", "medium", "large", "expanded", "custom"]
var WINDOW_SIZE_PRESETS = {
  compact: { width: 600, height: 420 },
  medium: { width: 720, height: 520 },
  large: { width: 880, height: 620 },
  expanded: { width: 1040, height: 720 }
}

function parseSettings(raw) {
  var str = String(raw || "").trim()
  if (!str) return Object.assign({}, DEFAULT_SETTINGS)

  try {
    var parsed = JSON.parse(str)
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return Object.assign({}, DEFAULT_SETTINGS)
    }

    var pos = String(parsed.position || "").toLowerCase()
    if (ALLOWED_POSITIONS.indexOf(pos) < 0) {
      pos = DEFAULT_SETTINGS.position
    }

    var offset = Object.assign({}, DEFAULT_SETTINGS.customOffset)
    if (parsed.customOffset && typeof parsed.customOffset === "object") {
      var ox = Number(parsed.customOffset.x)
      var oy = Number(parsed.customOffset.y)
      if (!isNaN(ox)) offset.x = ox
      if (!isNaN(oy)) offset.y = oy
    }

    var shortcuts = Object.assign({}, DEFAULT_SETTINGS.shortcuts)
    if (parsed.shortcuts && typeof parsed.shortcuts === "object") {
      for (var k in parsed.shortcuts) {
        if (typeof parsed.shortcuts[k] === "string" && parsed.shortcuts[k].trim()) {
          shortcuts[k] = parsed.shortcuts[k].trim()
        }
      }
    }

    var tags = DEFAULT_SETTINGS.defaultTagSet.slice()
    if (Array.isArray(parsed.defaultTagSet)) {
      var customTags = []
      for (var i = 0; i < parsed.defaultTagSet.length; i++) {
        var tag = String(parsed.defaultTagSet[i] || "").trim()
        if (tag && customTags.indexOf(tag) < 0) customTags.push(tag)
      }
      if (customTags.length > 0) tags = customTags
    }

    var maskSensitive = parsed.maskSensitiveText !== false
    var pasteOnClick = Boolean(parsed.pasteOnClick)

    var maxEntries = Number(parsed.maxHistoryEntries)
    if (isNaN(maxEntries) || maxEntries < 10) {
      maxEntries = DEFAULT_SETTINGS.maxHistoryEntries
    }

    var retention = Number(parsed.retentionDays)
    if (isNaN(retention) || retention < 0) {
      retention = DEFAULT_SETTINGS.retentionDays
    }

    var maxTotalMB = Number(parsed.maxTotalHistoryMB)
    if (isNaN(maxTotalMB) || maxTotalMB <= 0) {
      maxTotalMB = DEFAULT_SETTINGS.maxTotalHistoryMB
    }

    var maxImageMB = Number(parsed.maxImageStoreMB)
    if (isNaN(maxImageMB) || maxImageMB <= 0) {
      maxImageMB = DEFAULT_SETTINGS.maxImageStoreMB
    }

    var winSize = String(parsed.windowSize || "").toLowerCase()
    if (ALLOWED_WINDOW_SIZES.indexOf(winSize) < 0) {
      winSize = DEFAULT_SETTINGS.windowSize
    }

    var winWidth = Number(parsed.windowWidth)
    if (isNaN(winWidth) || winWidth < 400 || winWidth > 2560) {
      winWidth = (WINDOW_SIZE_PRESETS[winSize] && WINDOW_SIZE_PRESETS[winSize].width) || DEFAULT_SETTINGS.windowWidth
    }

    var winHeight = Number(parsed.windowHeight)
    if (isNaN(winHeight) || winHeight < 300 || winHeight > 1600) {
      winHeight = (WINDOW_SIZE_PRESETS[winSize] && WINDOW_SIZE_PRESETS[winSize].height) || DEFAULT_SETTINGS.windowHeight
    }

    return {
      position: pos,
      customOffset: offset,
      shortcuts: shortcuts,
      defaultTagSet: tags,
      maskSensitiveText: maskSensitive,
      pasteOnClick: pasteOnClick,
      maxHistoryEntries: maxEntries,
      retentionDays: retention,
      maxTotalHistoryMB: maxTotalMB,
      maxImageStoreMB: maxImageMB,
      windowSize: winSize,
      windowWidth: winWidth,
      windowHeight: winHeight
    }
  } catch (e) {
    return Object.assign({}, DEFAULT_SETTINGS)
  }
}

function parseShortcut(shortcutStr) {
  if (!shortcutStr || typeof shortcutStr !== "string") return null
  var raw = shortcutStr.split("+")
  var parts = []
  for (var i = 0; i < raw.length; i++) {
    var p = raw[i].trim().toLowerCase()
    if (p) parts.push(p)
  }
  if (parts.length === 0) return null

  var ctrl = false
  var alt = false
  var shift = false
  var meta = false
  var key = ""

  for (var j = 0; j < parts.length; j++) {
    var part = parts[j]
    if (part === "ctrl" || part === "control") ctrl = true
    else if (part === "alt") alt = true
    else if (part === "shift") shift = true
    else if (part === "meta" || part === "super" || part === "win") meta = true
    else key = part
  }

  return { ctrl: ctrl, alt: alt, shift: shift, meta: meta, key: key }
}

function matchesShortcut(event, shortcutStr, qt) {
  var spec = parseShortcut(shortcutStr)
  if (!spec || !event) return false

  var q = qt || (typeof Qt !== "undefined" ? Qt : null)
  var altMod = q ? q.AltModifier : 0x08000000
  var ctrlMod = q ? q.ControlModifier : 0x04000000
  var shiftMod = q ? q.ShiftModifier : 0x02000000
  var metaMod = q ? q.MetaModifier : 0x10000000

  var eventMods = event.modifiers || 0
  var hasCtrl = Boolean(eventMods & ctrlMod)
  var hasAlt = Boolean(eventMods & altMod)
  var hasShift = Boolean(eventMods & shiftMod)
  var hasMeta = Boolean(eventMods & metaMod)

  if (spec.ctrl !== hasCtrl || spec.alt !== hasAlt || spec.shift !== hasShift || spec.meta !== hasMeta) {
    return false
  }

  var k = spec.key
  var eventKey = event.key

  if (k.length === 1) {
    var upperCode = k.toUpperCase().charCodeAt(0)
    if (eventKey === upperCode) return true
  }

  if (q) {
    if (k === "tab" && (eventKey === q.Key_Tab || eventKey === q.Key_Backtab)) return true
    if (k === "escape" && eventKey === q.Key_Escape) return true
    if (k === "return" && eventKey === q.Key_Return) return true
    if (k === "enter" && (eventKey === q.Key_Enter || eventKey === q.Key_Return)) return true
    if (k === "space" && eventKey === q.Key_Space) return true
    if (k === "delete" && eventKey === q.Key_Delete) return true
    if (k === "backspace" && eventKey === q.Key_Backspace) return true
  } else {
    if (k === "tab" && (eventKey === 0x01000001 || eventKey === 0x01000002)) return true
    if (k === "escape" && eventKey === 0x01000000) return true
    if (k === "return" && eventKey === 0x01000004) return true
    if (k === "enter" && (eventKey === 0x01000005 || eventKey === 0x01000004)) return true
    if (k === "space" && eventKey === 0x20) return true
  }

  return false
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_SETTINGS: DEFAULT_SETTINGS,
    ALLOWED_POSITIONS: ALLOWED_POSITIONS,
    ALLOWED_WINDOW_SIZES: ALLOWED_WINDOW_SIZES,
    WINDOW_SIZE_PRESETS: WINDOW_SIZE_PRESETS,
    parseSettings: parseSettings,
    parseShortcut: parseShortcut,
    matchesShortcut: matchesShortcut
  }
}

