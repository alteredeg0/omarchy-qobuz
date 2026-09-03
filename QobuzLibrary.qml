import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Favourites (albums, tracks, artists) and the user's own playlists, behind
// one segmented control. Each tab is a separate qbzd call, fetched lazily.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }

  spacing: Style.space(6)

  Row {
    spacing: Style.space(4)

    Repeater {
      model: [
        { key: "albums", label: root.t("library.albums") },
        { key: "tracks", label: root.t("library.tracks") },
        { key: "artists", label: root.t("library.artists") },
        { key: "playlists", label: root.t("library.playlists") }
      ]

      delegate: Button {
        required property var modelData

        text: modelData.label
        fontSize: Style.font.caption
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: root.playerState.libraryType === modelData.key
        onClicked: if (root.service) root.service.loadLibrary(modelData.key)
      }
    }
  }

  Text {
    width: parent.width
    visible: root.playerState.libraryRunning
    text: root.t("word.loading")
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Text {
    width: parent.width
    visible: !root.playerState.libraryRunning && (root.playerState.library || []).length === 0
    text: root.t(root.playerState.libraryType === "playlists"
      ? "library.emptyPlaylists" : "library.emptyFavourites")
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  QobuzItemList {
    width: parent.width
    bar: root.bar
    service: root.service
    items: root.playerState.library
    maxItems: 50
  }
}
