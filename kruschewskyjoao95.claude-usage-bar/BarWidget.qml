import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Claude usage in the bar: "Claude <5h%> | <days to weekly reset> <weekly%>".
// Reads the record that omarchy-agent-usage-update writes for Claude Code, so
// it costs no quota. The Omarchy agents panel keeps that record fresh; this
// widget also asks for a refresh every 5 minutes.
BarWidget {
  id: root
  moduleName: "kruschewskyjoao95.claude-usage-bar"

  property var record: null
  property bool busy: false
  property int nowTick: 0

  readonly property string recordPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state") + "/omarchy/agents/usage/claude.json"

  // The record stores each limit as a 0-1 fraction (0.08 means 8%), so scale
  // it here; the bar and tooltip work in whole percents.
  function limit(index) {
    var entry = root.record && root.record.limits ? root.record.limits[index] : null
    if (!entry) return null
    return { percent: entry.percent * 100, resetsAt: entry.resetsAt }
  }

  function fmtPct(value) {
    if (value === null || value === undefined || isNaN(value)) return "--"
    return (value < 1 ? Number(value).toFixed(1) : Math.round(value)) + "%"
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

  // Percent and reset time for each window, read by the popup panel.
  readonly property color accentColor: "#d46c4d"
  readonly property var sessionUsage: root.limit(0)
  readonly property var weeklyUsage: root.limit(1)

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
    if (!root.record) return root.busy ? "Claude ..." : "Claude --"
    var session = root.limit(0)
    var weekly = root.limit(1)
    return "Claude " + fmtPct(session ? session.percent : null)
      + " | " + resetText(weekly ? weekly.resetsAt : "") + " " + fmtPct(weekly ? weekly.percent : null)
  }

  function tooltipText() {
    var lines = []
    if (root.record) {
      var session = root.limit(0)
      var weekly = root.limit(1)
      if (session) lines.push("5-hour  " + fmtPct(session.percent) + "  resets " + resetText(session.resetsAt))
      if (weekly) lines.push("Weekly  " + fmtPct(weekly.percent) + "  resets " + resetText(weekly.resetsAt))
      if (root.record.tierLabel) lines.push("Plan: " + root.record.tierLabel)
      if (root.record.usageStatusText) lines.push(root.record.usageStatusText)
    } else {
      lines.push("Claude usage not available yet")
    }
    lines.push("Right-click: refresh now")
    return lines.join("\n")
  }

  function applyRecord(raw) {
    root.busy = false
    try {
      root.record = JSON.parse(raw)
    } catch (error) {
      root.record = null
    }
  }

  function refresh(force) {
    if (updateProc.running) return
    root.busy = true
    updateProc.command = force ? ["omarchy-agent-usage-update", "--force", "claude"] : ["omarchy-agent-usage-update", "claude"]
    updateProc.running = true
  }

  // The shell's module row has no spacing, so each pill leaves its own gap.
  readonly property real pillGap: Style.spaceReal(2)

  implicitWidth: button.implicitWidth + pillGap
  implicitHeight: button.implicitHeight

  FileView {
    id: fileView
    path: root.recordPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyRecord(text())
    onFileChanged: reload()
    onLoadFailed: root.record = null
  }

  Process {
    id: updateProc
    onExited: function(code) {
      root.busy = false
      fileView.reload()
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

  // Click popup with the 5-hour and 7-day bars (Panel.qml).
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

  // Light floating chip: thin, borderless, half-transparent accent. It never
  // fills the bar height; the button keeps the full slot as its click area.
  readonly property real chipHeight: Math.max(12, height - Style.spaceReal(10))
  readonly property color softAccent: {
    var c = Qt.lighter(root.accentColor, 1.35)
    return Qt.rgba(c.r, c.g, c.b, 1.0)
  }

  Rectangle {
    width: parent.width - root.pillGap
    height: root.chipHeight
    anchors.centerIn: parent
    visible: !root.vertical
    radius: height / 2
    color: Qt.rgba(root.softAccent.r, root.softAccent.g, root.softAccent.b, 0.15)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    anchors.rightMargin: root.pillGap
    bar: root.bar
    text: root.vertical ? "" : root.barText()
    tooltipText: root.tooltipText()
    foreground: root.softAccent
    fontSize: Style.font.bodySmall
    horizontalMargin: 7
    verticalPadding: 6
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh(true)
      else root.togglePanel()
    }
  }
}
