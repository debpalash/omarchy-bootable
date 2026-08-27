import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.debpalash.bootable"
  ipcTarget: "io.github.debpalash.bootable"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string releaseUrl: "https://github.com/debpalash/bootable/releases/latest"
  readonly property string repositoryUrl: "https://github.com/debpalash/bootable"

  function launchGui() {
    if (!bootable.guiInstalled) return
    Quickshell.execDetached(["bootable-desktop"])
    close()
  }

  function launchTui() {
    if (!bootable.tuiInstalled) return
    Quickshell.execDetached(["omarchy-launch-terminal", "bootable"])
    close()
  }

  function openUrl(url) {
    Quickshell.execDetached(["omarchy-launch-browser", url])
    close()
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  onOpenedChanged: if (opened) {
    bootable.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service { id: bootable }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { bootable.refresh(); return "ok" }
    function status(): string { return bootable.version }
    function gui(): string { root.launchGui(); return bootable.guiInstalled ? "launched" : "not-installed" }
    function tui(): string { root.launchTui(); return bootable.tuiInstalled ? "launched" : "not-installed" }
  }

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    iconComponent: Component {
      Image {
        source: Qt.resolvedUrl("bootable-app-mark.svg")
        sourceSize.width: Style.space(16)
        sourceSize.height: Style.space(16)
        fillMode: Image.PreserveAspectFit
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) bootable.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "g" || text === "G") root.launchGui()
        else if (text === "t" || text === "T") root.launchTui()
        else if (text === "d" || text === "D") root.openUrl(root.releaseUrl)
        else if (text === "r" || text === "R") bootable.refresh()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Bootable"
          meta: bootable.loading ? "Checking local installation…" : bootable.version
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Image {
              source: Qt.resolvedUrl("bootable-mark.svg")
              sourceSize.width: Style.space(34)
              sourceSize.height: Style.space(34)
              fillMode: Image.PreserveAspectFit
            }
          }
        }

        Text {
          width: parent.width
          text: bootable.error !== "" ? bootable.error : (bootable.installed
            ? "Write operating-system images from the interface you prefer. Device selection and confirmation stay inside Bootable."
            : "Bootable is not on PATH yet. Download the native package for this machine to get started.")
          color: bootable.error !== "" ? (bar ? bar.urgent : Color.urgent) : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        PanelSectionHeader {
          text: "LAUNCH"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ActionRow {
          width: parent.width
          title: "Desktop GUI"
          detail: bootable.guiInstalled ? "Open the visual media writer" : "bootable-desktop is not installed"
          glyph: "󰖯"
          shortcut: "G"
          enabled: bootable.guiInstalled
          onTriggered: root.launchGui()
        }

        ActionRow {
          width: parent.width
          title: "Terminal UI"
          detail: bootable.tuiInstalled ? "Open Bootable in a new terminal" : "bootable is not installed"
          glyph: "󰆍"
          shortcut: "T"
          enabled: bootable.tuiInstalled
          onTriggered: root.launchTui()
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        PanelSectionHeader {
          text: "PROJECT"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ActionRow {
          width: parent.width
          title: "Latest stable release"
          detail: "Native packages and checksums"
          glyph: "󰇚"
          shortcut: "D"
          onTriggered: root.openUrl(root.releaseUrl)
        }

        ActionRow {
          width: parent.width
          title: "Source and documentation"
          detail: "debpalash/bootable"
          glyph: ""
          shortcut: ""
          onTriggered: root.openUrl(root.repositoryUrl)
        }

        Text {
          width: parent.width
          text: "R refreshes status  ·  Esc closes"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string title: ""
    property string detail: ""
    property string glyph: ""
    property string shortcut: ""
    signal triggered()

    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.space(16)
    height: implicitHeight
    opacity: enabled ? 1.0 : 0.45

    MouseArea {
      anchors.fill: parent
      enabled: actionRow.enabled
      hoverEnabled: true
      cursorShape: actionRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: actionRow.triggered()
    }

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text {
        text: actionRow.glyph
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: actionRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: actionRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        visible: actionRow.shortcut !== ""
        text: actionRow.shortcut
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      PanelActionButton {
        iconText: "󰁔"
        tooltipText: actionRow.title
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: actionRow.enabled
        Layout.alignment: Qt.AlignVCenter
        onClicked: actionRow.triggered()
      }
    }
  }
}
