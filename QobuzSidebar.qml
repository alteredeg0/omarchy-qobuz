import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// The app's left rail: sections on top, the library's four kinds below, then
// the user's own playlists listed so a click opens one directly.
Flickable {
  id: root

  property var bar: null
  property var service: null
  // The status page is app-only — it has no bar-panel equivalent — so the app
  // owns that flag rather than the shared view state.
  property bool statusSelected: false

  signal statusRequested()

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool showingPlaylists: playerState.libraryType === "playlists"
  readonly property var playlists: showingPlaylists ? (playerState.library || []) : []

  contentHeight: column.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  Column {
    id: column
    width: root.width
    spacing: Style.space(2)

    // ---- Identity --------------------------------------------------------

    Row {
      spacing: Style.space(8)
      bottomPadding: Style.space(10)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰝚"
        color: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        textFormat: Text.PlainText
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
          text: "Qobuz"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          textFormat: Text.PlainText
        }

        Text {
          visible: text !== ""
          text: root.playerState.subscription
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }
      }
    }

    // ---- Sections --------------------------------------------------------

    Repeater {
      model: [
        { view: Model.VIEW_DISCOVER, label: "Descubrir", icon: "󰉹" },
        { view: Model.VIEW_SEARCH,   label: "Buscar",    icon: "󰍉" },
        { view: Model.VIEW_QUEUE,    label: "Cola",      icon: "󰲸" },
        { view: Model.VIEW_LYRICS,   label: "Letra",     icon: "󰊄" }
      ]

      delegate: Button {
        required property var modelData

        width: root.width
        leftAlign: true
        text: modelData.label
        iconText: modelData.icon
        fontSize: Style.font.body
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: !root.statusSelected && root.playerState.view === modelData.view
        onClicked: {
          root.statusSelected = false
          if (root.service) root.service.goTo(modelData.view)
        }
      }
    }

    // ---- Library ---------------------------------------------------------

    PanelSectionHeader {
      text: "TU BIBLIOTECA"
      foreground: root.foreground
      fontFamily: root.fontFamily
      topPadding: Style.space(14)
      bottomPadding: Style.space(4)
    }

    Repeater {
      model: [
        { kind: "albums",    label: "Álbumes",  icon: "󰀥" },
        { kind: "tracks",    label: "Pistas",   icon: "󰝚" },
        { kind: "artists",   label: "Artistas", icon: "󰠃" },
        { kind: "playlists", label: "Playlists", icon: "󰲹" }
      ]

      delegate: Button {
        required property var modelData

        width: root.width
        leftAlign: true
        text: modelData.label
        iconText: modelData.icon
        fontSize: Style.font.body
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: !root.statusSelected
                && root.playerState.view === Model.VIEW_LIBRARY
                && root.playerState.libraryType === modelData.kind
        onClicked: {
          root.statusSelected = false
          if (!root.service) return
          root.service.goTo(Model.VIEW_LIBRARY)
          root.service.loadLibrary(modelData.kind)
        }
      }
    }

    // The playlists themselves, so a click goes straight to one instead of
    // via the library grid.
    Repeater {
      model: root.playlists.slice(0, 30)

      delegate: Button {
        required property var modelData

        width: root.width
        leftAlign: true
        // Playlist names run long; the rail is fixed-width.
        text: modelData.title.length > 26 ? modelData.title.slice(0, 25) + "…" : modelData.title
        tooltipText: modelData.title
        fontSize: Style.font.bodySmall
        foreground: Qt.darker(root.foreground, 1.3)
        fontFamily: root.fontFamily
        active: root.playerState.view === Model.VIEW_BROWSE
                && root.playerState.browse
                && String(root.playerState.browse.id) === String(modelData.id)
        onClicked: {
          root.statusSelected = false
          if (root.service) root.service.openItem(modelData)
        }
      }
    }

    // ---- Status ----------------------------------------------------------

    // PanelSeparator is a plain divider with no padding of its own, so the
    // breathing room has to come from a spacer.
    Item { width: 1; height: Style.space(12) }

    PanelSeparator {
      width: root.width
      foreground: root.foreground
    }

    Button {
      width: root.width
      leftAlign: true
      text: "Estado"
      iconText: "󰋼"
      fontSize: Style.font.body
      foreground: root.foreground
      fontFamily: root.fontFamily
      active: root.statusSelected
      onClicked: root.statusRequested()
    }
  }
}
