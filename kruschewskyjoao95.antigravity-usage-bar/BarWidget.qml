import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Antigravity usage in the bar: "Antigravity <5h%> | <days to weekly reset> <weekly%>".
// Runs the collector from kruschewskyjoao95's sibling plugin
// (jesseburlamaque.antigravity-usage) every 5 minutes. It reads local files,
// so it costs no quota.
BarWidget {
  id: root
  moduleName: "kruschewskyjoao95.antigravity-usage-bar"

  property var limits: []
  property bool ready: false
  property bool busy: false
  property int nowTick: 0

  readonly property string collectorPath: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/jesseburlamaque.antigravity-usage/bin/omarchy-agent-usage-antigravity"

  // The collector stores each limit as a 0-1 fraction (0.498 means 49.8%),
  // so scale it here.
  function limitFor(group) {
    for (var i = 0; i < root.limits.length; i++) {
      var entry = root.limits[i]
      if (entry.group === group) return { percent: entry.percent * 100, resetsAt: entry.resetsAt }
    }
    return null
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
  readonly property color accentColor: "#5fa88c"
  readonly property var sessionUsage: limitFor("gemini-5h")
  readonly property var weeklyUsage: limitFor("gemini-weekly")

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
    if (!root.ready) return root.busy ? "Agy ..." : "Agy --"
    var session = limitFor("gemini-5h")
    var weekly = limitFor("gemini-weekly")
    return "Agy " + fmtPct(session ? session.percent : null)
      + " | " + resetText(weekly ? weekly.resetsAt : "") + " " + fmtPct(weekly ? weekly.percent : null)
  }

  function tooltipText() {
    var lines = []
    if (root.ready) {
      var session = limitFor("gemini-5h")
      var weekly = limitFor("gemini-weekly")
      if (session) lines.push("5-hour  " + fmtPct(session.percent) + "  resets " + resetText(session.resetsAt))
      if (weekly) lines.push("Weekly  " + fmtPct(weekly.percent) + "  resets " + resetText(weekly.resetsAt))
    } else {
      lines.push("Agy usage not available yet")
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
  readonly property real pillGap: Style.spaceReal(2)

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
