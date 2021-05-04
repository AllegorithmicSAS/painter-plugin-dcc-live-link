import AlgWidgets.Style 2.0
import AlgWidgets 2.0
import QtQuick 2.7

Item {
  id: root
  width: button.width
  height: button.height

  AlgToolBarButton {
    id: button
    enabled: false
    iconName: enabled ? (clientName == "Unreal4" ? "icons/Unreal_idle.svg" : "icons/Unity_idle.svg") : "icons/Livelink_idle.svg"

    property bool enableAutoLink: true

    property string clientName: ""

    Rectangle {
      id: autoLinkButton
      height: 5
      width: height
      x: 2
      y: 2

      radius: width

      visible: button.enabled
      color: button.enableAutoLink? "#2FB29C" : "#EF4E35"
    }
  }

  AlgToolTipArea {
    anchors.fill: root
    tooltip: button.enabled ? "Send all materials to Integration." : "Live Link is enabled when you send an asset from a game engine to Painter."
  }
}
