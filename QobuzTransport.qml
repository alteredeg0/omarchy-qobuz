import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Progress, transport row and volume. Every control is gated on
// Model.canHandle so nothing pretends to work while logged out.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool live: playerState.daemonUp && playerState.authState === "ok"

  spacing: Style.space(8)

  // ---- Progress ----------------------------------------------------------

  PanelSlider {
    id: progress
    width: parent.width
    bar: root.bar
    minimum: 0
    maximum: Math.max(1, root.playerState.duration)
    step: 1
    integer: true
    enabled: Model.canHandle(root.playerState, "seek")
    opacity: enabled ? 1 : 0.4
    // While dragging, the slider owns the value; otherwise the service does.
    value: dragging ? liveValue : root.playerState.position
    onReleased: function (v) { if (root.service) root.service.seek(v) }
  }

  Item {
    width: parent.width
    implicitHeight: elapsed.implicitHeight

    Text {
      id: elapsed
      anchors.left: parent.left
      text: Model.formatDuration(root.playerState.position)
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }

    Text {
      anchors.right: parent.right
      text: Model.formatDuration(root.playerState.duration)
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }

  // ---- Transport ---------------------------------------------------------

  Item {
    width: parent.width
    implicitHeight: transportRow.implicitHeight

    Row {
      id: transportRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(4)

      Button {
        iconText: "󰒞"
        tooltipText: root.playerState.shuffle ? "Aleatorio activado" : "Aleatorio desactivado"
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: root.playerState.shuffle
        enabled: root.live
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.toggleShuffle()
      }

      Button {
        iconText: "󰒮"
        tooltipText: "Anterior"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: Model.canHandle(root.playerState, "previous")
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.previous()
      }

      Button {
        iconText: root.playerState.playback === Model.PLAYBACK_PLAYING ? "󰏤" : "󰐊"
        tooltipText: root.playerState.playback === Model.PLAYBACK_PLAYING ? "Pausar" : "Reproducir"
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconSize: Style.font.heading
        bordered: true
        enabled: Model.canHandle(root.playerState, "playPause")
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.togglePlayback()
      }

      Button {
        iconText: "󰒭"
        tooltipText: "Siguiente"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: Model.canHandle(root.playerState, "next")
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.next()
      }

      Button {
        iconText: root.playerState.repeat === "one" ? "󰑘" : "󰑖"
        tooltipText: root.playerState.repeat === "off" ? "Repetición desactivada"
                   : (root.playerState.repeat === "all" ? "Repetir todo" : "Repetir pista")
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: root.playerState.repeat !== "off"
        enabled: root.live
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.cycleRepeat()
      }
    }
  }

  // ---- Volume ------------------------------------------------------------

  Row {
    width: parent.width
    spacing: Style.space(8)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      // qbzd exposes no /api/playback/mute route (404), so this is an
      // indicator only — muting happens through the volume slider.
      text: root.playerState.muted || root.playerState.volume <= 0 ? "󰝟"
          : (root.playerState.volume < 0.5 ? "󰖀" : "󰕾")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      textFormat: Text.PlainText
    }

    PanelSlider {
      width: parent.width - Style.space(28)
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar
      minimum: 0
      maximum: 1
      step: 0.02
      enabled: Model.canHandle(root.playerState, "volume")
      opacity: enabled ? 1 : 0.4
      value: dragging ? liveValue : root.playerState.volume
      onMoved: function (v) { if (root.service) root.service.setVolume(v) }
      onReleased: function (v) { if (root.service) root.service.setVolume(v) }
    }
  }
}
