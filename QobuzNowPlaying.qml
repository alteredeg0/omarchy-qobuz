import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Cover art plus the track identity, at the top of the panel.
Item {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var track: playerState.track
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property real artSize: Style.space(96)

  implicitHeight: Math.max(artSize, textColumn.implicitHeight)

  Row {
    anchors.fill: parent
    spacing: Style.space(12)

    Rectangle {
      id: artFrame
      width: root.artSize
      height: root.artSize
      radius: Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      Image {
        id: art
        anchors.fill: parent
        // Qt follows the 302 from /api/artwork/current and sends no Origin
        // header, which is what qbzd's CSRF guard rejects.
        source: root.service ? root.service.artworkUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: "󰝚"
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.displayLarge
      }
    }

    Column {
      id: textColumn
      width: parent.width - artFrame.width - Style.space(12)
      spacing: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: parent.width
        text: root.track ? root.track.title : root.placeholderTitle()
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
        textFormat: Text.PlainText
        maximumLineCount: 2
        wrapMode: Text.Wrap
      }

      Text {
        width: parent.width
        visible: !!root.track && root.track.artist !== ""
        text: root.track ? root.track.artist : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        width: parent.width
        visible: !!root.track && root.track.album !== ""
        text: root.track ? root.track.album : ""
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      // The official Hi-Res AUDIO mark plus the actual rate — the reason to
      // be on Qobuz in the first place.
      QobuzHiResBadge {
        bar: root.bar
        track: root.track
        markSize: Style.space(22)
      }
    }
  }

  function t(key, a) { return service ? service.t(key, a) : String(key) }

  function placeholderTitle() {
    if (!playerState.daemonUp) return t("state.daemonUnreachable")
    if (playerState.authState === "needs_auth") return t("state.noSessionTitle")
    return t("state.nothingPlaying")
  }
}
