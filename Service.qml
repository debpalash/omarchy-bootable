import QtQuick
import QtCore
import Quickshell.Io

Item {
  id: root

  property bool loading: false
  property bool guiInstalled: false
  property bool tuiInstalled: false
  property bool clientCapable: false
  property bool catalogCapable: false
  property bool helperInstalled: false
  property string version: "Not installed"
  property string error: ""
  readonly property bool installed: guiInstalled || tuiInstalled
  readonly property bool clientReady: tuiInstalled && clientCapable && helperInstalled

  property string workflow: "idle"
  property string sourcePath: ""
  property var imageReport: null
  property var devices: []
  property bool devicesLoading: false
  property string devicesError: ""
  property var selectedTarget: null
  property var writePlan: null
  property bool acknowledged: false
  property string operationMessage: "Choose an operating-system image to begin."
  property string operationError: ""
  property string progressPhase: ""
  property double progressCompleted: 0
  property double progressTotal: 0
  property bool progressKnown: false
  property bool writeTerminalEvent: false
  property string catalogWorkflow: "idle"
  property var catalog: []
  property string catalogQuery: ""
  property var selectedDistribution: null
  property var releases: []
  property string catalogMessage: ""
  property string catalogError: ""
  property string downloadDestination: ""
  property string downloadPhase: ""
  property double downloadCompleted: 0
  property double downloadTotal: 0
  property bool downloadKnown: false
  property bool downloadTerminalEvent: false
  property bool downloadSessionStarting: false
  property bool downloadCompletionHandled: false
  readonly property bool writing: workflow === "writing"
  readonly property bool downloading: catalogWorkflow === "downloading"
  readonly property bool catalogBusy: catalogWorkflow === "catalog-loading" || catalogWorkflow === "releases-loading" || downloading
  readonly property bool busy: writing || downloading || workflow === "inspecting" || workflow === "discovering" || workflow === "planning"
  readonly property bool canWrite: workflow === "review" && acknowledged && writePlan !== null && eligible(selectedTarget)
  readonly property int progressPercent: progressKnown && progressTotal > 0
    ? Math.max(0, Math.min(100, Math.round(progressCompleted * 100 / progressTotal))) : 0
  readonly property int downloadPercent: downloadKnown && downloadTotal > 0
    ? Math.max(0, Math.min(100, Math.round(downloadCompleted * 100 / downloadTotal))) : 0
  readonly property string appVersionLabel: {
    var detected = String(version || "").trim()
    var match = detected.match(/^bootable\s+(.+)$/i)
    if (match) return "APP · v" + String(match[1]).replace(/^v/i, "")
    return "APP · " + detected
  }
  readonly property var filteredCatalog: {
    var query = String(catalogQuery || "").trim().toLowerCase()
    var rows = []
    for (var index = 0; index < catalog.length; index++) {
      var item = catalog[index]
      if (catalogItemMatches(item, query)) rows.push(item)
      if (rows.length >= 30) break
    }
    return rows
  }
  readonly property int catalogMatchCount: {
    var query = String(catalogQuery || "").trim().toLowerCase()
    var count = 0
    for (var index = 0; index < catalog.length; index++) {
      if (catalogItemMatches(catalog[index], query)) count++
    }
    return count
  }
  readonly property string catalogResultText: {
    var query = String(catalogQuery || "").trim()
    if (query === "") return catalog.length + (catalog.length === 1 ? " distribution" : " distributions")
      + (catalog.length > 30 ? " · showing first 30" : "") + " · name, slug, or base family"
    if (catalogMatchCount === 0) return "No distributions match “" + query + "”"
    return catalogMatchCount + (catalogMatchCount === 1 ? " distribution matches “" : " distributions match “")
      + query + "”" + (catalogMatchCount > 30 ? " · showing first 30" : "") + " · name, slug, or base family"
  }
  readonly property int eligibleDeviceCount: {
    var count = 0
    for (var index = 0; index < devices.length; index++) {
      if (eligible(devices[index])) count++
    }
    return count
  }
  readonly property string removableStatusText: {
    if (devicesLoading) return "Checking removable drives…"
    if (devicesError !== "") return "Could not check removable drives"
    if (devices.length === 0) return "No removable drives connected"
    if (devices.length === 1 && eligibleDeviceCount === 1) return "1 removable drive ready"
    if (devices.length === eligibleDeviceCount) return devices.length + " removable drives ready"
    if (devices.length === 1) return "1 removable drive connected · none eligible"
    if (eligibleDeviceCount === 0) return devices.length + " removable drives connected · none eligible"
    return devices.length + " removable drives connected · " + eligibleDeviceCount + " ready"
  }

  function helperPath() {
    return Qt.resolvedUrl("bootable-status").toString().replace(/^file:\/\//, "")
  }

  function downloadSessionPath() {
    return Qt.resolvedUrl("bootable-download-session").toString().replace(/^file:\/\//, "")
  }

  function fileName(path) {
    var parts = String(path || "").split("/")
    return parts.length > 0 ? parts[parts.length - 1] : ""
  }

  function catalogFieldMatches(value, term) {
    var field = String(value || "").toLowerCase()
    if (term.length > 2) return field.indexOf(term) !== -1
    var words = field.split(/[^a-z0-9]+/)
    for (var index = 0; index < words.length; index++) {
      if (words[index].indexOf(term) === 0) return true
    }
    return false
  }

  function catalogItemMatches(item, query) {
    var normalized = String(query || "").trim().toLowerCase()
    if (normalized === "") return true
    var terms = normalized.split(/\s+/)
    var fields = [item && item.name || "", item && item.slug || "", item && item.based_on || ""]
    for (var termIndex = 0; termIndex < terms.length; termIndex++) {
      var matched = false
      for (var fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
        if (catalogFieldMatches(fields[fieldIndex], terms[termIndex])) {
          matched = true
          break
        }
      }
      if (!matched) return false
    }
    return true
  }

  function formatBytes(value) {
    var bytes = Number(value || 0)
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var unit = 0
    while (bytes >= 1024 && unit < units.length - 1) {
      bytes /= 1024
      unit++
    }
    var precision = unit === 0 || bytes >= 100 ? 0 : (bytes >= 10 ? 1 : 2)
    return bytes.toFixed(precision) + " " + units[unit]
  }

  function imageKind(report) {
    if (!report) return ""
    var kind = report.kind
    if (typeof kind === "string") {
      if (kind === "HybridIso") return "Hybrid bootable ISO"
      if (kind === "RawDiskImage") return "Raw disk image"
      if (kind === "OpticalIso") return "Optical-only ISO"
      return kind
    }
    if (kind && kind.WindowsInstaller !== undefined) return "Windows installer"
    if (kind && kind.CompressedDiskImage !== undefined) return "Compressed disk image"
    return "Boot image"
  }

  function deviceName(device) {
    if (!device) return ""
    var name = [device.vendor || "", device.model || ""].join(" ").trim()
    return name !== "" ? name : String(device.path || "Unknown device")
  }

  function eligible(device) {
    return device !== null && device !== undefined
      && device.removable === true && device.read_only !== true && device.system_disk !== true
  }

  function eligibility(device) {
    if (!device) return "Unavailable"
    if (device.system_disk === true) return "System disk · blocked"
    if (device.removable !== true) return "Internal disk · blocked"
    if (device.read_only === true) return "Read-only · blocked"
    return "Removable · eligible"
  }

  function refresh() {
    if (!statusProcess.running) {
      loading = true
      error = ""
      statusProcess.command = [helperPath()]
      statusProcess.running = true
    }
    if (clientReady && !writing && !downloading) refreshDevices()
  }

  function applyStatus(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      guiInstalled = data.guiInstalled === true
      tuiInstalled = data.tuiInstalled === true
      clientCapable = data.clientCapable === true
      catalogCapable = data.catalogCapable === true
      helperInstalled = data.helperInstalled === true
      version = String(data.version || (installed ? "Installed" : "Not installed"))
      error = ""
      if (clientReady && workflow !== "writing" && !downloading) refreshDevices()
      if (clientReady && downloading) checkDownloadSession()
    } catch (parseError) {
      guiInstalled = false
      tuiInstalled = false
      clientCapable = false
      catalogCapable = false
      helperInstalled = false
      version = "Status unavailable"
      error = "Could not read the local Bootable status."
    }
  }

  function chooseImage() {
    if (busy || pickerProcess.running) return
    operationError = ""
    pickerProcess.command = ["omarchy", "file", "select", "--title", "Choose an OS image", "--extensions", "iso img raw xz gz zst bz2"]
    pickerProcess.running = true
  }

  function openCatalog() {
    if (!clientReady || !catalogCapable || busy || catalogProcess.running) return
    catalog = []
    catalogQuery = ""
    selectedDistribution = null
    releases = []
    catalogError = ""
    catalogMessage = "Loading Bootable's distribution catalog…"
    catalogWorkflow = "catalog-loading"
    catalogProcess.command = ["bootable", "catalog", "--limit", "100", "--json"]
    catalogProcess.running = true
  }

  function closeCatalog() {
    if (catalogBusy) return
    catalogWorkflow = "idle"
    catalogError = ""
    selectedDistribution = null
    releases = []
  }

  function loadReleases(distribution) {
    if (!distribution || busy || releasesProcess.running) return
    selectedDistribution = distribution
    releases = []
    catalogError = ""
    catalogMessage = "Finding current ISO releases for " + String(distribution.name || distribution.slug) + "…"
    catalogWorkflow = "releases-loading"
    releasesProcess.command = ["bootable", "releases", String(distribution.slug), "--json"]
    releasesProcess.running = true
  }

  function backToCatalog() {
    if (catalogBusy) return
    catalogError = ""
    catalogWorkflow = "catalog"
  }

  function safeReleaseName(release) {
    var name = fileName(String(release && release.name || "bootable-image.iso").replace(/\\/g, "/"))
      .replace(/[^A-Za-z0-9._+() -]/g, "_").trim()
    return name === "" || name === "." || name === ".." ? "bootable-image.iso" : name
  }

  function downloadRelease(release, index) {
    if (!release || !selectedDistribution || busy || downloadSessionProcess.running) return
    var downloads = String(StandardPaths.writableLocation(StandardPaths.DownloadLocation) || "")
      .replace(/^file:\/\//, "")
    try {
      downloads = decodeURIComponent(downloads)
    } catch (decodeError) {
      // Keep Qt's original path if it contains a malformed escape sequence.
    }
    downloadDestination = downloads + "/" + safeReleaseName(release)
    downloadPhase = "Preparing"
    downloadCompleted = 0
    downloadTotal = Number(release.size || 0)
    downloadKnown = downloadTotal > 0
    downloadTerminalEvent = false
    downloadCompletionHandled = false
    downloadSessionStarting = true
    catalogError = ""
    catalogMessage = "Downloading and verifying " + safeReleaseName(release) + "…"
    catalogWorkflow = "downloading"
    downloadSessionProcess.action = "start"
    downloadSessionProcess.command = [downloadSessionPath(), "start", String(selectedDistribution.slug),
      String(index), downloadDestination]
    downloadSessionProcess.running = true
  }

  function consumeDownloadEvent(value) {
    if (!value) return
    if (value.event === "progress" && value.data) {
      downloadPhase = String(value.data.phase || "Downloading")
      downloadCompleted = Number(value.data.completed || 0)
      downloadTotal = Number(value.data.total || 0)
      downloadKnown = value.data.total !== null && value.data.total !== undefined && downloadTotal > 0
      catalogMessage = String(value.data.message || downloadPhase)
    } else if (value.event === "finished") {
      downloadTerminalEvent = true
      downloadPhase = "Finished"
      downloadCompleted = downloadTotal
      catalogMessage = "Download verified. Inspecting the image…"
    } else if (value.event === "failed") {
      downloadTerminalEvent = true
      catalogError = String(value.data && value.data.message || "Bootable could not download that image.")
    }
  }

  function checkDownloadSession() {
    if (downloadSessionStatusProcess.running) return
    downloadSessionStatusProcess.command = [downloadSessionPath(), "status"]
    downloadSessionStatusProcess.running = true
  }

  function clearDownloadSession() {
    if (downloadSessionProcess.running) return
    downloadSessionProcess.action = "clear"
    downloadSessionProcess.command = [downloadSessionPath(), "clear"]
    downloadSessionProcess.running = true
  }

  function applyDownloadSessionStatus(raw) {
    var data
    try {
      data = JSON.parse(String(raw || ""))
    } catch (parseError) {
      return
    }

    if (data.destination) downloadDestination = String(data.destination)
    if (data.event) consumeDownloadEvent(data.event)

    if (data.active === true) {
      downloadSessionStarting = false
      downloadCompletionHandled = false
      if (catalogWorkflow !== "catalog-error") catalogWorkflow = "downloading"
      if (!data.event) {
        downloadPhase = "Preparing"
        catalogMessage = "Bootable is preparing the detached download…"
      }
      return
    }

    if (data.event && data.event.event === "finished") {
      if (!clientReady || downloadCompletionHandled) {
        catalogWorkflow = "downloading"
        return
      }
      downloadCompletionHandled = true
      downloadSessionStarting = false
      clearDownloadSession()
      catalogWorkflow = "idle"
      inspectImage(downloadDestination)
      return
    }

    if (data.event && data.event.event === "failed") {
      downloadCompletionHandled = true
      downloadSessionStarting = false
      if (catalogError === "") catalogError = String(data.error || "Bootable could not download that image.")
      catalogWorkflow = "catalog-error"
      clearDownloadSession()
      return
    }

    if (downloadSessionStarting) return
    if (catalogWorkflow === "downloading" && !downloadCompletionHandled) {
      catalogError = String(data.error || "The detached Bootable download stopped without a completion event.")
      catalogWorkflow = "catalog-error"
    }
  }

  function inspectImage(path) {
    if (!clientReady || inspectProcess.running || writing) return
    sourcePath = String(path || "")
    imageReport = null
    selectedTarget = null
    writePlan = null
    acknowledged = false
    operationError = ""
    operationMessage = "Inspecting " + fileName(sourcePath) + "…"
    workflow = "inspecting"
    inspectProcess.command = ["bootable", "inspect", sourcePath, "--json"]
    inspectProcess.running = true
  }

  function refreshDevices() {
    if (!clientReady || devicesProcess.running || writing || downloading) return
    selectedTarget = null
    writePlan = null
    acknowledged = false
    devices = []
    devicesLoading = true
    devicesError = ""
    operationError = ""
    workflow = sourcePath === "" ? "idle" : "discovering"
    operationMessage = "Looking for removable drives…"
    devicesProcess.command = ["bootable", "devices", "--json"]
    devicesProcess.running = true
  }

  function selectDevice(device) {
    if (busy || !eligible(device)) return
    selectedTarget = device
    writePlan = null
    acknowledged = false
    operationError = ""
    operationMessage = "Building a safe erase plan…"
    workflow = "planning"
    planProcess.command = ["bootable", "plan", sourcePath, String(device.id), "--json"]
    planProcess.running = true
  }

  function setAcknowledged(value) {
    if (workflow === "review" && !writing) acknowledged = value === true
  }

  function startWrite() {
    if (!canWrite || writeProcess.running) return
    if (!writePlan.target || String(writePlan.target.id) !== String(selectedTarget.id)
        || String(writePlan.confirmation_phrase || "") === "") {
      fail("The reviewed target changed. Refresh drives and review the plan again.")
      return
    }
    progressPhase = "Preparing"
    progressCompleted = 0
    progressTotal = Number(writePlan.image && writePlan.image.size || 0)
    progressKnown = progressTotal > 0
    operationError = ""
    operationMessage = "Waiting for administrator authentication…"
    writeTerminalEvent = false
    workflow = "writing"
    writeProcess.command = ["bootable", "write", sourcePath, String(selectedTarget.id),
      "--confirm", String(writePlan.confirmation_phrase), "--json-progress"]
    writeProcess.running = true
  }

  function consumeWriteLine(line) {
    var value
    try {
      value = JSON.parse(String(line || ""))
    } catch (parseError) {
      return
    }
    if (value.event === "progress" && value.data) {
      progressPhase = String(value.data.phase || "Writing")
      progressCompleted = Number(value.data.completed || 0)
      progressTotal = Number(value.data.total || 0)
      progressKnown = value.data.total !== null && value.data.total !== undefined && progressTotal > 0
      operationMessage = String(value.data.message || progressPhase)
    } else if (value.event === "finished") {
      writeTerminalEvent = true
      progressPhase = "Finished"
      progressCompleted = progressTotal
      operationMessage = "The image was written and verified successfully."
      workflow = "finished"
    } else if (value.event === "failed") {
      writeTerminalEvent = true
      fail(String(value.data && value.data.message || "Bootable could not finish the write."))
    }
  }

  function fail(message) {
    operationError = String(message || "Bootable could not complete the operation.")
    operationMessage = "Nothing else will be written."
    workflow = "error"
  }

  function retry() {
    if (writing) return
    if (sourcePath === "") {
      workflow = "idle"
      chooseImage()
    } else {
      refreshDevices()
    }
  }

  function resetWorkflow() {
    if (writing) return
    sourcePath = ""
    imageReport = null
    selectedTarget = null
    writePlan = null
    acknowledged = false
    operationError = ""
    operationMessage = "Choose an operating-system image to begin."
    progressPhase = ""
    progressCompleted = 0
    progressTotal = 0
    progressKnown = false
    workflow = "idle"
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode === 0) root.applyStatus(statusOutput.text)
      else root.error = String(statusError.text || "Could not inspect the Bootable installation.").trim()
    }
  }

  Process {
    id: pickerProcess
    running: false
    command: []
    stdout: StdioCollector { id: pickerOutput; waitForEnd: true }
    stderr: StdioCollector { id: pickerError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.inspectImage(String(pickerOutput.text || "").trim())
      else if (exitCode === 2) root.fail(String(pickerError.text || "The file chooser could not open.").trim())
    }
  }

  Process {
    id: catalogProcess
    running: false
    command: []
    stdout: StdioCollector { id: catalogOutput; waitForEnd: true }
    stderr: StdioCollector { id: catalogErrorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.catalogError = String(catalogErrorOutput.text || "Bootable could not load the distribution catalog.").trim()
        root.catalogWorkflow = "catalog-error"
        return
      }
      try {
        var rows = JSON.parse(String(catalogOutput.text || "[]"))
        root.catalog = Array.isArray(rows) ? rows : []
        root.catalogWorkflow = "catalog"
        root.catalogMessage = root.catalog.length === 0 ? "No distributions returned." : "Choose a distribution."
      } catch (parseError) {
        root.catalogError = "Bootable returned an invalid distribution catalog."
        root.catalogWorkflow = "catalog-error"
      }
    }
  }

  Process {
    id: releasesProcess
    running: false
    command: []
    stdout: StdioCollector { id: releasesOutput; waitForEnd: true }
    stderr: StdioCollector { id: releasesErrorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.catalogError = String(releasesErrorOutput.text || "Bootable could not resolve ISO releases.").trim()
        root.catalogWorkflow = "catalog-error"
        return
      }
      try {
        var rows = JSON.parse(String(releasesOutput.text || "[]"))
        root.releases = Array.isArray(rows) ? rows : []
        root.catalogWorkflow = "releases"
        root.catalogMessage = root.releases.length === 0 ? "No ISO releases found." : "Choose an ISO to download and verify."
      } catch (parseError) {
        root.catalogError = "Bootable returned an invalid release list."
        root.catalogWorkflow = "catalog-error"
      }
    }
  }

  Process {
    id: downloadSessionProcess
    property string action: ""
    running: false
    command: []
    stdout: StdioCollector { id: downloadSessionOutput; waitForEnd: true }
    stderr: StdioCollector { id: downloadSessionError; waitForEnd: true }
    onExited: function(exitCode) {
      var completedAction = action
      action = ""
      if (completedAction !== "start") return
      root.downloadSessionStarting = false
      if (exitCode !== 0) {
        root.catalogError = String(downloadSessionError.text || "Could not start the detached Bootable download.").trim()
        root.catalogWorkflow = "catalog-error"
        return
      }
      root.checkDownloadSession()
    }
  }

  Process {
    id: downloadSessionStatusProcess
    running: false
    command: []
    stdout: StdioCollector { id: downloadSessionStatusOutput; waitForEnd: true }
    stderr: StdioCollector { id: downloadSessionStatusError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyDownloadSessionStatus(downloadSessionStatusOutput.text)
      else if (root.downloading) {
        root.catalogError = String(downloadSessionStatusError.text || "Could not restore the Bootable download status.").trim()
        root.catalogWorkflow = "catalog-error"
      }
    }
  }

  Timer {
    interval: 750
    repeat: true
    running: root.downloading || root.downloadSessionStarting
    onTriggered: root.checkDownloadSession()
  }

  Process {
    id: inspectProcess
    running: false
    command: []
    stdout: StdioCollector { id: inspectOutput; waitForEnd: true }
    stderr: StdioCollector { id: inspectError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.fail(String(inspectError.text || "Bootable could not inspect that image.").trim())
        return
      }
      try {
        root.imageReport = JSON.parse(String(inspectOutput.text || ""))
        root.operationMessage = "Image inspected. Choose a removable target."
        root.refreshDevices()
      } catch (parseError) {
        root.fail("Bootable returned an invalid image report.")
      }
    }
  }

  Process {
    id: devicesProcess
    running: false
    command: []
    stdout: StdioCollector { id: devicesOutput; waitForEnd: true }
    stderr: StdioCollector { id: deviceErrorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.devicesLoading = false
      if (exitCode !== 0) {
        root.devicesError = String(deviceErrorOutput.text || "Bootable could not discover removable drives.").trim()
        if (root.sourcePath !== "" && root.imageReport !== null) root.fail(root.devicesError)
        else {
          root.workflow = "idle"
          root.operationMessage = "Choose an operating-system image to begin."
        }
        return
      }
      try {
        var rows = JSON.parse(String(devicesOutput.text || "[]"))
        root.devices = Array.isArray(rows) ? rows : []
        root.devicesError = ""
        if (root.sourcePath === "" || root.imageReport === null) {
          root.workflow = "idle"
          root.operationMessage = "Choose an operating-system image to begin."
        } else {
          root.workflow = "target"
          root.operationMessage = root.devices.length === 0
            ? "No removable drive detected. Connect one, then refresh."
            : "Choose a removable drive. Internal and system disks stay blocked."
        }
      } catch (parseError) {
        root.devicesError = "Bootable returned an invalid device list."
        if (root.sourcePath !== "" && root.imageReport !== null) root.fail(root.devicesError)
      }
    }
  }

  Process {
    id: planProcess
    running: false
    command: []
    stdout: StdioCollector { id: planOutput; waitForEnd: true }
    stderr: StdioCollector { id: planError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.fail(String(planError.text || "Bootable refused this write plan.").trim())
        return
      }
      try {
        var plan = JSON.parse(String(planOutput.text || ""))
        if (!plan.target || !root.eligible(plan.target)
            || !root.selectedTarget || String(plan.target.id) !== String(root.selectedTarget.id)) {
          root.fail("Bootable did not return the exact eligible target that was selected.")
          return
        }
        root.writePlan = plan
        root.acknowledged = false
        root.workflow = "review"
        root.operationMessage = "Review the erase plan and acknowledge it before writing."
      } catch (parseError) {
        root.fail("Bootable returned an invalid write plan.")
      }
    }
  }

  Process {
    id: writeProcess
    running: false
    command: []
    stdout: SplitParser { onRead: function(line) { root.consumeWriteLine(line) } }
    stderr: StdioCollector { id: writeError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0 && !root.writeTerminalEvent) {
        root.writeTerminalEvent = true
        root.progressPhase = "Finished"
        root.progressCompleted = root.progressTotal
        root.operationMessage = "The image was written and verified successfully."
        root.workflow = "finished"
      } else if (exitCode !== 0 && !root.writeTerminalEvent) {
        root.fail(String(writeError.text || "Bootable could not finish the write.").trim())
      }
    }
  }

  Component.onCompleted: {
    checkDownloadSession()
    refresh()
  }
}
