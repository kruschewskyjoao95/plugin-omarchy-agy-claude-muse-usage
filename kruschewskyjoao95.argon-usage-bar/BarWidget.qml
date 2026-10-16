import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Argon usage in the bar: "Argon <days to weekly reset> <weekly%>".
// Runs the collector from jesseburlamaque.antigravity-usage every 3 minutes.
// Since Argon only has a 7-day rolling limit (no 5-hour quota), only the weekly
// window is shown.
BarWidget {
  id: root
  moduleName: "kruschewskyjoao95.argon-usage-bar"

  property var limits: []
  property bool ready: false
  property bool busy: false
  property int nowTick: 0

  readonly property string collectorPath: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/jesseburlamaque.antigravity-usage/bin/omarchy-agent-usage-antigravity"

  // Find the Argon weekly limit (matches exact group or any argon group).
  function argonLimit() {
    for (var i = 0; i < root.limits.length; i++) {
      var entry = root.limits[i]
      var g = String(entry.group || "").toLowerCase()
      var gn = String(entry.groupName || "").toLowerCase()
      if (g === "gemini-argon-wtu-weekly" || g.indexOf("argon") !== -1 || gn.indexOf("argon") !== -1) {
        return {
          percent: entry.percent * 100,
          resetsAt: entry.resetsAt,
          burnRateText: entry.burnRateText || "",
          forecastText: entry.forecastText || ""
        }
      }
    }
    return null
  }

  function fmtPct(value) {
    if (value === null || value === undefined || isNaN(value)) return "--"
    return (value < 1 && value > 0 ? Number(value).toFixed(1) : Math.round(value)) + "%"
  }

  // Whole days until the reset, or hours when the reset is under a day away.
  function resetText(iso) {
    root.nowTick
    if (!iso) return "--"
    var hours = (Date.parse(iso) - Date.now()) / 3600000
    if (hours <= 0) return "reset"
    if (hours < 24) return Math.ceil(hours) + "h"
    return Math.floor(hours / 24) + "d"
  }

  // Percent and reset time for the weekly window, read by the popup panel.
  readonly property color accentColor: "#38bdf8"
  readonly property var weeklyUsage: argonLimit()

  // Time left until a reset, e.g. "4h 05m" or "3d 04h" (the popup shows it).
  function leftText(iso) {
    root.nowTick
    var reset = Date.parse(String(iso || "").replace(/(\.\d{3})\d+/, "$1"))
    if (isNaN(reset)) return "--"
    var mins = Math.round((reset - Date.now()) / 60000)
    if (mins <= 0) return "reset"
    var days = Math.floor(mins / 1440)
    var hours = Math.floor((mins % 1440) / 60)
    var rest = mins % 60
    var pad = function(n) { return n < 10 ? "0" + n : "" + n }
    if (days > 0) return days + "d " + pad(hours) + "h"
    return hours + "h " + pad(rest) + "m"
  }

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

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  function barText() {
    if (root.vertical) return ""
    if (!root.ready) return root.busy ? " Argon ..." : " Argon --"
    var weekly = argonLimit()
    return " Argon " + resetText(weekly ? weekly.resetsAt : "") + " " + fmtPct(weekly ? weekly.percent : null)
  }

  function tooltipText() {
    var lines = []
    if (root.ready) {
      var weekly = argonLimit()
      if (weekly) {
        lines.push("Weekly (7d)  " + fmtPct(weekly.percent) + "  resets " + resetText(weekly.resetsAt))
        if (weekly.forecastText) lines.push(weekly.forecastText)
      } else {
        lines.push("Argon quota not found")
      }
    } else {
      lines.push("Argon usage not available yet")
    }
    lines.push("Right-click: refresh now")
    return lines.join("\n")
  }

  function applyRecord(raw) {
    root.busy = false
    try {
      var parsed = JSON.parse(raw)
      root.limits = parsed.limits || []
      root.ready = parsed.ready !== false && root.limits.length > 0
    } catch (error) {
      root.ready = false
    }
  }

  function refresh(force) {
    if (usageProc.running) return
    root.busy = true
    usageProc.command = force ? [root.collectorPath, "--force"] : [root.collectorPath]
    usageProc.running = true
  }

  // The shell's module row has no spacing, so each pill leaves its own gap.
  readonly property real pillGap: Style.spaceReal(4)

  implicitWidth: button.implicitWidth + pillGap
  implicitHeight: button.implicitHeight

  Process {
    id: usageProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRecord(text)
    }
    onExited: function(code) {
      root.busy = false
      if (code !== 0) root.ready = false
    }
  }

  Component.onCompleted: refresh(false)

  Timer {
    interval: 180000
    running: true
    repeat: true
    onTriggered: root.refresh(false)
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.nowTick++
  }

  // Click popup with the 7-day bar (Panel.qml).
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

  // Background behind the label.
  Rectangle {
    anchors.fill: parent
    anchors.rightMargin: root.pillGap
    color: "#38bdf8"
    radius: 6
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    anchors.rightMargin: root.pillGap
    bar: root.bar
    text: root.vertical ? "" : root.barText()
    tooltipText: root.tooltipText()
    foreground: "#1f1a12"
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh(true)
      else root.togglePanel()
    }
  }
}
