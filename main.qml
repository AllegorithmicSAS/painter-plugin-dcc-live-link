import QtQuick 2.7
import QtWebSockets 1.0
import Painter 1.0
import "."

/* Allows to link Substance 3D Painter with an external program by using a persistent connection between both programs
 *
 * The connection is based on a WebSocket connection with a simple command protocol: "[COMMAND KEY] [JSON DATA]"
 * List of commands to which this plugin is able to answer:
 * - CREATE_PROJECT: Create a project with specified mesh and link it with the integration
 * - OPEN_PROJECT: Open an existing project and link it with the integration
 * - SEND_PROJECT_INFO: Send back info on the current project (project url and integration link identifier)
 *
 * For CREATE_PROJECT and OPEN_PROJECT, we receive a bag of information containing all the configuration
 * allowing to link a project:
 * {
 *     applicationName: "", // External application name
 *     workspacePath: "",   // Workspace path (the workspace of the external application)
 *     exportPath: "",      // Relative path in the workspace in which we want to export textures
 *     materials: {         // List of linked materials
 *         "my_application_material_name": {
 *             assetPath: "",      // External application material ID
 *             exportPreset: "",   // Name or url of the export preset to use
 *             resourceShader: "", // Name or url of the Substance 3D Painter shader to render the material
 *             spToUnityProperties: {
 *                 // Association between Substance 3D Painter exported textures and application textures
 *                 // "texture name as define in the SP template" => "external application ID"
 *                 // Example:
 *                 "$mesh_$textureSet_baseColor": "basecolor_texture_sampler_in_my_shader",
 *                 "...": "..."
 *             }
 *         },
 *         "...", {...}
 *     }
 *     project:
 *     {
 *         meshUrl: "",  // Mesh to use for the new project
 *         normal: "",   // Normal format to use (OpenGL/DirectX)
 *         template: "", // Template url or name to use
 *         url: ""       // Substance 3D Painter project location
 *     },
 *     linkIdentifier: "" // Identifier that will be serialized with the project to allow reconnection
 * }
 */
