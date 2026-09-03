import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// The upcoming tracks. qbzd's /api/queue returns `upcoming` + `history` +
// `current_track` — not the flat `tracks` array the wiki describes — so the
// indices here are offsets from the current position.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var upcoming: playerState.upcoming || []

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }


  spacing: Style.space(4)

  PanelSectionHeader {
    text: root.upcoming.length > 0
      ? root.t("section.upNext", root.playerState.queueLength)
      : root.t("section.queue")
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Text {
    visible: root.upcoming.length === 0
    width: parent.width
    text: root.t(root.playerState.queueLength > 0 ? "queue.last" : "queue.empty")
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  Repeater {
    model: root.upcoming.slice(0, 12)

    delegate: Button {
      required property var modelData
      required property int index

      width: root.width
      leftAlign: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.bodySmall
      text: (modelData.artist ? modelData.artist + " — " : "") + modelData.title
      tooltipText: modelData.duration > 0 ? Model.formatDuration(modelData.duration) : ""
      // queueIndex is the current position; the first upcoming entry is the
      // one after it.
      onClicked: if (root.service) root.service.queueJump(root.playerState.queueIndex + 1 + index)
    }
  }

  Text {
    visible: root.upcoming.length > 12
    text: root.t("hint.more", root.upcoming.length - 12)
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
  }
}
