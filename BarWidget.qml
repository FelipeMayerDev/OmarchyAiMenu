import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "focky.ai-menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰚩"
    fontFamily: Style.font.family
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      var payload = button === Qt.RightButton ? "{\"settings\":true}" : "{}"
      root.bar.run("omarchy-shell shell toggle focky.ai-menu '" + payload + "'")
    }
  }
}
