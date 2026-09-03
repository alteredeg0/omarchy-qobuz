import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Qobuz's own editorial rails — new releases, most streamed, press awards and
// the rest — as stacked sections. One /api/discover?section=index call fills
// them all, so this view fetches once and keeps what it got.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var rails: playerState.discover || []

  spacing: Style.space(4)

  Text {
    width: parent.width
    visible: root.playerState.discoverRunning
    text: "Cargando novedades…"
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Text {
    width: parent.width
    visible: !root.playerState.discoverRunning && root.rails.length === 0
    text: "Nada que mostrar ahora mismo."
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Repeater {
    model: root.rails

    delegate: QobuzItemList {
      required property var modelData

      width: root.width
      bar: root.bar
      service: root.service
      label: modelData.label
      items: modelData.items
      // A rail is a taster, not a catalogue; the full list is a click away.
      maxItems: 6
    }
  }
}
