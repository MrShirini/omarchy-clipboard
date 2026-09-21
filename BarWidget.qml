import Quickshell
import Quickshell.Io
import QtQuick
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "mrshirini.clipboard"

  property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy"
  property string pausedPath: stateDir + "/clipboard-paused"
  property bool isPaused: false

  FileView {
    id: pausedFile
    path: root.pausedPath
    watchChanges: true
    printErrors: false
    onLoaded: root.isPaused = true
    onLoadFailed: root.isPaused = false
    onFileChanged: reload()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.isPaused ? "󰏤" : "󰅌"
    slotSize: Style.bar.statusSlot
    tooltipText: root.isPaused
      ? "Clipboard (Paused / Incognito) • Left-click: Open, Right-click: Resume"
      : "Clipboard (Super+Ctrl+V) • Right-click: Pause"
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton || b === Qt.MiddleButton) {
        togglePauseProc.running = true
      } else {
        root.bar.run("omarchy-shell shell toggle mrshirini.clipboard")
      }
    }
  }

  Process {
    id: togglePauseProc
    command: ["sh", "-c", '
      F="' + root.pausedPath + '"
      if [ -f "$F" ]; then
        rm -f "$F"
      else
        mkdir -p "$(dirname "$F")"
        touch "$F"
      fi
    ']
  }
}

