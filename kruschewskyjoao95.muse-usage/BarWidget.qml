import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// kruschewskyjoao95.muse-usage bar widget: Muse 5-hour and weekly usage.
// The collector caches its last live reading, so the poll below is cheap.
// A live Muse turn only runs once that cache is older than 30 minutes, a
// window has reset, or the user right-clicks to force a refresh.
BarWidget {
  id: root
  moduleName: "kruschewskyjoao95.muse-usage"

  property var record: null
  property string errorText: ""
  property bool busy: false
  // Bumped once a minute so the "resets in" text in the tooltip stays current.
  property int nowTick: 0

  readonly property string helperPath: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kruschewskyjoao95.muse-usage/bin/omarchy-muse-usage"
  readonly property int pollMs: 3600000

  function windowPercent() { return root.record && root.record.window ? root.record.window.usedPercent : null }
  function weeklyPercent() { return root.record && root.record.weekly ? root.record.weekly.usedPercent : null }

  function fmtPct(value) {
    return value === null || value === undefined ? "--" : value + "%"
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
  readonly property var sessionUsage: root.record && root.record.window
    ? { percent: root.record.window.usedPercent, resetsAt: root.record.window.resetsAt } : null
  readonly property var weeklyUsage: root.record && root.record.weekly
    ? { percent: root.record.weekly.usedPercent, resetsAt: root.record.weekly.resetsAt } : null

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
    if (!root.record) return root.busy ? " Muse ..." : " Muse --"
    return " Muse " + fmtPct(windowPercent()) + " | 7d " + fmtPct(weeklyPercent())
  }

  function tooltipText() {
    if (!root.record) return root.errorText || "Muse usage not loaded yet"
    var lines = []
    if (root.record.window)
      lines.push("5-hour  " + fmtPct(windowPercent()) + "  resets " + clockText(root.record.window.resetsAt)
        + " (" + untilText(root.record.window.resetsAt) + ")")
    if (root.record.weekly)
      lines.push("Weekly  " + fmtPct(weeklyPercent()) + "  resets " + clockText(root.record.weekly.resetsAt)
        + " (" + untilText(root.record.weekly.resetsAt) + ")")
    if (root.errorText) lines.push(root.errorText)
    lines.push("Right-click: refresh now (runs one Muse turn)")
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
      root.errorText = "Muse collector returned invalid JSON"
      return
    }
    root.record = parsed.ready ? parsed : null
    root.errorText = parsed.error || ""
  }

  function refresh(force) {
    if (refreshProc.running) return
    root.busy = true
    refreshProc.command = force ? [root.helperPath, "--force"] : [root.helperPath, "--max-age", "3600"]
    refreshProc.running = true
  }

  Component.onCompleted: refresh(false)

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
      if (code === 0) return
      root.busy = false
      root.errorText = "Muse collector failed (exit " + code + ")"
    }
  }

  // The shell's module row has no spacing, so each pill leaves its own gap.
  readonly property real pillGap: Style.spaceReal(4)

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

  // Blue background: this one takes white text, since dark text would be hard to read on it.
  Rectangle {
    anchors.fill: parent
    anchors.rightMargin: root.pillGap
    color: "#0071f1"
    radius: 6
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    anchors.rightMargin: root.pillGap
    bar: root.bar
    text: root.vertical ? "" : root.barText()
    tooltipText: root.tooltipText()
    foreground: "#ffffff"
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh(true)
      else root.togglePanel()
    }
  }
}
