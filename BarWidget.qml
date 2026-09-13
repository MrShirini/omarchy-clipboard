import QtQuick
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "mrshirini.clipboard"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅌"
    slotSize: Style.bar.statusSlot
    tooltipText: "Clipboard (Super+Ctrl+V)"
    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle mrshirini.clipboard")
    }
  }
}
