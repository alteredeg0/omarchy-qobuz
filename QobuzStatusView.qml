import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

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

  function text(value, fallback) {
    if (value === null || value === undefined || String(value) === "") return fallback || "—"
    return String(value)
  }

  function yesNo(value) { return value === true ? "Sí" : "No" }

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
    if (n <= 0) return "—"
    return (n > 1000 ? (Math.round(n / 100) / 10) : n) + " kHz"
  }

  Text {
    visible: !root.daemon
    width: parent.width
    text: "Sin datos del demonio todavía."
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
    if (!errorRows.length) errorRows.push({ key: "Errores", value: "Ninguno" })

    return [
      {
        label: "DEMONIO",
        rows: [
          { key: "Versión", value: root.text(daemon.version) + "  (API v" + daemon.apiVersion + ")" },
          { key: "Activo desde hace", value: root.uptimeLabel(daemon.uptime) },
          { key: "Red", value: daemon.online ? "En línea" : "Sin conexión", alert: !daemon.online },
          { key: "Sesión", value: playerState.authState === "ok"
              ? "Iniciada" + (playerState.subscription ? " · " + playerState.subscription : "")
              : "Sin iniciar", alert: playerState.authState !== "ok" },
          { key: "Host", value: service ? service.host : "—" }
        ]
      },
      {
        label: "AUDIO",
        rows: [
          { key: "Backend", value: root.text(audio.backend) },
          { key: "Dispositivo", value: root.text(audio.configured_device, "Por defecto del sistema") },
          { key: "Dispositivo presente", value: root.yesNo(audio.device_present), alert: audio.device_present !== true },
          { key: "Dispositivo abierto", value: root.yesNo(audio.device_open) },
          { key: "Bit-perfect", value: root.text(audio.bit_perfect, "Desactivado") },
          { key: "Formato", value: audio.bit_depth
              ? audio.bit_depth + " bits · " + root.rateLabel(audio.sample_rate)
              : "—" }
        ]
      },
      {
        label: "QOBUZ CONNECT",
        rows: [
          { key: "Nombre del dispositivo", value: root.text(qconnect.device_name) },
          { key: "Activado", value: root.yesNo(qconnect.enabled) },
          { key: "Estado", value: root.text(qconnect.state) },
          { key: "Sesión activa", value: root.yesNo(qconnect.session_active) }
        ]
      },
      { label: "ÚLTIMOS ERRORES", rows: errorRows }
    ]
  }
}