PainterPlugin {
  id: root

  property alias linkQuickInterval : settings.linkQuickInterval
  property alias linkDegradedResolution : settings.linkDegradedResolution
  property alias linkHQTreshold : settings.linkHQTreshold
  property alias linkHQInterval : settings.linkHQInterval
  property alias initDelayOnProjectCreation : settings.initDelayOnProjectCreation

  property bool isLinked: false
  property var liveLinkConfig: null
  property var sendMapsButton: null
  readonly property string linkIdentifierKey: "live_link_identifier"
  readonly property bool enableAutoLink: settings.enableAutoLink

  state: "disconnected"
  states: [
    State {
      name: "disconnected"
      PropertyChanges { target: root; isLinked: false }
    },
    State {
      name: "connected"
      PropertyChanges { target: root; isLinked: true }
    },
    State {
      name: "exporting"
      extend: "connected"
    }
  ]

  Component.onCompleted: {
    sendMapsButton = alg.ui.addWidgetToPluginToolBar("ButtonSendMaps.qml");
    sendMapsButton.clicked.connect(sendMaps);
    sendMapsButton.enabled = Qt.binding(function() { return root.isLinked; });
  }

  onConfigure:
  {
    settings.open();
  }

  onEnableAutoLinkChanged: {
    if (enableAutoLink) {
      autoLink();
    }
    if (sendMapsButton) {
      sendMapsButton.enableAutoLink = enableAutoLink
    }
  }

  function disconnect() {
    if (root.liveLinkConfig) {
        alg.log.info(root.liveLinkConfig.applicationName + " client disconnected");
    }
    lqTimer.stop();
    hqTimer.stop();
    root.liveLinkConfig = null;
    root.state = "disconnected"
  }

  function sendMaps(materialsToSend, mapExportConfig) {
    function sendMaterialsMaps() {
        var fullExportPath = "%1/%2".arg(root.liveLinkConfig.workspacePath).arg(root.liveLinkConfig.exportPath);

      function sendMaterialMaps(materialLink, mapsInfos) {
        // Ask the loading of each maps
        var data = {
          material: materialLink.assetPath,
          params: {}
        };
        for (var mapName in mapsInfos) {
          // Convert absolute map path as a workspace relative path
          var mapPath = mapsInfos[mapName];
          if (mapPath.length == 0) continue;

          if (mapName in materialLink.spToLiveLinkProperties) {
            // Convert absolute map path as a workspace relative path
            var relativeMapPath = mapPath.replace(root.liveLinkConfig.workspacePath + "/", '');
            data.params[materialLink.spToLiveLinkProperties[mapName]] = relativeMapPath;
          }
          else {
            alg.log.warn("No defined association with the exported '%1' map".arg(mapName));
          }
        }
        server.sendCommand("SET_MATERIAL_PARAMS", data);
      }

      // Export map from preset
      var materialsName = alg.mapexport.documentStructure().materials.map(
        function(m) { return m.name; }
      ).sort();

      // Filter materials if needed
      if (materialsToSend !== undefined) {
        materialsName = materialsName.filter(
          function(m) { return materialsToSend.indexOf(m) !== -1; }
        );
      }

      for (var i in materialsName) {
        var materialName = materialsName[i];
        if (!(materialName in root.liveLinkConfig.materials)) {
          alg.log.warn("Material %1 is not correctly linked with %2"
            .arg(materialName)
            .arg(root.liveLinkConfig.applicationName));
          continue;
        }

        var materialLink = root.liveLinkConfig.materials[materialName];
        root.state = "exporting"
        var exportData = alg.mapexport.exportDocumentMaps(
          materialLink.exportPreset,
          fullExportPath,
          "tga",
          mapExportConfig,
          [materialName]
        );
        root.state = "connected"
        if (root.sendMapsButton) {
            root.sendMapsButton.clientName = root.liveLinkConfig.applicationName;
        }
        for (var stackPath in exportData) {
          sendMaterialMaps(materialLink, exportData[stackPath]);
        }
      }
    }

    if (root.state == "disconnected") return;
    try {
      sendMaterialsMaps();
    }
    catch(err) {alg.log.exception(err);}
  }

  function getCurrentTextureSet() {
    return alg.mapexport.documentStructure().materials
      .filter(function(m){return m.selected})[0].name;
  }

  function autoLink() {
    if (root.state == "disconnected") return;
    var textureSet = getCurrentTextureSet();
    var resolution = alg.mapexport.textureSetResolution(textureSet);
    // Enable deferred high quality only if resolution > treshold
    if (resolution[0] * resolution[1] <=
        root.linkHQTreshold * root.linkHQTreshold) {
      sendMaps([textureSet]);
    }
    else {
      sendMaps([textureSet], {
        resolution: [
          root.linkDegradedResolution,
          root.linkDegradedResolution * (resolution[1] / resolution[0])
        ]
      });
      hqTimer.start();
    }
  }

  Timer {
    id: lqTimer
    repeat: false
    interval: root.linkQuickInterval
    onTriggered: autoLink()
  }

  Timer {
    id: hqTimer
    repeat: false
    interval: root.linkHQInterval
    onTriggered: sendMaps([getCurrentTextureSet()])
  }

  onComputationStatusChanged: {
    // When the engine status becomes non busy; we send the current texture set.
    // If resolution is too high; we send a first degraded version to
    // quickly visualize results; then we send the high quality version after
    // few seconds.
    // If paint engine status change during this time, we stop all timers.
    lqTimer.stop();
    hqTimer.stop();
    if (root.state === "connected" && !isComputing && enableAutoLink) {
      lqTimer.start();
    }
  }

  function linkToClient(data) {
    root.liveLinkConfig = {
      applicationName: data.applicationName,
      exportPath: data.exportPath.replace("\\", "/"),
      workspacePath: data.workspacePath.replace("\\", "/"),
      linkIdentifier: data.linkIdentifier, // Identifier to allow reconnection
      materials: data.materials, // Materials info (path, export preset, shader, association)
      project: data.project // Project configuration (mesh, normal, template, url)
    }

    alg.log.info(root.liveLinkConfig.applicationName + " client connected");
  }

  function applyResourceShaders() {
    var shaderInstances = {
      shaders: {},
      texturesets: {}
    };
    // Create one shader instance per material
    for (var materialName in root.liveLinkConfig.materials) {
      var materialLink = root.liveLinkConfig.materials[materialName];

      var shaderInstanceName = materialName;
      shaderInstances.shaders[shaderInstanceName] = {
        shader: materialLink.resourceShader,
        shaderInstance: shaderInstanceName
      };
      shaderInstances.texturesets[materialName] = {
        shader: shaderInstanceName
      }
    }
    try {
      alg.shaders.shaderInstancesFromObject(shaderInstances);
    }
    catch(err) {
      alg.log.warn("Error while creating shader instances: %1".arg(err.message));
    }
  }

  function initSynchronization(mapsNeeded) {
    // If there is only one material, auto associate one
    // with SP one even if name doesn't match
    {
      var spMaterials = alg.mapexport.documentStructure().materials;
      var integrationMaterials = root.liveLinkConfig.materials;
      var integrationMaterialsNames = Object.keys(integrationMaterials);
      if (spMaterials.length === 1 && integrationMaterialsNames.length === 1) {
        var matName = integrationMaterialsNames[0];
        var spMatName = spMaterials[0].name;

        var material = root.liveLinkConfig.materials[matName];
        root.liveLinkConfig.materials = {};
        root.liveLinkConfig.materials[spMatName] = material;
      }
    }

    root.state = "connected";
    alg.project.settings.setValue(linkIdentifierKey, root.liveLinkConfig.linkIdentifier);
    if (mapsNeeded) {
      sendMaps();
    }
    applyResourceShaders();
  }

  function createProject(data) {
    linkToClient(data);

    if (alg.project.isOpen()) {
      // TODO: Ask the user if he wants to save its current opened project
      alg.project.close();
    }
    alg.project.create(root.liveLinkConfig.project.meshUrl, null, root.liveLinkConfig.project.template, {
      normalMapFormat: root.liveLinkConfig.project.normal
    });

    // HACK: Substance 3D Painter is not synchronous when creating a project
    setTimeout(function(projectUrl) {
      return function() {
        initSynchronization();
        alg.project.save(projectUrl);
      };
    }(data.project.url), root.initDelayOnProjectCreation);
  }

  function openProject(data) {
    linkToClient(data);

    var projectOpened = alg.project.isOpen();
    var isAlreadyOpen = false;
    try {
      function cleanUrl(url) {
        return alg.fileIO.localFileToUrl(alg.fileIO.urlToLocalFile(url));
      }
      isAlreadyOpen =
        cleanUrl(alg.project.url()) == cleanUrl(data.project.url) ||
        data.linkIdentifier == alg.project.settings.value(linkIdentifierKey);
    }
    catch (err) {}

    // If the project is already opened, keep it
    try {
      if (!isAlreadyOpen) {
        if (projectOpened) {
          // TODO: Ask the user if he wants to save its current opened project
          alg.project.close();
        }
        alg.project.open(data.project.url);
      }
      var mapsNeeded = !isAlreadyOpen;
      initSynchronization(mapsNeeded);
    }
    catch (err) {
      alg.log.exception(err)
      disconnect()
    }
  }

  function sendProjectInfo() {
    try {
      if (alg.project.settings.contains(linkIdentifierKey)) {
        server.sendCommand("OPENED_PROJECT_INFO", {
          linkIdentifier: alg.project.settings.value(linkIdentifierKey),
          projectUrl: alg.project.url()
        });
      }
    }
    catch(err) {}
  }

  CommandServer {
    id: server
    Component.onCompleted: {
      registerCallback("CREATE_PROJECT", createProject);
      registerCallback("OPEN_PROJECT", openProject);
      registerCallback("SEND_PROJECT_INFO", sendProjectInfo);
    }

    onConnectedChanged: {
      if (!connected) {
        disconnect();
      }
    }
  }

  Settings {
    id: settings
  }
}
