import AlgWidgets.Style 2.0
import AlgWidgets 2.0
import QtQuick 2.7

AlgToolBarButton {
  id: root
  tooltip: "Send all materials to Integration"
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

    visible: root.enabled
    color: root.enableAutoLink? "#2FB29C" : "#EF4E35"
  }

}
