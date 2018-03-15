import AlgWidgets.Style 1.0
import QtQuick 2.7
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4

Button {
  id: root
  antialiasing: true
  height: 32
  width: 32
  tooltip: "Send all materials to Integration"

  property bool enableAutoLink: true

  property string clientName: ""

  style: ButtonStyle {
    background: Rectangle {
        implicitWidth: root.width
        implicitHeight: root.height
        color: root.hovered ?
          "#262626" :
          "transparent"
    }
  }

  Image {
    anchors.fill: parent
    antialiasing: true
    anchors.margins: 8
    fillMode:Image.PreserveAspectFit
    source: enabled ? (clientName == "Unreal4" ? "icons/Unreal_idle.svg" : "icons/Unity_idle.svg") : "icons/Livelink_idle.svg"
    opacity: root.enabled ?
      1.0:
      0.3
    sourceSize.width: root.width
    sourceSize.height: root.height
  }

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
