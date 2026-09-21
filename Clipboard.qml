import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory
import "Classify.js" as Classify
import "Fuzzy.js" as Fuzzy
import "Settings.js" as Settings
import "Sanitize.js" as Sanitize

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property bool opened: false
  property string filterText: ""
  property bool favoritesOnly: false
  property string activeTypeFilter: "all"
  property string activeTagFilter: "all"
  property var revealedItems: ({})
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool clearConfirmOpen: false
  property bool paused: false
  property bool settingsOpen: false
  property var history: []

  property string settingsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy/plugins/mrshirini.clipboard/settings.json"
  property var settings: Settings.DEFAULT_SETTINGS

  property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy"
  property string historyPath: stateDir + "/clipboard-history.json"
  property string pausedPath: stateDir + "/clipboard-paused"

  FileView {
    id: pausedFile
    path: root.pausedPath
    watchChanges: true
    printErrors: false
    onLoaded: root.paused = true
    onLoadFailed: root.paused = false
    onFileChanged: reload()
  }

  Process {
    id: togglePauseFileProc
    command: ["true"]
  }

  function togglePause() {
    root.setPaused(!root.paused)
  }

  function setPaused(val) {
    root.paused = val
    if (val) {
      togglePauseFileProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")"; touch "$1"', "pause", root.pausedPath]
    } else {
      togglePauseFileProc.command = ["sh", "-c", 'rm -f "$1"', "pause", root.pausedPath]
    }
    togglePauseFileProc.running = true
  }

  function loadSettings(raw) {
    root.settings = Settings.parseSettings(raw)
  }

  function updateSettings(patchObj) {
    var copy = Object.assign({}, root.settings, patchObj)
    root.settings = Settings.parseSettings(JSON.stringify(copy))
    settingsFile.setText(JSON.stringify(root.settings, null, 2) + "\n")

    // Prune history immediately if capacity or retention changed
    var retention = (root.settings && root.settings.retentionDays) || 0
    var list = root.history.slice()
    if (retention > 0) {
      list = ClipboardHistory.pruneRetention(list, retention)
    }
    var limit = (root.settings && root.settings.maxHistoryEntries) || root.historyLimit
    var maxBytes = ((root.settings && root.settings.maxTotalHistoryMB) || 1) * 1024 * 1024
    var maxImageBytes = ((root.settings && root.settings.maxImageStoreMB) || 32) * 1024 * 1024
    list = ClipboardHistory.pruneTotalSize(list, maxBytes)
    list = ClipboardHistory.pruneImageStore(list, maxImageBytes)
    if (list.length > limit) {
      list = list.slice(0, limit)
    }
    root.history = list
    root.saveHistory(true)
    root.rebuildDisplay()
  }

  function updateSetting(key, val) {
    var patch = {}
    patch[key] = val
    root.updateSettings(patch)
  }

  function toggleReveal(historyIdx) {
    var copy = Object.assign({}, root.revealedItems)
    copy[historyIdx] = !copy[historyIdx]
    root.revealedItems = copy
    root.rebuildDisplay()
  }

  function toggleTagOnIndex(displayIdx, tag) {
    if (displayIdx < 0 || displayIdx >= displayModel.count) return
    var row = displayModel.get(displayIdx)
    if (!row) return
    root.history = ClipboardHistory.toggleEntryTag(root.history, row.historyIndex, tag)
    root.saveHistory()
    root.rebuildDisplay()
  }
  property string captureScript: Qt.resolvedUrl("capture.sh").toString().replace(/^file:\/\//, "")
  // Shares the [menu] surface tokens — themes that style the menu also
  // style the clipboard. Selected-row colors composed in the
  // singleton so consumers drop them straight into Rectangle bindings.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property var currentScreen: null

  function activeScreen() {
    var monitor = Hyprland.focusedMonitor
    if (!monitor) return (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var scr = Quickshell.screens[i]
      if (scr && (scr.name === monitor.name || scr === monitor)) return scr
    }
    return (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
  }

  property int cardWidth: {
    var targetW = (root.settings && root.settings.windowWidth) || 720
    var maxW = panel && panel.width > 0 ? panel.width - Style.gapsOut * 2 : Style.space(targetW)
    return Math.max(Math.min(Style.space(320), maxW), Math.min(Style.space(targetW), maxW))
  }
  property int cardHeight: {
    var barH = Style.bar.sizeHorizontal
    var targetH = (root.settings && root.settings.windowHeight) || 520
    var maxH = panel && panel.height > 0 ? panel.height - barH - Style.gapsOut * 2 : Style.space(targetH)
    return Math.max(Math.min(Style.space(240), maxH), Math.min(Style.space(targetH), maxH))
  }
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int historyLimit: (root.settings && root.settings.maxHistoryEntries) || 300

  function open(payloadJson) {
    root.currentScreen = root.activeScreen()
    root.opened = true
    root.settingsOpen = false
    var retention = (root.settings && root.settings.retentionDays) || 0
    if (retention > 0) {
      root.history = ClipboardHistory.pruneRetention(root.history, retention)
    }
    root.filterText = ""
    root.favoritesOnly = false
    root.activeTypeFilter = "all"
    root.activeTagFilter = "all"
    root.revealedItems = ({})
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.cancelClearHistory()
    root.settingsOpen = false
    root.opened = false
    if (saveDebounceTimer.running) {
      saveDebounceTimer.stop()
      root.flushSaveHistory()
    }
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function normalizeEntry(value) {
    return ClipboardHistory.normalizeEntry(value)
  }

  function entryKey(entry) {
    return ClipboardHistory.entryKey(entry)
  }

  function loadHistory(raw) {
    var res = ClipboardHistory.parseHistoryResult(raw)
    if (res.corrupted) {
      console.warn("Omarchy clipboard: corrupted history detected, creating backup. Error:", res.error)
      backupCorruptProc.running = true
    }
    var list = res.entries
    var retention = (root.settings && root.settings.retentionDays) || 0
    if (retention > 0) {
      list = ClipboardHistory.pruneRetention(list, retention)
    }
    var limit = (root.settings && root.settings.maxHistoryEntries) || root.historyLimit
    var maxBytes = ((root.settings && root.settings.maxTotalHistoryMB) || 1) * 1024 * 1024
    var maxImageBytes = ((root.settings && root.settings.maxImageStoreMB) || 32) * 1024 * 1024
    list = ClipboardHistory.pruneTotalSize(list, maxBytes)
    list = ClipboardHistory.pruneImageStore(list, maxImageBytes)
    if (list.length > limit) {
      list = list.slice(0, limit)
    }
    root.history = list
    if (root.opened) root.rebuildDisplay()
  }

  Timer {
    id: saveDebounceTimer
    interval: 300
    repeat: false
    onTriggered: root.flushSaveHistory()
  }

  function saveHistory(immediate) {
    if (immediate === true) {
      saveDebounceTimer.stop()
      root.flushSaveHistory()
    } else {
      saveDebounceTimer.restart()
    }
  }

  function flushSaveHistory() {
    var limit = (root.settings && root.settings.maxHistoryEntries) || root.historyLimit
    historyFile.setText(JSON.stringify(root.history.slice(0, limit), null, 2) + "\n")
    root.sweepImages()
  }

  function addClipboardEntry(entry) {
    if (root.paused) return
    var normalized = ClipboardHistory.normalizeEntry(entry)
    if (!normalized) return

    var limit = (root.settings && root.settings.maxHistoryEntries) || root.historyLimit
    var maxBytes = ((root.settings && root.settings.maxTotalHistoryMB) || 1) * 1024 * 1024
    var maxImageBytes = ((root.settings && root.settings.maxImageStoreMB) || 32) * 1024 * 1024
    var retention = (root.settings && root.settings.retentionDays) || 0

    root.history = ClipboardHistory.addEntry(root.history, normalized, limit, maxBytes, maxImageBytes, retention)
    root.saveHistory()
    if (root.opened) root.rebuildDisplay()
  }

  function addClipboardJson(line) {
    root.addClipboardEntry(ClipboardHistory.parseEntryJson(line))
  }

  function requestClearHistory() {
    if (root.history.length === 0) return
    clearConfirm.selectedIndex = 1
    root.clearConfirmOpen = true
  }

  function cancelClearHistory() {
    root.clearConfirmOpen = false
    root.disarmPointer()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmClearHistory() {
    root.history = ClipboardHistory.clearHistory(root.history)
    root.saveHistory(true)
    root.selectedIndex = 0
    root.cursorActive = false
    root.disarmPointer()
    root.clearConfirmOpen = false
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function removeDisplayIndex(index) {
    if (index < 0 || index >= displayModel.count) return

    var row = displayModel.get(index)
    root.history = ClipboardHistory.removeEntryAt(root.history, row.historyIndex)
    root.saveHistory(true)

    if (displayModel.count <= 1) {
      root.selectedIndex = 0
      root.cursorActive = false
    } else if (root.selectedIndex >= displayModel.count - 1) {
      root.selectedIndex = displayModel.count - 2
    }

    root.disarmPointer()
    root.rebuildDisplay()
  }

  function toggleFavoriteIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.history = ClipboardHistory.toggleFavorite(root.history, row.historyIndex)
    root.saveHistory()
    root.rebuildDisplay()
  }

  function rebuildDisplay() {
    var rows = ClipboardHistory.displayRows(
      root.history,
      root.filterText,
      50,
      root.favoritesOnly,
      root.activeTypeFilter,
      root.activeTagFilter,
      Classify,
      Fuzzy,
      Sanitize
    )

    displayModel.clear()
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      var isRevealed = root.revealedItems[row.index] === true
      var isMasked = row.sensitive && (!root.settings || root.settings.maskSensitiveText !== false) && !isRevealed
      displayModel.append({
        entryType: row.entryType,
        fullText: row.fullText,
        previewText: isMasked ? row.maskedPreview : row.previewText,
        previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
        path: row.path,
        mime: row.mime,
        favorite: row.favorite,
        truncated: row.truncated,
        sensitive: row.sensitive,
        sensitiveType: row.sensitiveType,
        revealed: isRevealed,
        tags: row.tags ? row.tags.slice() : [],
        historyIndex: row.index
      })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.applySelected(row)
  }

  function copyIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.copySelected(row)
  }

  function openIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.openSelected(row)
  }

  function applySelected(row) {
    if (!row) return
    root.opened = false
    if (row.entryType === "image") {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-file", row.mime, row.path])
    } else if (row.fullText) {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-text", "--shift-insert", "--history-index", String(row.historyIndex)])
    }
  }

  function copySelected(row) {
    if (!row) return
    root.opened = false
    if (row.entryType === "image") {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-file", "--copy-only", row.mime, row.path])
    } else if (row.fullText) {
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-paste-text", "--copy-only", "--history-index", String(row.historyIndex)])
    }
  }

  function openSelected(row) {
    if (!row) return
    root.opened = false
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-clipboard-open", "--history-index", String(row.historyIndex)])
  }

  Component.onCompleted: initProc.running = true

  ListModel { id: displayModel }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("{}")
    onFileChanged: reload()
  }

  Process {
    id: backupCorruptProc
    command: ["sh", "-c", 'if [ -f "$1" ]; then cp "$1" "$1.bak-$(date +%s)"; fi', "backup", root.historyPath]
  }

  Process {
    id: sweepImagesProc
    command: ["sh", "-c", '
      STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
      IMG_DIR="$STATE_DIR/clipboard-images"
      HIST="$STATE_DIR/clipboard-history.json"
      [ -d "$IMG_DIR" ] && [ -f "$HIST" ] || exit 0
      ref=$(jq -r \'.[] | select(.type=="image" and .path!=null) | .path\' "$HIST" 2>/dev/null | sort -u)
      for f in "$IMG_DIR"/*; do
        [ -f "$f" ] || continue
        if ! echo "$ref" | grep -Fqx "$f"; then
          rm -f "$f"
        fi
      done
    ']
  }

  function sweepImages() {
    if (!sweepImagesProc.running) sweepImagesProc.running = true
  }

  // Reap watchers left behind by a previous shell instance, then start our
  // own. The pdeathsig on the watchers makes the kernel kill them whenever
  // the shell exits, however it exits, so no further lifecycle management.
  Process {
    id: initProc
    command: ["sh", "-c", "mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/clipboard-images\" \"${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/mrshirini.clipboard\"; pkill -f 'wl-paste .*--watch .*capture\\.sh' || true"]
    onExited: {
      currentProc.running = true
      textWatchProc.running = true
      imageWatchProc.running = true
    }
  }

  Process {
    id: currentProc
    command: [root.captureScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.addClipboardJson(text)
    }
  }

  Process {
    id: textWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  Process {
    id: imageWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  // A watcher that dies takes clipboard history with it, silently: copying still
  // works, the picker still opens, and the old entries are all still there, so
  // nothing recorded until the next shell reload. Bring it back instead.
  Timer {
    id: watchRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!textWatchProc.running) textWatchProc.running = true
      if (!imageWatchProc.running) imageWatchProc.running = true
    }
  }

  PanelWindow {
    id: panel
    screen: root.currentScreen
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      x: {
        var ox = (root.settings && root.settings.customOffset && root.settings.customOffset.x) || 0
        var pos = (root.settings && root.settings.position) || "top-right"
        var targetX
        if (pos === "top-left") {
          targetX = Style.gapsOut + ox
        } else if (pos === "top-center" || pos === "center") {
          targetX = Math.round((parent.width - width) / 2) + ox
        } else {
          targetX = parent.width - width - Style.gapsOut + ox
        }
        return Math.max(0, Math.min(targetX, Math.max(0, parent.width - width)))
      }
      y: {
        var oy = (root.settings && root.settings.customOffset && root.settings.customOffset.y) || 0
        var pos = (root.settings && root.settings.position) || "top-right"
        var targetY
        if (pos === "center") {
          targetY = Math.round((parent.height - height) / 2) + oy
        } else {
          targetY = Style.bar.sizeHorizontal + Style.gapsOut + oy
        }
        return Math.max(0, Math.min(targetY, Math.max(0, parent.height - height)))
      }
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.clearConfirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.clearConfirmOpen) {
            if (clearConfirm.handleKey(event)) event.accepted = true
            return
          }

          if (root.settingsOpen) {
            if (event.key === Qt.Key_Escape) {
              root.settingsOpen = false
              event.accepted = true
            } else if (((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Comma)
                       || (root.settings && root.settings.shortcuts && Settings.matchesShortcut(event, root.settings.shortcuts.openSettings, Qt))) {
              root.settingsOpen = false
              event.accepted = true
            } else if (((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_P)
                       || (root.settings && root.settings.shortcuts && Settings.matchesShortcut(event, root.settings.shortcuts.togglePause, Qt))) {
              root.togglePause()
              event.accepted = true
            }
            return
          }

          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.close()
            event.accepted = true
          } else if (((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Comma)
                     || (root.settings && root.settings.shortcuts && Settings.matchesShortcut(event, root.settings.shortcuts.openSettings, Qt))) {
            root.settingsOpen = true
            event.accepted = true
          } else if (((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_P)
                     || (root.settings && root.settings.shortcuts && Settings.matchesShortcut(event, root.settings.shortcuts.togglePause, Qt))) {
            root.togglePause()
            event.accepted = true
          } else if (((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_F || event.key === Qt.Key_S))
                     || ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_D || event.key === Qt.Key_S))
                     || (root.settings && root.settings.shortcuts && Settings.matchesShortcut(event, root.settings.shortcuts.favorite, Qt))) {
            if (root.cursorActive && displayModel.count > 0) {
              root.toggleFavoriteIndex(root.selectedIndex)
            }
            event.accepted = true
          } else if ((event.modifiers & Qt.ControlModifier) && (event.key >= Qt.Key_1 && event.key <= Qt.Key_7)) {
            var filterIds = ["all", "text", "link", "code", "image", "file", "color"]
            var targetIdx = event.key - Qt.Key_1
            if (targetIdx >= 0 && targetIdx < filterIds.length) {
              root.activeTypeFilter = filterIds[targetIdx]
              root.selectedIndex = 0
              root.rebuildDisplay()
              event.accepted = true
            }
          } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab
                     || (root.settings && root.settings.shortcuts && Settings.matchesShortcut(event, root.settings.shortcuts.toggleFavoritesView, Qt))) {
            root.favoritesOnly = !root.favoritesOnly
            root.selectedIndex = 0
            root.rebuildDisplay()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            if (event.modifiers & Qt.ShiftModifier) root.requestClearHistory()
            else root.removeDisplayIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectAbsolute(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectAbsolute(displayModel.count - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive && (event.modifiers & Qt.AltModifier)) root.openIndex(root.selectedIndex)
            else if (root.cursorActive && (event.modifiers & Qt.ShiftModifier)) root.copyIndex(root.selectedIndex)
            else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: clearConfirm

          anchors.fill: parent
          opened: root.clearConfirmOpen
          z: 10
          message: "Clear history? (Starred items will be kept)"
          confirmText: "Clear"
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelClearHistory()
          onConfirmed: root.confirmClearHistory()
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Row {
          width: parent.width
          height: root.headerHeight
          spacing: Style.space(8)

          Item {
            width: parent.width - favFilterBtn.width - pauseBtn.width - settingsBtn.width - parent.spacing * (root.settingsOpen ? 1 : 3)
            height: parent.height

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.settingsOpen
                ? "Settings & Preferences"
                : (root.filterText || (root.favoritesOnly ? "Search favorites…" : "Search clipboard…"))
              color: root.foreground
              opacity: (root.settingsOpen || root.filterText) ? 1 : 0.58
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: root.settingsOpen
              elide: Text.ElideRight
            }
          }

          Rectangle {
            id: pauseBtn
            visible: !root.settingsOpen
            width: visible ? (pauseRow.implicitWidth + Style.space(16)) : 0
            height: parent.height
            radius: root.cornerRadius
            color: root.paused
              ? Util.alpha(Color.accent, 0.2)
              : (pauseMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
            border.color: root.paused
              ? Color.accent
              : (pauseMouse.containsMouse ? Util.alpha(root.foreground, 0.3) : Util.alpha(root.border, 0.25))
            border.width: 1

            Row {
              id: pauseRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                text: root.paused ? "󰐊" : "󰏤"
                color: root.paused ? Color.accent : (pauseMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                text: root.paused ? "Resume" : "Pause"
                color: root.paused ? Color.accent : (pauseMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.paused
                verticalAlignment: Text.AlignVCenter
              }
            }

            MouseArea {
              id: pauseMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.togglePause()
                keyCatcher.forceActiveFocus()
              }
            }
          }

          Rectangle {
            id: favFilterBtn
            visible: !root.settingsOpen
            width: visible ? (favFilterRow.implicitWidth + Style.space(16)) : 0
            height: parent.height
            radius: root.cornerRadius
            color: root.favoritesOnly ? root.selectedBackground : (favFilterMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
            border.color: root.favoritesOnly ? root.selectedText : (favFilterMouse.containsMouse ? Util.alpha(root.foreground, 0.3) : Util.alpha(root.border, 0.25))
            border.width: 1

            Row {
              id: favFilterRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                text: "★"
                color: root.favoritesOnly ? Color.accent : (favFilterMouse.containsMouse ? Util.alpha(Color.accent, 0.85) : Util.alpha(root.foreground, 0.5))
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                text: "Favorites"
                color: root.favoritesOnly ? root.selectedText : (favFilterMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.favoritesOnly
                verticalAlignment: Text.AlignVCenter
              }
            }

            MouseArea {
              id: favFilterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.favoritesOnly = !root.favoritesOnly
                root.selectedIndex = 0
                root.rebuildDisplay()
                keyCatcher.forceActiveFocus()
              }
            }
          }

          Rectangle {
            id: settingsBtn
            width: settingsRow.implicitWidth + Style.space(16)
            height: parent.height
            radius: root.cornerRadius
            color: root.settingsOpen ? root.selectedBackground : (settingsMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
            border.color: root.settingsOpen ? Color.accent : (settingsMouse.containsMouse ? Util.alpha(root.foreground, 0.3) : Util.alpha(root.border, 0.25))
            border.width: 1

            Row {
              id: settingsRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                text: root.settingsOpen ? "✓" : "⚙"
                color: root.settingsOpen ? (root.selectedText || Color.accent) : (settingsMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                text: root.settingsOpen ? "Done" : "Settings"
                color: root.settingsOpen ? (root.selectedText || Color.accent) : (settingsMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.settingsOpen
                verticalAlignment: Text.AlignVCenter
              }
            }

            MouseArea {
              id: settingsMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.settingsOpen = !root.settingsOpen
                keyCatcher.forceActiveFocus()
              }
            }
          }
        }

        Rectangle {
          visible: root.paused && !root.settingsOpen
          width: parent.width
          height: visible ? Style.space(28) : 0
          radius: Style.space(4)
          color: Util.alpha(Color.accent, 0.15)
          border.color: Util.alpha(Color.accent, 0.4)
          border.width: 1

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              text: "󰏤 History paused (Incognito active) — New copies will not be saved."
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
              height: Style.space(20)
              width: resumeBannerRow.implicitWidth + Style.space(12)
              radius: Style.space(3)
              color: resumeMouse.containsMouse ? Color.accent : Util.alpha(Color.accent, 0.25)

              Row {
                id: resumeBannerRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  text: "󰐊"
                  color: resumeMouse.containsMouse ? root.background : Color.accent
                  font.pixelSize: Style.font.caption - Style.space(1)
                  verticalAlignment: Text.AlignVCenter
                }

                Text {
                  id: resumeText
                  text: "Resume"
                  color: resumeMouse.containsMouse ? root.background : Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - Style.space(1)
                  font.bold: true
                  verticalAlignment: Text.AlignVCenter
                }
              }

              MouseArea {
                id: resumeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.setPaused(false)
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }
        }

        Row {
          visible: !root.settingsOpen
          width: parent.width
          height: visible ? Style.space(24) : 0
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "all", label: "All" },
              { id: "text", label: "Text" },
              { id: "link", label: "Links" },
              { id: "code", label: "Code" },
              { id: "image", label: "Images" },
              { id: "file", label: "Files" },
              { id: "color", label: "Colors" }
            ]

            Rectangle {
              required property var modelData
              readonly property bool isSelected: root.activeTypeFilter === modelData.id
              height: parent.height
              width: chipText.implicitWidth + Style.space(16)
              radius: root.cornerRadius
              color: isSelected ? root.selectedBackground : (chipMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
              border.color: isSelected ? Color.accent : (chipMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
              border.width: 1

              Text {
                id: chipText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? (root.selectedText || Color.accent) : (chipMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.65))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: isSelected
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.activeTypeFilter = modelData.id
                  root.selectedIndex = 0
                  root.rebuildDisplay()
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }
        }

        Row {
          visible: root.favoritesOnly && !root.settingsOpen
          width: parent.width
          height: visible ? Style.space(24) : 0
          spacing: Style.space(6)

          Repeater {
            model: {
              if (!root.favoritesOnly) return []
              var defaults = (root.settings && root.settings.defaultTagSet) ? root.settings.defaultTagSet.slice() : ["Code", "Links", "Tokens", "Todo"]
              var allTags = ClipboardHistory.getAllTags(root.history)
              var list = ["all"]
              for (var i = 0; i < defaults.length; i++) {
                var d = defaults[i].toLowerCase()
                if (list.indexOf(d) < 0) list.push(d)
              }
              for (var j = 0; j < allTags.length; j++) {
                var t = allTags[j].toLowerCase()
                if (list.indexOf(t) < 0) list.push(t)
              }
              return list
            }

            Rectangle {
              required property var modelData
              readonly property bool isSelected: root.activeTagFilter === modelData
              height: parent.height
              width: tagChipText.implicitWidth + Style.space(16)
              radius: root.cornerRadius
              color: isSelected ? root.selectedBackground : (tagChipMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
              border.color: isSelected ? Color.accent : (tagChipMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
              border.width: 1

              Text {
                id: tagChipText
                anchors.centerIn: parent
                text: modelData === "all" ? "All Tags" : ("#" + modelData)
                color: isSelected ? (root.selectedText || Color.accent) : (tagChipMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.65))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: isSelected
              }

              MouseArea {
                id: tagChipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.activeTagFilter = modelData
                  root.selectedIndex = 0
                  root.rebuildDisplay()
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }
        }

        Item {
          visible: !root.settingsOpen
          width: parent.width
          height: visible ? (parent.height - root.headerHeight - Style.space(24) - (root.favoritesOnly ? Style.space(24) + root.contentSpacing : 0) - (root.paused ? Style.space(28) + root.contentSpacing : 0) - root.contentSpacing * 2) : 0

          Row {
            anchors.fill: parent
            spacing: 0

            Item {
              width: parent.width / 2
              height: parent.height
              clip: true

              ListView {
                id: resultList
                anchors.fill: parent
                anchors.rightMargin: root.contentMargin
                model: displayModel
                clip: true
                reuseItems: true
                cacheBuffer: root.rowHeight * 8
                spacing: Style.space(4)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  id: row
                  required property int index
                  required property string entryType
                  required property string previewText
                  required property string fullText
                  required property string previewImage
                  required property bool favorite
                  required property bool truncated
                  required property bool sensitive
                  required property string sensitiveType
                  required property bool revealed
                  required property var tags
                  required property int historyIndex

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: hasCursor ? root.selectedBackground : "transparent"

                  Row {
                    anchors.left: parent.left
                    anchors.right: starBtn.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(6)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    spacing: Style.space(10)

                    Image {
                      visible: row.previewImage.length > 0
                      width: visible ? parent.height : 0
                      height: parent.height
                      source: row.previewImage
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      smooth: true
                    }

                    Rectangle {
                      visible: row.entryType === "color"
                      width: visible ? parent.height : 0
                      height: parent.height
                      radius: Style.space(4)
                      color: row.entryType === "color" ? row.fullText : "transparent"
                      border.width: 1
                      border.color: Util.alpha(root.foreground, 0.3)
                    }

                    Rectangle {
                      visible: row.sensitive
                      z: 2
                      width: sensitiveLabel.implicitWidth + Style.space(12)
                      height: Style.space(20)
                      radius: Style.space(4)
                      anchors.verticalCenter: parent.verticalCenter
                      color: Util.alpha(Color.accent, 0.15)
                      border.color: Util.alpha(Color.accent, 0.4)
                      border.width: 1

                      Text {
                        id: sensitiveLabel
                        anchors.centerIn: parent
                        text: row.revealed ? "🔓 Secret" : "🔒 " + (row.sensitiveType || "Secret")
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - Style.space(1)
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleReveal(row.historyIndex)
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - (row.previewImage.length > 0 ? parent.height + parent.spacing : (row.entryType === "color" ? parent.height + parent.spacing : 0)) - (row.sensitive ? sensitiveLabel.implicitWidth + Style.space(12) + parent.spacing : 0)
                      height: parent.height
                      text: row.previewText + (row.truncated ? " [64KB capped]" : "")
                      color: row.hasCursor ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      opacity: row.entryType === "image" || row.entryType === "file" ? 0.72 : 1.0
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  Item {
                    id: starBtn
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(28)
                    height: Style.space(28)
                    z: 2

                    Text {
                      anchors.centerIn: parent
                      text: row.favorite ? "★" : (starMouse.containsMouse ? "★" : "☆")
                      color: row.favorite ? Color.accent : (starMouse.containsMouse ? Util.alpha(Color.accent, 0.85) : (row.hasCursor ? Util.alpha(root.selectedText, 0.45) : Util.alpha(root.foreground, 0.3)))
                      font.pixelSize: Style.font.heading
                    }

                    MouseArea {
                      id: starMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.toggleFavoriteIndex(row.index)
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 1
                    onPositionChanged: function(mouse) {
                      root.selectFromPointer(row.index, row, mouse)
                    }
                    onClicked: function(mouse) {
                      root.cursorActive = true
                      root.selectedIndex = row.index
                      if (mouse && (mouse.modifiers & Qt.AltModifier)) {
                        root.openIndex(row.index)
                      } else if (root.settings && root.settings.pasteOnClick) {
                        if (mouse && (mouse.modifiers & Qt.ShiftModifier)) {
                          root.copyIndex(row.index)
                        } else {
                          root.activateIndex(row.index)
                        }
                      } else {
                        root.copyIndex(row.index)
                      }
                    }
                  }
                }
              }
            }

            Item {
              width: parent.width / 2
              height: parent.height
              clip: true

              property var activeRow: displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count ? displayModel.get(root.selectedIndex) : null

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Style.normalBorderWidth
                color: Util.alpha(root.border, 0.28)
              }

              Text {
                textFormat: Text.PlainText
                visible: parent.activeRow && !parent.activeRow.previewImage
                anchors.fill: parent
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: 0
                anchors.topMargin: 0
                anchors.bottomMargin: (parent.activeRow && parent.activeRow.favorite) ? Style.space(32) : 0
                text: {
                  if (!parent.activeRow) return ""
                  if (parent.activeRow.sensitive && !parent.activeRow.revealed && (!root.settings || root.settings.maskSensitiveText !== false)) {
                    return "[🔒 " + (parent.activeRow.sensitiveType || "Secret") + " - Masked for privacy]\n\n" + Sanitize.maskText(parent.activeRow.fullText)
                  }
                  return parent.activeRow.fullText
                }
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                verticalAlignment: Text.AlignTop
              }

              Image {
                visible: parent.activeRow && parent.activeRow.previewImage
                anchors.fill: parent
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: 0
                anchors.topMargin: 0
                anchors.bottomMargin: (parent.activeRow && parent.activeRow.favorite) ? Style.space(32) : 0
                source: parent.activeRow ? parent.activeRow.previewImage : ""
                fillMode: Image.PreserveAspectFit
                verticalAlignment: Image.AlignTop
                asynchronous: true
                smooth: true
              }

              Row {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: root.contentMargin
                anchors.right: parent.right
                height: Style.space(24)
                spacing: Style.space(6)
                visible: parent.activeRow && parent.activeRow.favorite

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Tags:"
                  color: Util.alpha(root.foreground, 0.5)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Repeater {
                  model: (root.settings && root.settings.defaultTagSet) ? root.settings.defaultTagSet : ["Code", "Links", "Tokens", "Todo"]

                  Rectangle {
                    required property var modelData
                    readonly property bool hasTag: {
                      var rowTags = parent.parent.activeRow ? parent.parent.activeRow.tags : []
                      if (!rowTags) return false
                      for (var k = 0; k < rowTags.length; k++) {
                        if (String(rowTags[k]).toLowerCase() === String(modelData).toLowerCase()) return true
                      }
                      return false
                    }
                    height: parent.height
                    width: previewTagText.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: hasTag ? root.selectedBackground : (previewTagMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: hasTag ? Color.accent : (previewTagMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.25))
                    border.width: 1

                    Text {
                      id: previewTagText
                      anchors.centerIn: parent
                      text: "#" + modelData
                      color: hasTag ? Color.accent : (previewTagMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.7))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: hasTag
                    }

                    MouseArea {
                      id: previewTagMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.toggleTagOnIndex(root.selectedIndex, modelData)
                      }
                    }
                  }
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0

            Text {
              text: "󰅌"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.history.length === 0 ? "Clipboard is empty" : (root.favoritesOnly ? "No favorite items yet" : (root.activeTypeFilter !== "all" ? "No items of type “" + root.activeTypeFilter + "”" : "No matches for “" + root.filterText + "”"))
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }

        Flickable {
          id: settingsPanel
          visible: root.settingsOpen
          width: parent.width
          height: visible ? (parent.height - root.headerHeight - root.contentSpacing) : 0
          contentWidth: width
          contentHeight: settingsColumn.implicitHeight + Style.space(24)
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: settingsColumn
            width: parent.width
            spacing: Style.space(16)

            // 1. Overlay Window Size & Dimensions
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Overlay Window Size"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Select a preset size or adjust width and height to fit your screen."
                color: Util.alpha(root.foreground, 0.65)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: [
                    { id: "compact", label: "Compact (600×420)", w: 600, h: 420 },
                    { id: "medium", label: "Medium (720×520)", w: 720, h: 520 },
                    { id: "large", label: "Large (880×620)", w: 880, h: 620 },
                    { id: "expanded", label: "Expanded (1040×720)", w: 1040, h: 720 }
                  ]

                  Rectangle {
                    required property var modelData
                    readonly property bool isSelected: (root.settings && root.settings.windowWidth === modelData.w && root.settings.windowHeight === modelData.h)
                    height: Style.space(26)
                    width: sizeChipText.implicitWidth + Style.space(16)
                    radius: root.cornerRadius
                    color: isSelected ? root.selectedBackground : (sizeChipMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: isSelected ? Color.accent : (sizeChipMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
                    border.width: 1

                    Text {
                      id: sizeChipText
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? (root.selectedText || Color.accent) : (sizeChipMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: sizeChipMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.updateSettings({
                          windowSize: modelData.id,
                          windowWidth: modelData.w,
                          windowHeight: modelData.h
                        })
                      }
                    }
                  }
                }
              }

              Row {
                spacing: Style.space(16)

                // Width adjuster
                Row {
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Width: " + ((root.settings && root.settings.windowWidth) || 720) + "px"
                    color: Util.alpha(root.foreground, 0.85)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Rectangle {
                    height: Style.space(24)
                    width: Style.space(26)
                    radius: root.cornerRadius
                    color: wMinusMouse.containsMouse ? Util.alpha(root.foreground, 0.12) : Util.alpha(root.foreground, 0.05)
                    border.color: Util.alpha(root.border, 0.25)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "−"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.bold: true
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: wMinusMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var curW = (root.settings && root.settings.windowWidth) || 720
                        root.updateSettings({
                          windowSize: "custom",
                          windowWidth: Math.max(480, curW - 40)
                        })
                      }
                    }
                  }

                  Rectangle {
                    height: Style.space(24)
                    width: Style.space(26)
                    radius: root.cornerRadius
                    color: wPlusMouse.containsMouse ? Util.alpha(root.foreground, 0.12) : Util.alpha(root.foreground, 0.05)
                    border.color: Util.alpha(root.border, 0.25)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "+"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.bold: true
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: wPlusMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var curW = (root.settings && root.settings.windowWidth) || 720
                        root.updateSettings({
                          windowSize: "custom",
                          windowWidth: Math.min(1600, curW + 40)
                        })
                      }
                    }
                  }
                }

                // Height adjuster
                Row {
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Height: " + ((root.settings && root.settings.windowHeight) || 520) + "px"
                    color: Util.alpha(root.foreground, 0.85)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Rectangle {
                    height: Style.space(24)
                    width: Style.space(26)
                    radius: root.cornerRadius
                    color: hMinusMouse.containsMouse ? Util.alpha(root.foreground, 0.12) : Util.alpha(root.foreground, 0.05)
                    border.color: Util.alpha(root.border, 0.25)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "−"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.bold: true
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: hMinusMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var curH = (root.settings && root.settings.windowHeight) || 520
                        root.updateSettings({
                          windowSize: "custom",
                          windowHeight: Math.max(340, curH - 40)
                        })
                      }
                    }
                  }

                  Rectangle {
                    height: Style.space(24)
                    width: Style.space(26)
                    radius: root.cornerRadius
                    color: hPlusMouse.containsMouse ? Util.alpha(root.foreground, 0.12) : Util.alpha(root.foreground, 0.05)
                    border.color: Util.alpha(root.border, 0.25)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "+"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.bold: true
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: hPlusMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var curH = (root.settings && root.settings.windowHeight) || 520
                        root.updateSettings({
                          windowSize: "custom",
                          windowHeight: Math.min(1200, curH + 40)
                        })
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.border, 0.15)
            }

            // 2. Maximum Savings / History Capacity
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Maximum Saved Entries (History Capacity)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Maximum number of clipboard history items to keep on disk. Oldest unstarred entries are evicted first."
                color: Util.alpha(root.foreground, 0.65)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: [
                    { val: 50, label: "50 entries" },
                    { val: 100, label: "100 entries" },
                    { val: 300, label: "300 (Default)" },
                    { val: 500, label: "500 entries" },
                    { val: 1000, label: "1000 entries" }
                  ]

                  Rectangle {
                    required property var modelData
                    readonly property bool isSelected: (root.settings.maxHistoryEntries || 300) === modelData.val
                    height: Style.space(26)
                    width: maxEntriesText.implicitWidth + Style.space(16)
                    radius: root.cornerRadius
                    color: isSelected ? root.selectedBackground : (maxEntriesMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: isSelected ? Color.accent : (maxEntriesMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
                    border.width: 1

                    Text {
                      id: maxEntriesText
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? (root.selectedText || Color.accent) : (maxEntriesMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: maxEntriesMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateSetting("maxHistoryEntries", modelData.val)
                    }
                  }
                }
              }

              Text {
                text: "Total History Store Size Cap"
                color: Util.alpha(root.foreground, 0.8)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: [
                    { val: 1, label: "1 MB (Default)" },
                    { val: 2, label: "2 MB" },
                    { val: 5, label: "5 MB" },
                    { val: 10, label: "10 MB" }
                  ]

                  Rectangle {
                    required property var modelData
                    readonly property bool isSelected: (root.settings.maxTotalHistoryMB || 1) === modelData.val
                    height: Style.space(26)
                    width: maxMBText.implicitWidth + Style.space(16)
                    radius: root.cornerRadius
                    color: isSelected ? root.selectedBackground : (maxMBMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: isSelected ? Color.accent : (maxMBMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
                    border.width: 1

                    Text {
                      id: maxMBText
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? (root.selectedText || Color.accent) : (maxMBMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: maxMBMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateSetting("maxTotalHistoryMB", modelData.val)
                    }
                  }
                }
              }

              Text {
                text: "Image Cache Disk Cap"
                color: Util.alpha(root.foreground, 0.8)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: [
                    { val: 16, label: "16 MB" },
                    { val: 32, label: "32 MB (Default)" },
                    { val: 64, label: "64 MB" },
                    { val: 128, label: "128 MB" }
                  ]

                  Rectangle {
                    required property var modelData
                    readonly property bool isSelected: (root.settings.maxImageStoreMB || 32) === modelData.val
                    height: Style.space(26)
                    width: maxImgText.implicitWidth + Style.space(16)
                    radius: root.cornerRadius
                    color: isSelected ? root.selectedBackground : (maxImgMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: isSelected ? Color.accent : (maxImgMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
                    border.width: 1

                    Text {
                      id: maxImgText
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? (root.selectedText || Color.accent) : (maxImgMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: maxImgMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateSetting("maxImageStoreMB", modelData.val)
                    }
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.border, 0.15)
            }

            // 2. Retention & Auto-Purge Policy
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Auto-Purge & Retention Policy"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Automatically delete unstarred items older than a set time. Starred (★) favorites are permanently protected."
                color: Util.alpha(root.foreground, 0.65)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: [
                    { val: 0, label: "Keep Forever (Default)" },
                    { val: 1, label: "24 Hours" },
                    { val: 7, label: "7 Days" },
                    { val: 14, label: "14 Days" },
                    { val: 30, label: "30 Days" },
                    { val: 90, label: "90 Days" }
                  ]

                  Rectangle {
                    required property var modelData
                    readonly property bool isSelected: (root.settings.retentionDays || 0) === modelData.val
                    height: Style.space(26)
                    width: retentionText.implicitWidth + Style.space(16)
                    radius: root.cornerRadius
                    color: isSelected ? root.selectedBackground : (retentionMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: isSelected ? Color.accent : (retentionMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
                    border.width: 1

                    Text {
                      id: retentionText
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? (root.selectedText || Color.accent) : (retentionMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: retentionMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateSetting("retentionDays", modelData.val)
                    }
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.border, 0.15)
            }

            // 3. Sensitive Data Masking
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Sensitive Data Privacy Masking"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Automatically detect and mask API keys, JWT tokens, and passwords in the list view (e.g. sk-••••••1234)."
                color: Util.alpha(root.foreground, 0.65)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                spacing: Style.space(6)

                Rectangle {
                  readonly property bool isMasking: root.settings.maskSensitiveText !== false
                  height: Style.space(26)
                  width: maskOnText.implicitWidth + Style.space(16)
                  radius: root.cornerRadius
                  color: isMasking ? root.selectedBackground : (maskOnMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                  border.color: isMasking ? Color.accent : Util.alpha(root.border, 0.2)
                  border.width: 1

                  Text {
                    id: maskOnText
                    anchors.centerIn: parent
                    text: "🔒 Mask Secrets (Enabled)"
                    color: parent.isMasking ? (root.selectedText || Color.accent) : Util.alpha(root.foreground, 0.75)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: parent.isMasking
                  }

                  MouseArea {
                    id: maskOnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updateSetting("maskSensitiveText", true)
                  }
                }

                Rectangle {
                  readonly property bool isMasking: root.settings.maskSensitiveText !== false
                  height: Style.space(26)
                  width: maskOffText.implicitWidth + Style.space(16)
                  radius: root.cornerRadius
                  color: !isMasking ? root.selectedBackground : (maskOffMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                  border.color: !isMasking ? Color.accent : Util.alpha(root.border, 0.2)
                  border.width: 1

                  Text {
                    id: maskOffText
                    anchors.centerIn: parent
                    text: "🔓 Show Plainly (Disabled)"
                    color: !parent.isMasking ? (root.selectedText || Color.accent) : Util.alpha(root.foreground, 0.75)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: !parent.isMasking
                  }

                  MouseArea {
                    id: maskOffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updateSetting("maskSensitiveText", false)
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.border, 0.15)
            }

            // 4. Paste on Click
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Click Behavior"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Choose whether clicking an item only copies it to clipboard or immediately pastes it into the active application."
                color: Util.alpha(root.foreground, 0.65)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                spacing: Style.space(6)

                Rectangle {
                  readonly property bool isPasteOnClick: Boolean(root.settings.pasteOnClick)
                  height: Style.space(26)
                  width: copyOnlyText.implicitWidth + Style.space(16)
                  radius: root.cornerRadius
                  color: !isPasteOnClick ? root.selectedBackground : (copyOnlyMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                  border.color: !isPasteOnClick ? Color.accent : Util.alpha(root.border, 0.2)
                  border.width: 1

                  Text {
                    id: copyOnlyText
                    anchors.centerIn: parent
                    text: "Copy to Clipboard Only (Default)"
                    color: !parent.isPasteOnClick ? (root.selectedText || Color.accent) : Util.alpha(root.foreground, 0.75)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: !parent.isPasteOnClick
                  }

                  MouseArea {
                    id: copyOnlyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updateSetting("pasteOnClick", false)
                  }
                }

                Rectangle {
                  readonly property bool isPasteOnClick: Boolean(root.settings.pasteOnClick)
                  height: Style.space(26)
                  width: autoPasteText.implicitWidth + Style.space(16)
                  radius: root.cornerRadius
                  color: isPasteOnClick ? root.selectedBackground : (autoPasteMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                  border.color: isPasteOnClick ? Color.accent : Util.alpha(root.border, 0.2)
                  border.width: 1

                  Text {
                    id: autoPasteText
                    anchors.centerIn: parent
                    text: "Automatically Paste on Click"
                    color: parent.isPasteOnClick ? (root.selectedText || Color.accent) : Util.alpha(root.foreground, 0.75)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: parent.isPasteOnClick
                  }

                  MouseArea {
                    id: autoPasteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.updateSetting("pasteOnClick", true)
                  }
                }
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.border, 0.15)
            }

            // 6. Placement
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                text: "Overlay Placement"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Position on screen where the clipboard overlay is summoned."
                color: Util.alpha(root.foreground, 0.65)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                spacing: Style.space(6)
                Repeater {
                  model: [
                    { id: "top-right", label: "Top-Right (Default)" },
                    { id: "top-center", label: "Top-Center" },
                    { id: "top-left", label: "Top-Left" },
                    { id: "center", label: "Center" }
                  ]

                  Rectangle {
                    required property var modelData
                    readonly property bool isSelected: (root.settings.position || "top-right") === modelData.id
                    height: Style.space(26)
                    width: posText.implicitWidth + Style.space(16)
                    radius: root.cornerRadius
                    color: isSelected ? root.selectedBackground : (posMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")
                    border.color: isSelected ? Color.accent : (posMouse.containsMouse ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.border, 0.2))
                    border.width: 1

                    Text {
                      id: posText
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? (root.selectedText || Color.accent) : (posMouse.containsMouse ? root.foreground : Util.alpha(root.foreground, 0.75))
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: posMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateSetting("position", modelData.id)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
