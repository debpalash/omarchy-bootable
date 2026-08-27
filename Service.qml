import QtQuick
import Quickshell.Io

Item {
  id: root

  property bool loading: false
  property bool guiInstalled: false
  property bool tuiInstalled: false
  property string version: "Not installed"
  property string error: ""
  readonly property bool installed: guiInstalled || tuiInstalled

  function helperPath() {
    return Qt.resolvedUrl("bootable-status").toString().replace(/^file:\/\//, "")
  }

  function refresh() {
    if (statusProcess.running) return
    loading = true
    error = ""
    statusProcess.command = [helperPath()]
    statusProcess.running = true
  }

  function apply(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      guiInstalled = data.guiInstalled === true
      tuiInstalled = data.tuiInstalled === true
      version = String(data.version || (installed ? "Installed" : "Not installed"))
      error = ""
    } catch (parseError) {
      guiInstalled = false
      tuiInstalled = false
      version = "Status unavailable"
      error = "Could not read the local Bootable status."
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode === 0) root.apply(statusOutput.text)
      else root.error = String(statusError.text || "Could not inspect the Bootable installation.").trim()
    }
  }

  Component.onCompleted: refresh()
}
