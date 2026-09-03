import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model
import "QobuzStrings.js" as Strings

// What /api/status reports beyond playback: the daemon, the audio path and
// Qobuz Connect. Useful precisely when something is wrong — a DAC that did not
// open, bit-perfect silently disabled, the network down.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var daemon: playerState.daemon
  readonly property var audio: daemon ? (daemon.audio || {}) : ({})
  readonly property var qconnect: daemon ? (daemon.qconnect || {}) : ({})
  readonly property var errors: daemon ? (daemon.errors || {}) : ({})
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  spacing: Style.space(4)

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }

  function text(value, fallback) {
    if (value === null || value === undefined || String(value) === "") return fallback || t("word.dash")
    return String(value)
  }

  function yesNo(value) { return t(value === true ? "word.yes" : "word.no") }

  function uptimeLabel(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0))
    var d = Math.floor(s / 86400)
    var h = Math.floor((s % 86400) / 3600)
    var m = Math.floor((s % 3600) / 60)
    if (d > 0) return d + " d " + h + " h"
    if (h > 0) return h + " h " + m + " min"
    return m + " min"
  }

  function rateLabel(hz) {
    var n = Number(hz) || 0
    if (n <= 0) return t("word.dash")
    return (n > 1000 ? (Math.round(n / 100) / 10) : n) + " kHz"
  }

  Text {
    visible: !root.daemon
    width: parent.width
    text: root.t("status.noData")
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Repeater {
    model: root.daemon ? root.sections : []

    delegate: Column {
      required property var modelData

      width: root.width
      spacing: Style.space(2)
      bottomPadding: Style.space(10)

      PanelSectionHeader {
        text: modelData.label
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: modelData.rows

        delegate: Item {
          required property var modelData

          width: parent.width
          implicitHeight: Math.max(key.implicitHeight, value.implicitHeight) + Style.space(6)

          Text {
            id: key
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(200)
            text: modelData.key
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
          }

          Text {
            id: value
            anchors.left: key.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.value
            color: modelData.alert === true ? (root.bar ? root.bar.urgent : Color.urgent) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            textFormat: Text.PlainText
          }
        }
      }
    }
  }

  readonly property var sections: {
    if (!daemon) return []
    var errorRows = []
    for (var name in errors) {
      if (!Object.prototype.hasOwnProperty.call(errors, name)) continue
      if (errors[name] === null || errors[name] === undefined) continue
      errorRows.push({ key: name, value: String(errors[name]), alert: true })
    }
    if (!errorRows.length) errorRows.push({ key: t("status.errorsLabel"), value: t("status.noErrors") })

    return [
      {
        label: t("status.daemon"),
        rows: [
          { key: t("status.version"), value: root.text(daemon.version) + "  (API v" + daemon.apiVersion + ")" },
          { key: t("status.uptime"), value: root.uptimeLabel(daemon.uptime) },
          { key: t("status.network"), value: t(daemon.online ? "status.online" : "status.offline"), alert: !daemon.online },
          { key: t("status.session"), value: playerState.authState === "ok"
              ? t("status.signedIn") + (playerState.subscription ? " · " + playerState.subscription : "")
              : t("status.signedOut"), alert: playerState.authState !== "ok" },
          { key: t("status.host"), value: service ? service.host : t("word.dash") }
        ]
      },
      {
        label: t("status.audio"),
        rows: [
          { key: t("status.backend"), value: root.text(audio.backend) },
          { key: t("status.device"), value: root.text(audio.configured_device, t("status.deviceDefault")) },
          { key: t("status.devicePresent"), value: root.yesNo(audio.device_present), alert: audio.device_present !== true },
          { key: t("status.deviceOpen"), value: root.yesNo(audio.device_open) },
          { key: t("status.bitPerfect"), value: root.text(audio.bit_perfect, t("status.disabled")) },
          { key: t("status.format"), value: audio.bit_depth
              ? t("status.bits", audio.bit_depth, root.rateLabel(audio.sample_rate))
              : t("word.dash") }
        ]
      },
      {
        label: t("status.connect"),
        rows: [
          { key: t("status.connectName"), value: root.text(qconnect.device_name) },
          { key: t("status.connectEnabled"), value: root.yesNo(qconnect.enabled) },
          { key: t("status.connectState"), value: root.text(qconnect.state) },
          { key: t("status.connectSession"), value: root.yesNo(qconnect.session_active) }
        ]
      },
      { label: t("status.errors"), rows: errorRows }
    ]
  }
}
