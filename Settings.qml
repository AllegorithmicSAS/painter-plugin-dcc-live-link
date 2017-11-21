import AlgWidgets 1.0
import QtQuick 2.7
import QtQuick.Layouts 1.3
import Painter 1.0

AlgWindow {
  id: root

  title: "Live Link configuration"
  visible: false
  minimumWidth: 300
  maximumWidth: minimumWidth
  minimumHeight: 150
  maximumHeight: minimumHeight

  Component.onCompleted: {
    flags = flags | Qt.WindowStaysOnTopHint;
  }

  property int linkQuickInterval: 300 /*ms*/
  property int linkDegradedResolution: 1024
  property int linkHQTreshold: 2048
  property int linkHQInterval: 4000 /*ms*/
  property int initDelayOnProjectCreation: 5000 /*ms*/
  readonly property string settingsKeyPrefix: "live_link"

  GridLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: 10

    columns: 2

    function initSlider(component, linkedProperty) {
      var settingKey = "%1_%2".arg(root.settingsKeyPrefix).arg(linkedProperty);
      var defaultValue = alg.settings.contains(settingKey)?
        alg.settings.value(settingKey) : root[linkedProperty];

      // Bind slider value changed on setting value
      root[linkedProperty] = Qt.binding(function() {return component.value;});
      component.valueChanged.connect(function() {
        alg.settings.setValue(settingKey, component.value);
      });

      // Set default value
      component.value = defaultValue;
    }

    function initResolutionComboBox(component, linkedProperty, model) {
      var settingKey = "%1_%2".arg(root.settingsKeyPrefix).arg(linkedProperty);
      var defaultValue = alg.settings.contains(settingKey)?
        alg.settings.value(settingKey) : root[linkedProperty];

      // Bind combo box index changed on setting value
      component.currentIndexChanged.connect(function() {
        var resolution = model.get(component.currentIndex).resolution;
        root[linkedProperty] = resolution;
        alg.settings.setValue(settingKey, resolution);
      });

      // Fill model
      for (var resolution = component.minResolution; resolution <= component.maxResolution; resolution = resolution << 1) {
        model.append({
          text: resolution + " px",
          resolution: resolution
        });
      }

      // Set default resolution/index
      function log2(n) { return Math.log(n) / Math.log(2); }
      component.currentIndex = log2(defaultValue) - log2(component.minResolution);
    }

    AlgSlider {
      Layout.columnSpan: 2
      Layout.fillWidth:true
      precision: 0
      stepSize: 1000
      minValue: 1000
      maxValue: 10000
      text: "Delay on project creation (ms)"
      Component.onCompleted: parent.initSlider(this, "initDelayOnProjectCreation");
    }

    AlgSlider {
      Layout.columnSpan: 2
      Layout.fillWidth:true
      precision: 0
      stepSize: 50
      minValue: 50
      maxValue: 2000
      text: "Standard maps transfer delay (ms)"
      Component.onCompleted: parent.initSlider(this, "linkQuickInterval");
    }

    AlgLabel {text: "Degraded preview treshold"}
    AlgComboBox {
      Layout.fillWidth: true
      property int minResolution: 1024
      property int maxResolution: 4096
      textRole: "text"
      Component.onCompleted: parent.initResolutionComboBox(this, "linkHQTreshold", model);
      model: ListModel {}
    }

    AlgLabel {text: "Degraded preview resolution"}
    AlgComboBox {
      Layout.fillWidth: true
      property int minResolution: 256
      property int maxResolution: 2048
      textRole: "text"
      Component.onCompleted: parent.initResolutionComboBox(this, "linkDegradedResolution", model);
      model: ListModel {}
    }

    AlgSlider {
      Layout.columnSpan: 2
      Layout.fillWidth:true
      precision: 0
      stepSize: 50
      minValue: 100
      maxValue: 5000
      text: "HQ maps transfer delay (ms)"
      Component.onCompleted: parent.initSlider(this, "linkHQInterval");
    }
  }
}
