import AlgWidgets.Style 1.0
import QtQuick 2.7
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4

Button {
  id: root
  height: 30
  width: 30
  tooltip: "Send all materials to Integration"

  property string clientName: ""

  style: ButtonStyle {
    background: Rectangle {
        color: (root.enabled && hovered)? AlgStyle.background.color.gray : "#141414"
    }
    label: Item {
      Image {
        height: parent.height
        antialiasing: true
        fillMode:Image.PreserveAspectFit
        source: enabled ? (clientName == "Unreal4" ? "icons/ue4_connected.png" : "icons/unity_connected.png") : "icons/no_connection.png"
        opacity: root.enabled? (hovered? 0.9 : 0.7) : 0.4
      }
    }
  }
}
