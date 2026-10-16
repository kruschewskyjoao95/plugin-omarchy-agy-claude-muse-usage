import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Popup opened by clicking the Claude bar label: a 5-hour bar and a 7-day bar,
// each with the percent used and the time left until that window resets.
// The numbers live on the bar widget (hostWidget); this panel only renders them.
Panel {
  id: root
  moduleName: "kruschewskyjoao95.claude-usage-bar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color accentColor: "#d46c4d"
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(400))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: body
        width: parent.width
        spacing: Style.space(16)

        PanelHero {
          title: "Claude Code"
          meta: "Limites do Claude"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
        }

        PanelSeparator { foreground: root.contentForeground }

        UsageBar {
          heading: "5 HORAS"
          usage: hostWidget ? hostWidget.sessionUsage : null
        }

        UsageBar {
          heading: "7 DIAS"
          usage: hostWidget ? hostWidget.weeklyUsage : null
        }

        Item {
          width: parent.width
          implicitHeight: refreshButton.implicitHeight

          Button {
            id: refreshButton
            anchors.horizontalCenter: parent.horizontalCenter
            text: hostWidget && hostWidget.busy ? "atualizando…" : "↻ atualizar"
            fontFamily: root.contentFontFamily
            bordered: true
            background: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
            onClicked: if (hostWidget) hostWidget.refresh(true)
          }
        }
      }
    }
  }

  // One window: heading, time left to reset, a bar filled by the used share,
  // and the used percent underneath.
  component UsageBar: Column {
    id: usageBar
    required property string heading
    required property var usage

    readonly property real fraction: usage && isFinite(usage.percent) ? Math.max(0, Math.min(100, usage.percent)) / 100 : 0
    readonly property string pctText: hostWidget ? hostWidget.fmtPct(usage ? usage.percent : null) : "--"
    readonly property string leftText: hostWidget && usage ? hostWidget.leftText(usage.resetsAt) : "--"

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(headingText.implicitHeight, leftLabel.implicitHeight)

      Text {
        id: headingText
        textFormat: Text.PlainText
        text: usageBar.heading
        color: Qt.darker(root.contentForeground, 1.4)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: leftLabel
        textFormat: Text.PlainText
        text: "faltam " + usageBar.leftText
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Rectangle {
      width: parent.width
      height: Style.space(10)
      radius: height / 2
      color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.16)

      Rectangle {
        height: parent.height
        radius: parent.radius
        width: parent.width * usageBar.fraction
        color: root.accentColor
      }
    }

    Text {
      textFormat: Text.PlainText
      text: usageBar.pctText + " usado"
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }
}
