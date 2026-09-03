import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// The app's bottom bar: what's playing on the left, transport and progress in
// the middle, volume on the right. Same service calls and the same
// Model.canHandle gating as the panel's transport — only the layout differs.
Item {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var track: playerState.track
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool playing: playerState.playback === Model.PLAYBACK_PLAYING

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }


  implicitHeight: Style.space(84)

  // ---- Now playing -------------------------------------------------------

  Row {
    id: nowPlaying
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(Style.space(300), parent.width * 0.26)
    spacing: Style.space(10)

    Rectangle {
      id: coverFrame
      width: Style.space(56)
      height: width
      anchors.verticalCenter: parent.verticalCenter
      radius: Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      Image {
        id: cover
        anchors.fill: parent
        source: root.service ? root.service.artworkUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: Math.round(Style.space(56) * 2)
        sourceSize.height: Math.round(Style.space(56) * 2)
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: "󰝚"
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        textFormat: Text.PlainText
      }
    }

    Column {
      width: parent.width - coverFrame.width - Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: root.track ? root.track.title : root.t("state.nothingPlaying")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.track ? root.track.artist : ""
        color: Qt.darker(root.foreground, 1.35)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      QobuzHiResBadge {
        bar: root.bar
        track: root.track
        markSize: Style.space(16)
      }
    }
  }

  // ---- Transport and progress -------------------------------------------

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(Style.space(560), parent.width * 0.44)
    spacing: Style.space(4)

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(6)

      Button {
        iconText: "󰒞"
        tooltipText: root.t(root.playerState.shuffle ? "action.shuffleOn" : "action.shuffleOff")
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: root.playerState.shuffle
        enabled: root.playerState.authState === "ok"
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.toggleShuffle()
      }

      Button {
        iconText: "󰒮"
        tooltipText: root.t("action.previous")
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: Model.canHandle(root.playerState, "previous")
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.previous()
      }

      Button {
        iconText: root.playing ? "󰏤" : "󰐊"
        tooltipText: root.t(root.playing ? "action.pause" : "action.play")
        iconSize: Style.font.heading
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: Model.canHandle(root.playerState, "playPause")
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.togglePlayback()
      }

      Button {
        iconText: "󰒭"
        tooltipText: root.t("action.next")
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: Model.canHandle(root.playerState, "next")
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.next()
      }

      Button {
        iconText: root.playerState.repeat === "one" ? "󰑘" : "󰑖"
        tooltipText: root.t(root.playerState.repeat === "off" ? "action.repeatOff"
                   : (root.playerState.repeat === "all" ? "action.repeatAll" : "action.repeatOne"))
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: root.playerState.repeat !== "off"
        enabled: root.playerState.authState === "ok"
        opacity: enabled ? 1 : 0.4
        onClicked: if (root.service) root.service.cycleRepeat()
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      Text {
        id: elapsed
        anchors.verticalCenter: parent.verticalCenter
        text: Model.formatDuration(root.playerState.position)
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }

      PanelSlider {
        width: parent.width - elapsed.width - total.width - Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
        minimum: 0
        maximum: Math.max(1, root.playerState.duration)
        step: 1
        integer: true
        enabled: Model.canHandle(root.playerState, "seek")
        opacity: enabled ? 1 : 0.4
        value: dragging ? liveValue : root.playerState.position
        onReleased: function (v) { if (root.service) root.service.seek(v) }
      }

      Text {
        id: total
        anchors.verticalCenter: parent.verticalCenter
        text: Model.formatDuration(root.playerState.duration)
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        textFormat: Text.PlainText
      }
    }
  }

  // ---- Volume ------------------------------------------------------------

  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(Style.space(190), parent.width * 0.16)
    spacing: Style.space(8)

    Text {
      id: volumeGlyph
      anchors.verticalCenter: parent.verticalCenter
      // qbzd has no mute route, so this reflects the level rather than
      // offering a toggle that would silently do nothing.
      text: root.playerState.muted || root.playerState.volume <= 0 ? "󰝟"
          : (root.playerState.volume < 0.5 ? "󰖀" : "󰕾")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      textFormat: Text.PlainText
    }

    PanelSlider {
      width: parent.width - volumeGlyph.width - Style.space(8)
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
