import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model
import "QobuzStrings.js" as Strings

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

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }


  spacing: Style.space(4)

  Text {
    width: parent.width
    visible: root.playerState.discoverRunning
    text: root.t("discover.loading")
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Text {
    width: parent.width
    visible: !root.playerState.discoverRunning && root.rails.length === 0
    text: root.t("discover.empty")
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
      label: Strings.railLabel(root.service ? root.service.lang : Strings.DEFAULT_LANG, modelData.key)
      items: modelData.items
      // A rail is a taster, not a catalogue; the full list is a click away.
      maxItems: 6
    }
  }
}
