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

  function askAgent(task) {
    var localStatus = "GUI: " + (bootable.guiInstalled ? "installed" : "missing")
      + "; TUI: " + (bootable.tuiInstalled ? "installed" : "missing")
      + "; detected version: " + bootable.version
    var prompt = "Help me " + task + " for Bootable (https://github.com/debpalash/bootable) on this Omarchy system. "
      + "Inspect the machine and current stable release before acting. Local status: " + localStatus + ". "
      + "Prefer the official stable package or archive appropriate for this Arch-based machine, verify its published SHA-256 checksum, and make the requested interface command available on PATH. "
      + "Explain any system change and ask before privileged or destructive actions. Never write to removable media, select a storage device, or weaken Bootable's device-selection and confirmation safety gates."
    Quickshell.execDetached(["omarchy", "agent", "prompt", prompt])
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
    function gui(): string {
      if (bootable.guiInstalled) root.launchGui()
      else root.askAgent("install the Bootable desktop GUI")
      return bootable.guiInstalled ? "launched" : "agent-opened"
    }
    function tui(): string {
      if (bootable.tuiInstalled) root.launchTui()
      else root.askAgent("install the Bootable terminal UI")
      return bootable.tuiInstalled ? "launched" : "agent-opened"
    }
    function agent(): string { root.askAgent("diagnose and fix my Bootable installation"); return "agent-opened" }
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
        if (text === "g" || text === "G") {
          if (bootable.guiInstalled) root.launchGui()
          else root.askAgent("install the Bootable desktop GUI")
        }
        else if (text === "t" || text === "T") {
          if (bootable.tuiInstalled) root.launchTui()
          else root.askAgent("install the Bootable terminal UI")
        }
        else if (text === "a" || text === "A") root.askAgent("diagnose and fix my Bootable installation")
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
            : "Bootable is not on PATH yet. Pick an interface and Omarchy's default agent will help install it.")
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
          title: bootable.guiInstalled ? "Desktop GUI" : "Install Desktop GUI with AI"
          detail: bootable.guiInstalled ? "Open the visual media writer" : "Ask the default Omarchy agent"
          glyph: bootable.guiInstalled ? "󰖯" : "󰚩"
          shortcut: "G"
          onTriggered: {
            if (bootable.guiInstalled) root.launchGui()
            else root.askAgent("install the Bootable desktop GUI")
          }
        }

        ActionRow {
          width: parent.width
          title: bootable.tuiInstalled ? "Terminal UI" : "Install Terminal UI with AI"
          detail: bootable.tuiInstalled ? "Open Bootable in a new terminal" : "Ask the default Omarchy agent"
          glyph: bootable.tuiInstalled ? "󰆍" : "󰚩"
          shortcut: "T"
          onTriggered: {
            if (bootable.tuiInstalled) root.launchTui()
            else root.askAgent("install the Bootable terminal UI")
          }
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

        ActionRow {
          width: parent.width
          title: "Diagnose or fix with AI"
          detail: "Open the configured default Omarchy agent"
          glyph: "󰚩"
          shortcut: "A"
          onTriggered: root.askAgent("diagnose and fix my Bootable installation")
        }

        Text {
          width: parent.width
          text: "A asks AI  ·  R refreshes  ·  Esc closes"
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
    implicitHeight: Style.space(58)
    height: Style.space(58)
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
