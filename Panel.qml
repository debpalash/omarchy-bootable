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
  property bool showMore: false

  readonly property int compactPanelHeight: {
    if (bootable.catalogWorkflow === "catalog" || bootable.catalogWorkflow === "releases") return Style.space(430)
    if (bootable.catalogWorkflow === "downloading") return Style.space(350)
    if (bootable.catalogWorkflow === "catalog-error") return Style.space(390)
    if (bootable.catalogWorkflow !== "idle") return Style.space(300)
    if (showMore) return Style.space(500)
    if (!bootable.clientReady) return Style.space(300)
    if (bootable.workflow === "target") return Style.space(500)
    if (bootable.workflow === "review") return Style.space(540)
    if (bootable.workflow === "writing") return Style.space(430)
    if (bootable.workflow === "finished") return Style.space(350)
    if (bootable.workflow === "error") return Style.space(410)
    return Style.space(285)
  }

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
      + "; catalog client: " + (bootable.catalogCapable ? "available" : "missing")
      + "; privileged helper: " + (bootable.helperInstalled ? "installed" : "missing")
      + "; detected version: " + bootable.version
    var prompt = "Help me " + task + " for Bootable (https://github.com/debpalash/bootable) on this Omarchy system. "
      + "Inspect the live machine plus current stable and published release-candidate channels before acting. Local status: " + localStatus + ". "
      + "Bootable's in-panel client requires version 0.1.4 or newer with both write --json-progress and download --json-progress. Never downgrade a newer compatible published build to an older stable release that lacks these capabilities. "
      + "Prefer stable when it satisfies the client requirement; otherwise use the newest published release candidate for this Arch-based machine. Verify the chosen artifact's published SHA-256 checksum, and ensure both Bootable interfaces plus the root-owned privileged helper and polkit policy are installed. "
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

  Connections {
    target: bootable
    function onCatalogWorkflowChanged() {
      if (bootable.catalogWorkflow !== "idle") {
        scroll.contentY = 0
        catalogResults.contentY = 0
      }
      if (bootable.catalogWorkflow === "catalog") {
        Qt.callLater(function() { catalogSearch.forceActiveFocus() })
      }
    }
  }

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
    function discover(): string {
      root.open()
      root.showMore = false
      if (bootable.catalogCapable) bootable.openCatalog()
      else root.askAgent("install or update Bootable so catalog downloads support streaming client progress")
      return bootable.catalogCapable ? "catalog-opened" : "agent-opened"
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
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: bootable.catalogWorkflow === "idle"
      ? panel.fittedContentHeight(Math.min(content.implicitHeight, root.compactPanelHeight), root.compactPanelHeight)
      : root.compactPanelHeight

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: catalogSearch.activeFocus
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
        else if ((text === "s" || text === "S") && bootable.clientReady) {
          root.showMore = false
          if (bootable.catalogCapable) bootable.openCatalog()
          else root.askAgent("install or update Bootable so catalog downloads support streaming client progress")
        }
        else if (text === "m" || text === "M") root.showMore = !root.showMore
        else if ((text === "r" || text === "R") && !bootable.writing) bootable.refreshDevices()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        interactive: bootable.catalogWorkflow === "idle"
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

          PanelSectionHeader {
            text: bootable.writing ? "FLASHING MEDIA" : "CREATE MEDIA"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          DeviceStatusRow {
            width: parent.width
            visible: bootable.clientReady
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

            RowLayout {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.sourcePath === "" && bootable.catalogWorkflow === "idle"

              SourceChoice {
                Layout.fillWidth: true
                glyph: "󰋩"
                title: "Local image"
                detail: "Browse files"
                shortcut: "C"
                enabled: !bootable.busy
                onTriggered: bootable.chooseImage()
              }

              SourceChoice {
                Layout.fillWidth: true
                glyph: "󰇚"
                title: "Discover ISO"
                detail: bootable.catalogCapable ? "Search catalog" : "Update needed"
                shortcut: "S"
                enabled: !bootable.busy
                onTriggered: {
                  root.showMore = false
                  if (bootable.catalogCapable) bootable.openCatalog()
                  else root.askAgent("install or update Bootable so catalog downloads support streaming client progress")
                }
              }
            }

            ActionRow {
              width: parent.width
              visible: bootable.sourcePath !== "" && bootable.catalogWorkflow === "idle"
              title: bootable.fileName(bootable.sourcePath)
              detail: bootable.imageReport
                ? bootable.imageKind(bootable.imageReport) + " · " + bootable.formatBytes(bootable.imageReport.size)
                : "ISO, IMG, RAW, or compressed disk image"
              glyph: "󰈙"
              shortcut: "C"
              enabled: !bootable.busy
              onTriggered: bootable.chooseImage()
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.catalogWorkflow !== "idle"

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  Layout.fillWidth: true
                  text: bootable.selectedDistribution
                    ? String(bootable.selectedDistribution.name || "ISO releases")
                    : "DISCOVER IMAGES"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }

                PanelActionButton {
                  iconText: "󰅁"
                  tooltipText: bootable.selectedDistribution ? "Back to catalog" : "Close catalog"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !bootable.catalogBusy
                  onClicked: bootable.selectedDistribution ? bootable.backToCatalog() : bootable.closeCatalog()
                }
              }

              StatusCard {
                width: parent.width
                visible: bootable.catalogWorkflow === "catalog-loading" || bootable.catalogWorkflow === "releases-loading"
                glyph: "󰔟"
                title: bootable.catalogWorkflow === "catalog-loading" ? "Loading catalog" : "Finding ISO releases"
                detail: bootable.catalogMessage
                tone: root.accent
              }

              TextField {
                id: catalogSearch
                width: parent.width
                visible: bootable.catalogWorkflow === "catalog"
                placeholderText: "Search distributions or base…"
                text: bootable.catalogQuery
                color: root.foreground
                placeholderTextColor: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                selectByMouse: true
                background: Rectangle {
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.055)
                  border.color: catalogSearch.activeFocus ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
                  border.width: 1
                }
                onTextChanged: bootable.catalogQuery = text
                Keys.onEscapePressed: function(event) {
                  catalogSearch.focus = false
                  keyCatcher.forceActiveFocus()
                  event.accepted = true
                }
                onAccepted: {
                  catalogSearch.focus = false
                  keyCatcher.forceActiveFocus()
                }
              }

              Flickable {
                id: catalogResults
                width: parent.width
                height: Style.space(180)
                visible: bootable.catalogWorkflow === "catalog" || bootable.catalogWorkflow === "releases"
                clip: true
                contentWidth: width
                contentHeight: resultRows.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                  id: resultRows
                  width: catalogResults.width - Style.space(8)
                  spacing: Style.space(4)

                  Repeater {
                    model: bootable.catalogWorkflow === "catalog" ? bootable.filteredCatalog : []
                    delegate: ActionRow {
                      required property var modelData
                      width: parent.width
                      title: String(modelData.name || modelData.slug)
                      detail: "#" + String(modelData.rank || "–") + " · " + String(modelData.based_on || "Independent")
                      glyph: "󰣇"
                      shortcut: ""
                      onTriggered: bootable.loadReleases(modelData)
                    }
                  }

                  Repeater {
                    model: bootable.catalogWorkflow === "releases" ? bootable.releases : []
                    delegate: ActionRow {
                      required property var modelData
                      required property int index
                      width: parent.width
                      title: String(modelData.name || "ISO image")
                      detail: bootable.formatBytes(modelData.size || 0)
                        + (modelData.checksum ? " · publisher checksum" : " · checksum unavailable")
                      glyph: "󰇚"
                      shortcut: ""
                      onTriggered: bootable.downloadRelease(modelData, index)
                    }
                  }
                }
              }

              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: bootable.catalogWorkflow === "downloading"

                StatusCard {
                  width: parent.width
                  glyph: "󰇚"
                  title: bootable.downloadPhase
                  detail: bootable.catalogMessage
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
                    width: bootable.downloadKnown ? parent.width * bootable.downloadPercent / 100 : parent.width * 0.24
                    radius: parent.radius
                    color: root.accent

                    SequentialAnimation on x {
                      running: bootable.downloading && !bootable.downloadKnown
                      loops: Animation.Infinite
                      NumberAnimation { from: 0; to: Math.max(0, parent.parent.width - parent.width); duration: 900; easing.type: Easing.InOutSine }
                      NumberAnimation { from: Math.max(0, parent.parent.width - parent.width); to: 0; duration: 900; easing.type: Easing.InOutSine }
                    }
                  }
                }

                Text {
                  width: parent.width
                  text: bootable.downloadKnown
                    ? bootable.downloadPercent + "% · " + bootable.formatBytes(bootable.downloadCompleted) + " / " + bootable.formatBytes(bootable.downloadTotal)
                    : "Downloading…"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: bootable.catalogWorkflow === "catalog-error"

                StatusCard {
                  width: parent.width
                  glyph: "󰅚"
                  title: "Catalog action failed"
                  detail: bootable.catalogError
                  tone: root.urgent
                }

                PrimaryAction {
                  width: parent.width
                  title: bootable.selectedDistribution ? "Retry ISO lookup" : "Retry catalog"
                  detail: "Run the Bootable CLI request again"
                  glyph: "󰑐"
                  onTriggered: bootable.selectedDistribution
                    ? bootable.loadReleases(bootable.selectedDistribution)
                    : bootable.openCatalog()
                }
              }
            }

            StatusCard {
              width: parent.width
              visible: bootable.busy && !bootable.writing && !bootable.downloading
                && bootable.catalogWorkflow === "idle"
              glyph: "󰔟"
              title: bootable.workflow === "planning" ? "Preparing review" : "Checking media"
              detail: bootable.operationMessage
              tone: root.accent
            }

            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: bootable.catalogWorkflow === "idle" && bootable.workflow === "target"
                && bootable.imageReport !== null && bootable.sourcePath !== ""

              PanelSectionHeader {
                text: "SELECT TARGET"
                foreground: root.foreground
                fontFamily: root.fontFamily
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
                text: "Connect a removable USB drive, then refresh. Nothing is selected automatically."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              visible: bootable.catalogWorkflow === "idle" && bootable.workflow === "review" && bootable.writePlan !== null

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
              visible: bootable.catalogWorkflow === "idle" && bootable.workflow === "writing"

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
              visible: bootable.catalogWorkflow === "idle" && bootable.workflow === "finished"

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
              visible: bootable.catalogWorkflow === "idle" && bootable.workflow === "error"

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

          }

          CompactActionRow {
            width: parent.width
            title: root.showMore ? "Hide full-app links" : "Open GUI, TUI, downloads, or AI help"
            glyph: root.showMore ? "󰅀" : "󰅂"
            shortcut: "M"
            enabled: !bootable.writing
            visible: bootable.catalogWorkflow === "idle"
            onTriggered: root.showMore = !root.showMore
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
            visible: root.showMore && bootable.catalogWorkflow === "idle"
          }

          PanelSectionHeader {
            text: "FULL INTERFACES"
            foreground: root.foreground
            fontFamily: root.fontFamily
            visible: root.showMore && bootable.catalogWorkflow === "idle"
          }

          ActionRow {
            width: parent.width
            title: bootable.guiInstalled ? "Desktop GUI" : "Install Desktop GUI with AI"
            detail: bootable.guiInstalled ? "Open the full visual media writer" : "Ask the default Omarchy agent"
            glyph: bootable.guiInstalled ? "󰖯" : "󰚩"
            shortcut: "G"
            visible: root.showMore && bootable.catalogWorkflow === "idle"
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
            visible: root.showMore && bootable.catalogWorkflow === "idle"
            onTriggered: {
              if (bootable.tuiInstalled) root.launchTui()
              else root.askAgent("install the Bootable terminal UI")
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
            visible: root.showMore && bootable.catalogWorkflow === "idle"
          }

          PanelSectionHeader {
            text: "PROJECT"
            foreground: root.foreground
            fontFamily: root.fontFamily
            visible: root.showMore && bootable.catalogWorkflow === "idle"
          }

          RowLayout {
            width: parent.width
            height: Style.space(62)
            spacing: Style.space(8)
            visible: root.showMore && bootable.catalogWorkflow === "idle"

            CompactProjectLink {
              Layout.fillWidth: true
              glyph: "󰇚"
              title: "Release"
              shortcut: "D"
              onTriggered: root.openUrl(root.releaseUrl)
            }

            CompactProjectLink {
              Layout.fillWidth: true
              glyph: ""
              title: "Source"
              onTriggered: root.openUrl(root.repositoryUrl)
            }

            CompactProjectLink {
              Layout.fillWidth: true
              glyph: "󰚩"
              title: "AI help"
              shortcut: "A"
              onTriggered: root.askAgent("diagnose and fix my Bootable installation")
            }
          }

          Text {
            width: parent.width
            text: bootable.catalogWorkflow === "idle"
              ? "C local  ·  S discover  ·  M more  ·  Esc close"
              : (bootable.downloading
                ? "Safe to close · download continues"
                : (catalogSearch.activeFocus ? "Enter search  ·  Esc leave search" : "Scroll to browse  ·  Esc close"))
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

  component DeviceStatusRow: Rectangle {
    implicitHeight: Style.space(42)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    border.width: 1

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: bootable.devicesError !== "" ? "󰅚" : (bootable.eligibleDeviceCount > 0 ? "󰕓" : "󰋌")
        color: bootable.devicesError !== "" ? root.urgent : (bootable.eligibleDeviceCount > 0 ? root.accent : root.dim)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        Layout.fillWidth: true
        text: bootable.removableStatusText
        color: bootable.eligibleDeviceCount > 0 ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      PanelActionButton {
        iconText: bootable.devicesLoading ? "󰔟" : "󰑐"
        tooltipText: bootable.devicesError !== "" ? "Retry drive check" : "Refresh removable drives"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: !bootable.devicesLoading && !bootable.writing
        onClicked: bootable.refreshDevices()
      }
    }
  }

  component SourceChoice: CursorSurface {
    id: sourceChoice
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property string shortcut: ""
    signal triggered()

    foreground: root.foreground
    implicitHeight: Style.space(62)
    height: implicitHeight
    opacity: enabled ? 1.0 : 0.45

    MouseArea {
      anchors.fill: parent
      enabled: sourceChoice.enabled
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: sourceChoice.triggered()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: sourceChoice.glyph
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: sourceChoice.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: sourceChoice.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        text: sourceChoice.shortcut
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  component CompactActionRow: CursorSurface {
    id: compactAction
    property string title: ""
    property string glyph: ""
    property string shortcut: ""
    signal triggered()

    foreground: root.foreground
    implicitHeight: Style.space(38)
    height: implicitHeight
    opacity: enabled ? 1.0 : 0.45

    MouseArea {
      anchors.fill: parent
      enabled: compactAction.enabled
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: compactAction.triggered()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)
      Text { text: compactAction.glyph; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
      Text {
        Layout.fillWidth: true
        text: compactAction.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text { text: compactAction.shortcut; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
      Text { text: "󰁔"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
    }
  }

  component CompactProjectLink: CursorSurface {
    id: projectLink
    property string glyph: ""
    property string title: ""
    property string shortcut: ""
    signal triggered()

    foreground: root.foreground
    implicitHeight: Style.space(62)
    height: implicitHeight

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: projectLink.triggered()
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: projectLink.glyph
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
      }

      Text {
        Layout.alignment: Qt.AlignHCenter
        text: projectLink.title + (projectLink.shortcut !== "" ? "  " + projectLink.shortcut : "")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
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
