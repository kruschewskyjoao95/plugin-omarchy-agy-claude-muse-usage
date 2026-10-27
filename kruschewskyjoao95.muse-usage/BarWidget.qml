import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Codex 5-hour and weekly usage, read from Omarchy's local usage record.
BarWidget {
  id: root
  moduleName: "kruschewskyjoao95.muse-usage"

  property var record: null
  property string errorText: ""
  property bool busy: false
  // Bumped once a minute so the "resets in" text in the tooltip stays current.
  property int nowTick: 0

  readonly property string recordPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "") + "/.local/state") + "/omarchy/agents/usage/codex.json"
  readonly property int pollMs: 180000

  function limit(index) {
    var entry = root.record && root.record.limits ? root.record.limits[index] : null
    return entry ? { percent: entry.percent * 100, resetsAt: entry.resetsAt } : null
  }
  function windowPercent() { var value = limit(0); return value ? value.percent : null }
  function weeklyPercent() { var value = limit(1); return value ? value.percent : null }

  function fmtPct(value) {
    return value === null || value === undefined ? "--" : Number(value).toFixed(1) + "%"
  }

  function untilText(iso) {
    root.nowTick // re-evaluate once a minute
    if (!iso) return ""
    var ms = Date.parse(iso) - Date.now()
    if (ms <= 0) return "reset due"
    var mins = Math.round(ms / 60000)
    var hours = Math.floor(mins / 60)
    var rest = mins % 60
    return hours > 0 ? "in " + hours + "h " + rest + "m" : "in " + rest + "m"
  }

  function clockText(iso) {
    if (!iso) return ""
    return Qt.formatDateTime(new Date(iso), "ddd dd/MM HH:mm")
  }

  // Percent and reset time for each window, read by the popup panel.
  readonly property color accentColor: "#0071f1"
  readonly property var sessionUsage: limit(0)
  readonly property var weeklyUsage: limit(1)

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
    if (!root.record) return root.busy ? "Codex ..." : "Codex --"
    return "Codex " + fmtPct(windowPercent()) + " | 7d " + fmtPct(weeklyPercent())
  }

  function tooltipText() {
    if (!root.record) return root.errorText || "Codex usage not loaded yet"
    var lines = []
    var session = limit(0), weekly = limit(1)
    if (session) lines.push("5-hour  " + fmtPct(session.percent) + "  resets " + clockText(session.resetsAt) + " (" + untilText(session.resetsAt) + ")")
    if (weekly) lines.push("Weekly  " + fmtPct(weekly.percent) + "  resets " + clockText(weekly.resetsAt) + " (" + untilText(weekly.resetsAt) + ")")
    if (root.errorText) lines.push(root.errorText)
    lines.push("Right-click: refresh now")
    return lines.join("\n")
  }

  function applyRecord(raw) {
    root.busy = false
    if (!String(raw || "").trim()) return
    var parsed = null
    try {
      parsed = JSON.parse(raw)
    } catch (error) {
      root.record = null
      root.errorText = "Codex usage record returned invalid JSON"
      return
    }
    root.record = parsed.ready ? parsed : null
    root.errorText = parsed.usageStatusText || ""
  }

  function refresh(force) {
    if (refreshProc.running) return
    root.busy = true
    refreshProc.command = force ? ["omarchy-agent-usage-update", "--force", "codex"] : ["omarchy-agent-usage-update", "codex"]
    refreshProc.running = true
  }

  Component.onCompleted: refresh(false)

  FileView {
    id: fileView
    path: root.recordPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyRecord(text())
    onFileChanged: reload()
    onLoadFailed: root.record = null
  }

  Timer {
    interval: root.pollMs
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

  Process {
    id: refreshProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRecord(text)
    }
    onExited: function(code) {
      root.busy = false
      fileView.reload()
      if (code !== 0) root.errorText = "Codex usage update failed (exit " + code + ")"
    }
  }

  // The shell's module row has no spacing, so each pill leaves its own gap.
  readonly property real pillGap: Style.spaceReal(2)

  implicitWidth: button.implicitWidth + pillGap
  implicitHeight: button.implicitHeight

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
