import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Lyrics for whatever is playing. qbzd answers /api/lyrics?id=current, and a
// track with none is an ordinary "not_found", not a failure — so this view
// says so plainly instead of showing an error.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var lyrics: playerState.lyrics
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var lines: lyrics ? (lyrics.lines || []) : []

  spacing: Style.space(4)

  Text {
    width: parent.width
    visible: root.playerState.lyricsRunning
    text: "Buscando la letra…"
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Text {
    width: parent.width
    visible: !root.playerState.lyricsRunning && root.lines.length === 0
    text: {
      if (!root.playerState.track) return "No hay nada sonando."
      if (root.lyrics && root.lyrics.message) return root.lyrics.message
      return "Esta pista no tiene letra en Qobuz."
    }
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
  }

  Repeater {
    model: root.lines

    delegate: Text {
      required property var modelData

      width: root.width
      // Blank lines are stanza breaks and must keep their height.
      text: String(modelData) === "" ? " " : String(modelData)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }
}
