import Painter 1.0
import QtQuick 2.7
import QtWebSockets 1.0

Item {
  id: root

  property alias host : server.host
  property alias listen: server.listen
  property alias port: server.port
  property alias currentWebSocket: server.currentWebSocket
  readonly property bool connected: currentWebSocket !== null

  signal jsonMessageReceived(var command, var jsonData)

  property var _callbacks: null

  function registerCallback(command, callback) {
    if (_callbacks === null) {
      _callbacks = {};
    }
    _callbacks[command.toUpperCase()] = callback;
  }

  function sendCommand(command, data) {
    if (!connected) {
      alg.log.warn(qsTr("Can't send \"%1\" command as there is no client connected").arg(command));
      return;
    }
    try {
      server.currentWebSocket.sendTextMessage(command + " " + JSON.stringify(data));
    }
    catch(err) {
      alg.log.error(qsTr("Unexpected error while sending \"%1\" command: %2").arg(command).arg(err.message));
    }
  }

  WebSocketServer {
    id: server

    listen: true
    port: 6404
    property var currentWebSocket: null
    name: "Substance 3D Painter"
    accept: !root.connected // Ensure only one connection at a time

    onClientConnected: {
      currentWebSocket = webSocket;

      webSocket.statusChanged.connect(function onWSStatusChanged() {
          if (root && root.connected && (
                webSocket.status == WebSocket.Closed ||
                webSocket.status == WebSocket.Error))
          {
            server.currentWebSocket = null;
          }
          if (webSocket.status == WebSocket.Error) {
            alg.log.warn(qsTr("Command server connection error: %1").arg(webSocket.errorString));
          }
      });
      webSocket.onTextMessageReceived.connect(function onWSTxtMessageReceived(message) {
        // Try to retrieve command and json data
        var command, jsonData;
        try {
          var separator = message.indexOf(" ");
          var jsonString = message.substring(separator + 1, message.length);
          jsonData = JSON.parse(jsonString);
          command = message.substring(0, separator).toUpperCase();
        }
        catch(err) {
          alg.log.warn(qsTr("Command connection received badly formated message starting with: \"%1\"...: %2")
            .arg(message.substring(0, 30))
            .arg(err.message));
          return;
        }

        if (root._callbacks && command in root._callbacks) {
          try {
            root._callbacks[command](jsonData)
          }
          catch(err) {
            alg.log.warn(err.message);
          }
        }
        root.jsonMessageReceived(command, jsonData);
      })
    }

    onErrorStringChanged: {
      alg.log.warn(qsTr("Command server error: %1").arg(errorString));
    }
  }
}
