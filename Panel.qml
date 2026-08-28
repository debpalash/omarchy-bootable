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
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
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
      + "; client mode: " + (bootable.clientCapable ? "available" : "missing")
      + "; privileged helper: " + (bootable.helperInstalled ? "installed" : "missing")
      + "; detected version: " + bootable.version
    var prompt = "Help me " + task + " for Bootable (https://github.com/debpalash/bootable) on this Omarchy system. "
      + "Inspect the machine and current stable release before acting. Local status: " + localStatus + ". "
      + "Prefer the official stable package or archive appropriate for this Arch-based machine, verify its published SHA-256 checksum, and install both bootable interfaces plus the root-owned privileged helper and polkit policy. "
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
    function create(): string {
      if (bootable.clientReady) {
        root.open()
        bootable.chooseImage()
        return "picker-opened"
      }
      root.askAgent("install or update Bootable so the Omarchy media client is ready")
      return "agent-opened"
    }
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
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Style.space(700), Style.space(740))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if ((text === "c" || text === "C") && bootable.clientReady) bootable.chooseImage()
        else if (text === "g" || text === "G") {
          if (bootable.guiInstalled) root.launchGui()
          else root.askAgent("install the Bootable desktop GUI")
        }
        else if (text === "t" || text === "T") {
          if (bootable.tuiInstalled) root.launchTui()
          else root.askAgent("install the Bootable terminal UI")
        }
        else if (text === "a" || text === "A") root.askAgent("diagnose and fix my Bootable installation")
        else if (text === "d" || text === "D") root.openUrl(root.releaseUrl)
        else if ((text === "r" || text === "R") && !bootable.writing) bootable.refreshDevices()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: scroll.width - Style.space(8)
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
            text: bootable.writing
              ? "The panel may be closed while Bootable keeps writing and verifying."
              : "Flash an OS image without leaving the Omarchy bar. Every target is still discovered, blocked, reviewed, and confirmed by Bootable."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          PanelSectionHeader {
            text: "CREATE MEDIA"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: !bootable.clientReady

            StatusCard {
              width: parent.width
              glyph: "󰚩"
              title: bootable.tuiInstalled ? "Bootable update needed" : "Install Bootable with AI"
              detail: !bootable.tuiInstalled
                ? "The terminal client is missing."
                : (!bootable.clientCapable
                  ? "This version does not support streaming client progress."
                  : "The root-owned write helper is missing.")
              tone: root.accent
            }

            ActionRow {
              width: parent.width
              title: "Prepare the media client"
              detail: "Ask Omarchy's default agent to install and verify it"
              glyph: "󰚩"
              shortcut: "A"
              onTriggered: root.askAgent("install or update Bootable so the Omarchy media client is ready")
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: bootable.clientReady

            ActionRow {
              width: parent.width
              title: bootable.sourcePath === "" ? "Choose OS image" : bootable.fileName(bootable.sourcePath)
              detail: bootable.imageReport
                ? bootable.imageKind(bootable.imageReport) + " · " + bootable.formatBytes(bootable.imageReport.size)
                : "ISO, IMG, RAW, or compressed disk image"
              glyph: bootable.sourcePath === "" ? "󰋩" : "󰈙"
              shortcut: "C"
              enabled: !bootable.busy
              onTriggered: bootable.chooseImage()
            }

            StatusCard {
              width: parent.width
              visible: bootable.busy && !bootable.writing
              glyph: "󰔟"
              title: bootable.workflow === "planning" ? "Preparing review" : "Checking media"
              detail: bootable.operationMessage
              tone: root.accent
            }

            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: bootable.workflow === "target"

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: parent.width - refreshButton.width - parent.spacing
                  text: "TARGET DRIVE"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  id: refreshButton
                  iconText: "󰑐"
                  tooltipText: "Refresh drives"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: bootable.refreshDevices()
                }
              }

              Repeater {
                model: bootable.devices
                delegate: DeviceRow {
                  required property var modelData
                  width: parent.width
                  device: modelData
                  onTriggered: bootable.selectDevice(device)
                }
              }

              Text {
                width: parent.width
                visible: bootable.devices.length === 0
                text: "No removable drive detected. Connect one, then refresh. Bootable will not choose a disk automatically."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.workflow === "review" && bootable.writePlan !== null

              StatusCard {
                width: parent.width
                glyph: "󰓦"
                title: bootable.deviceName(bootable.selectedTarget)
                detail: String(bootable.selectedTarget && bootable.selectedTarget.path || "")
                  + " · " + bootable.formatBytes(bootable.selectedTarget && bootable.selectedTarget.capacity || 0)
                tone: root.urgent
              }

              Text {
                width: parent.width
                text: "This erases the selected removable drive. Bootable will re-check its identity and safety immediately before writing."
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }

              Toggle {
                width: parent.width
                label: "I understand this drive will be erased"
                description: "A separate explicit acknowledgement is required."
                checked: bootable.acknowledged
                foreground: root.foreground
                accent: root.urgent
                onClicked: bootable.setAcknowledged(!bootable.acknowledged)
              }

              PrimaryAction {
                width: parent.width
                title: "Erase and write image"
                detail: bootable.acknowledged ? "Administrator authentication opens next" : "Acknowledge the erase first"
                glyph: "󰋊"
                enabled: bootable.canWrite
                destructive: true
                onTriggered: bootable.startWrite()
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.workflow === "writing"

              StatusCard {
                width: parent.width
                glyph: "󰑊"
                title: bootable.progressPhase
                detail: bootable.operationMessage
                tone: root.accent
              }

              Rectangle {
                width: parent.width
                height: Style.space(8)
                radius: height / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                clip: true

                Rectangle {
                  height: parent.height
                  width: bootable.progressKnown ? parent.width * bootable.progressPercent / 100 : parent.width * 0.24
                  radius: parent.radius
                  color: root.accent

                  SequentialAnimation on x {
                    running: bootable.writing && !bootable.progressKnown
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: Math.max(0, parent.parent.width - parent.width); duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: Math.max(0, parent.parent.width - parent.width); to: 0; duration: 900; easing.type: Easing.InOutSine }
                  }
                }
              }

              Row {
                width: parent.width
                Text {
                  width: parent.width / 2
                  text: bootable.progressKnown
                    ? bootable.formatBytes(bootable.progressCompleted) + " / " + bootable.formatBytes(bootable.progressTotal)
                    : "Working…"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  width: parent.width / 2
                  text: bootable.progressKnown ? bootable.progressPercent + "%" : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignRight
                }
              }

              Text {
                width: parent.width
                text: "Do not unplug the drive. Closing this panel does not cancel the write."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.workflow === "finished"

              StatusCard {
                width: parent.width
                glyph: "󰄬"
                title: "Media ready"
                detail: bootable.operationMessage
                tone: root.accent
              }

              PrimaryAction {
                width: parent.width
                title: "Flash another image"
                detail: "Start a fresh, unselected workflow"
                glyph: "󰑐"
                onTriggered: bootable.resetWorkflow()
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.workflow === "error"

              StatusCard {
                width: parent.width
                glyph: "󰅚"
                title: "Write did not complete"
                detail: bootable.operationError
                tone: root.urgent
              }

              PrimaryAction {
                width: parent.width
                title: "Refresh and retry"
                detail: "Re-discover drives and build a new plan"
                glyph: "󰑐"
                onTriggered: bootable.retry()
              }
            }

            Text {
              width: parent.width
              visible: bootable.workflow !== "error" && bootable.workflow !== "finished"
                && bootable.workflow !== "writing" && bootable.operationMessage !== ""
              text: bootable.operationMessage
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          PanelSectionHeader {
            text: "FULL INTERFACES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          ActionRow {
            width: parent.width
            title: bootable.guiInstalled ? "Desktop GUI" : "Install Desktop GUI with AI"
            detail: bootable.guiInstalled ? "Open the full visual media writer" : "Ask the default Omarchy agent"
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
            text: "C chooses image  ·  R refreshes drives  ·  Esc closes"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component StatusCard: Rectangle {
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property color tone: root.foreground

    implicitHeight: cardContent.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.09)
    border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.28)
    border.width: 1

    RowLayout {
      id: cardContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text {
        text: parent.parent.glyph
        color: parent.parent.tone
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        Layout.alignment: Qt.AlignTop
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)
        Text {
          Layout.fillWidth: true
          text: cardContent.parent.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.WordWrap
        }
        Text {
          Layout.fillWidth: true
          text: cardContent.parent.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  component DeviceRow: CursorSurface {
    id: deviceRow
    required property var device
    signal triggered()

    foreground: root.foreground
    implicitHeight: Style.space(66)
    height: implicitHeight
    opacity: bootable.eligible(device) ? 1.0 : 0.48

    MouseArea {
      anchors.fill: parent
      enabled: bootable.eligible(device)
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: deviceRow.triggered()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text {
        text: bootable.eligible(device) ? "󰕓" : "󰌾"
        color: bootable.eligible(device) ? root.accent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: bootable.deviceName(device)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: String(device.path || "") + " · " + bootable.formatBytes(device.capacity)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: bootable.eligibility(device)
          color: bootable.eligible(device) ? root.accent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        visible: bootable.eligible(device)
        text: "󰁔"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }

  component PrimaryAction: Rectangle {
    id: primary
    property string title: ""
    property string detail: ""
    property string glyph: ""
    property bool destructive: false
    signal triggered()

    implicitHeight: Style.space(58)
    radius: Style.cornerRadius
    color: Qt.rgba((destructive ? root.urgent : root.accent).r,
      (destructive ? root.urgent : root.accent).g,
      (destructive ? root.urgent : root.accent).b,
      primaryMouse.pressed ? 0.30 : (primaryMouse.containsMouse ? 0.22 : 0.14))
    border.color: Qt.rgba((destructive ? root.urgent : root.accent).r,
      (destructive ? root.urgent : root.accent).g,
      (destructive ? root.urgent : root.accent).b, 0.55)
    border.width: 1
    opacity: enabled ? 1.0 : 0.42

    MouseArea {
      id: primaryMouse
      anchors.fill: parent
      enabled: primary.enabled
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: primary.triggered()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(10)
      Text {
        text: primary.glyph
        color: primary.destructive ? root.urgent : root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: primary.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: primary.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
      Text {
        text: "󰁔"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
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
      }

      PanelActionButton {
        iconText: "󰁔"
        tooltipText: actionRow.title
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: actionRow.enabled
        onClicked: actionRow.triggered()
      }
    }
  }
}
