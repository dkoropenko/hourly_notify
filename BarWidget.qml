import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon that opens the hourly-notify settings panel. The chime itself runs in
// the plugin's singleton Service so it fires once per hour across all bars.
BarWidget {
  id: root
  moduleName: "dkoropenko.hourly-notify"

  readonly property string defaultSound: "/usr/share/sounds/freedesktop/stereo/complete.oga"

  readonly property bool enabledSetting: setting("enabled", true) !== false
  readonly property string soundSetting: {
    var value = setting("sound", root.defaultSound)
    return (value === undefined || value === null || value === "") ? root.defaultSound : String(value)
  }
  readonly property real volumeSetting: {
    var value = Number(setting("volume", 0.6))
    if (isNaN(value)) value = 0.6
    return Math.max(0, Math.min(1, value))
  }

  readonly property var service: serviceProbe.value
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // The service is created around the same time as the bar; poll until it
  // exists, then mirror settings into it and stop.
  function lookupService() {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.serviceFor !== "function") return null
    return root.bar.shell.serviceFor(root.moduleName)
  }

  function syncService() {
    var target = root.service
    if (!target) return
    target.enabled = root.enabledSetting
    target.soundPath = root.soundSetting
    target.volume = root.volumeSetting
  }

  // Merge values into this widget's inline shell.json entry and persist once.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    for (var changed in values) entry[changed] = values[changed]

    root.settings = entry
    if (panelLoader.item && "settings" in panelLoader.item) panelLoader.item.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    syncService()
  }

  function setEnabled(value) { persistSettings({ enabled: value === true }) }
  function setSound(value) { persistSettings({ sound: String(value) }) }

  // Live drag: update the service so the test plays at the dragged level, but
  // only write shell.json when the slider is released (commitVolume).
  function setVolumeLive(value) {
    var level = Math.max(0, Math.min(1, Number(value)))
    if (isNaN(level)) return
    if (root.service) root.service.volume = level
  }
  function commitVolume(value) {
    var level = Math.max(0, Math.min(1, Number(value)))
    if (isNaN(level)) level = root.volumeSetting
    persistSettings({ volume: level })
  }

  function playTest() { if (root.service) root.service.chime() }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onServiceChanged: syncService()
  onSettingsChanged: {
    injectPanel()
    syncService()
  }

  QtObject {
    id: serviceProbe
    property var value: null
  }

  Timer {
    interval: 250
    repeat: true
    triggeredOnStart: true
    running: root.service === null
    onTriggered: {
      var target = root.lookupService()
      if (target) {
        serviceProbe.value = target
        root.syncService()
      }
    }
  }

  IpcHandler {
    target: "dkoropenko.hourly-notify"

    function toggleChime(): void { root.setEnabled(!root.enabledSetting) }
    function setEnabled(value: string): void {
      root.setEnabled(String(value) === "true" || String(value) === "1")
    }
    function setSound(path: string): void { root.setSound(String(path)) }
    // Volume as a whole percent (0-100), matching the panel's readout.
    function setVolume(percent: string): void { root.commitVolume(Number(percent) / 100) }
    function chime(): void { root.playTest() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.enabledSetting ? "󰂚" : "󰂛"
    dimmed: !root.enabledSetting
    tooltipText: root.enabledSetting ? "Ежечасный сигнал включён" : "Ежечасный сигнал выключен"
    onPressed: root.togglePanel()
  }
}
