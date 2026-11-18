import QtQuick
import qs.Commons
import qs.Ui

// Settings UI for the hourly chime: enable/disable, sound picker, an
// independent volume slider, and a test button.
Panel {
  id: root
  moduleName: "dkoropenko.hourly-notify"
  ipcTarget: "dkoropenko.hourly-notify"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var barIdentity: hostWidget || root
  readonly property var service: hostWidget ? hostWidget.service : null
  readonly property var soundOptions: service ? service.soundOptions : []
  readonly property bool chimeEnabled: hostWidget ? hostWidget.enabledSetting : false
  readonly property string currentSound: hostWidget ? hostWidget.soundSetting : ""
  readonly property real currentVolume: hostWidget ? hostWidget.volumeSetting : 0.6

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // Keyboard cursor. Rows: 0 = enable switch, 1 = sound, 2 = volume, 3 = test.
  property bool cursorActive: false
  property int selectedIndex: 0

  function moveCursor(delta) {
    var next = root.selectedIndex + delta
    if (next < 0) next = 0
    if (next > 3) next = 3
    root.selectedIndex = next
  }

  function adjustVolume(delta) {
    if (!root.hostWidget) return
    root.hostWidget.commitVolume(Math.max(0, Math.min(1, root.currentVolume + delta)))
  }

  function activate() {
    if (!root.hostWidget) return
    if (root.selectedIndex === 0) root.hostWidget.setEnabled(!root.chimeEnabled)
    else if (root.selectedIndex === 1) soundDropdown.open()
    else if (root.selectedIndex === 3) root.hostWidget.playTest()
  }

  function setCursor(row) {
    root.cursorActive = true
    root.selectedIndex = row
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: soundDropdown.popupOpen
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0 && root.selectedIndex === 2) root.adjustVolume(dx * 0.05)
      }
      onActivateRequested: if (root.cursorActive) root.activate()
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "t" || t === "T") { if (root.hostWidget) root.hostWidget.playTest() }
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(14)

        // ---- Hero: bell icon, title/status, on-off switch ----
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroSwitch.implicitHeight)

          Text {
            id: heroIcon
            text: root.chimeEnabled ? "󰂚" : "󰂛"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            opacity: root.chimeEnabled ? 1.0 : 0.5
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          ToggleSwitch {
            id: heroSwitch
            checked: root.chimeEnabled
            foreground: root.contentForeground
            hasCursor: root.cursorActive && root.selectedIndex === 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onHovered: function(on) { if (on) root.setCursor(0) }
            onToggled: if (root.hostWidget) root.hostWidget.setEnabled(!root.chimeEnabled)
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroSwitch.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Ежечасный сигнал"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.chimeEnabled ? "КАЖДЫЙ ЧАС В :00" : "ВЫКЛЮЧЕНО"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        // ---- Sound picker ----
        Column {
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "ЗВУК ОПОВЕЩЕНИЯ"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
          }

          Dropdown {
            id: soundDropdown
            width: parent.width
            showLabel: false
            value: root.currentSound
            options: root.soundOptions
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            hasCursor: root.cursorActive && root.selectedIndex === 1
            onChanged: function(v) { if (root.hostWidget) root.hostWidget.setSound(v) }
            onHovered: function(on) { if (on) root.setCursor(1) }
          }
        }

        // ---- Independent volume ----
        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: volumeHeader.implicitHeight

            PanelSectionHeader {
              id: volumeHeader
              text: "ГРОМКОСТЬ СИГНАЛА"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: Math.round((volumeSlider.dragging ? volumeSlider.liveValue : root.currentVolume) * 100) + "%"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          CursorSurface {
            id: volumeRow
            width: parent.width
            height: volumeSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.selectedIndex === 2
            foreground: root.contentForeground
            outline: true

            PanelSlider {
              id: volumeSlider
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 0
              maximum: 1
              step: 0.05
              value: root.currentVolume
              onMoved: function(v) { if (root.hostWidget) root.hostWidget.setVolumeLive(v) }
              onReleased: function(v) { if (root.hostWidget) root.hostWidget.commitVolume(v) }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) root.setCursor(2)
            }
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        // ---- Test ----
        Button {
          id: testButton
          width: parent.width
          text: "Проверить сигнал"
          iconText: "󰐊"
          bordered: true
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          hasCursor: root.cursorActive && root.selectedIndex === 3
          onClicked: if (root.hostWidget) root.hostWidget.playTest()
          onHovered: function(on) { if (on) root.setCursor(3) }
        }

        Text {
          width: parent.width
          text: "Тест звучит с выбранной громкостью сигнала."
          color: Qt.darker(root.contentForeground, 1.6)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
