import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// The app's main area: whichever view the shared state says, laid out for a
// full screen rather than a 440px panel. Collections become cover grids;
// tracks stay dense numbered lists, which is what they read best as.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var results: playerState.search
  readonly property var detail: playerState.browse
  readonly property bool isArtist: detail && detail.kind === "artist"
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function showing(view) { return playerState.view === view }

  spacing: Style.space(20)

  // ---- Empty and loading states -----------------------------------------

  Text {
    width: parent.width
    visible: root.playerState.authState === "needs_auth"
    text: "Sin sesión de Qobuz. Ejecuta «qbzd login» en una terminal."
    color: Qt.darker(root.foreground, 1.3)
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
  }

  // ---- Discover ----------------------------------------------------------

  Column {
    width: parent.width
    spacing: Style.space(20)
    visible: root.showing(Model.VIEW_DISCOVER)

    Text {
      width: parent.width
      visible: root.playerState.discoverRunning
      text: "Cargando novedades…"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    Repeater {
      model: root.playerState.discover || []

      delegate: QobuzGrid {
        required property var modelData

        width: parent.width
        bar: root.bar
        service: root.service
        label: modelData.label
        items: modelData.items
        maxItems: 12
      }
    }
  }

  // ---- Search ------------------------------------------------------------

  Column {
    width: parent.width
    spacing: Style.space(20)
    visible: root.showing(Model.VIEW_SEARCH)

    Text {
      width: parent.width
      visible: root.playerState.searchError !== ""
      text: root.playerState.searchError
      color: root.bar ? root.bar.urgent : Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      visible: !root.playerState.searchRunning && root.playerState.searchError === ""
               && root.results.query !== "" && root.results.total === 0
      text: "Sin resultados para «" + root.results.query + "»."
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      visible: root.results.query === "" && !root.playerState.searchRunning
      text: "Escribe arriba para buscar en el catálogo."
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    QobuzGrid {
      width: parent.width
      bar: root.bar
      service: root.service
      label: "ÁLBUMES"
      items: root.results.albums
    }

    // Tracks are the one search bucket that reads better as a list.
    QobuzItemList {
      width: parent.width
      bar: root.bar
      service: root.service
      label: "PISTAS"
      items: root.results.tracks
      maxItems: 20
    }

    QobuzGrid {
      width: parent.width
      bar: root.bar
      service: root.service
      label: "ARTISTAS"
      items: root.results.artists
      targetCoverSize: Style.space(120)
    }

    QobuzGrid {
      width: parent.width
      bar: root.bar
      service: root.service
      label: "PLAYLISTS"
      items: root.results.playlists
    }
  }

  // ---- Library -----------------------------------------------------------

  Column {
    width: parent.width
    spacing: Style.space(12)
    visible: root.showing(Model.VIEW_LIBRARY)

    Text {
      width: parent.width
      visible: root.playerState.libraryRunning
      text: "Cargando…"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    Text {
      width: parent.width
      visible: !root.playerState.libraryRunning && (root.playerState.library || []).length === 0
      text: root.playerState.libraryType === "playlists"
        ? "No tienes playlists." : "No tienes favoritos en esta categoría."
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    // Favourite tracks are a list; everything else is a grid.
    QobuzItemList {
      width: parent.width
      bar: root.bar
      service: root.service
      items: root.playerState.libraryType === "tracks" ? root.playerState.library : []
      maxItems: 100
    }

    QobuzGrid {
      width: parent.width
      bar: root.bar
      service: root.service
      items: root.playerState.libraryType === "tracks" ? [] : root.playerState.library
      targetCoverSize: root.playerState.libraryType === "artists" ? Style.space(120) : Style.space(150)
    }
  }

  // ---- Queue -------------------------------------------------------------

  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: root.showing(Model.VIEW_QUEUE)

    QobuzItemList {
      width: parent.width
      bar: root.bar
      service: root.service
      label: root.playerState.queueLength > 0
        ? "A CONTINUACIÓN · " + root.playerState.queueLength + " EN COLA" : "COLA"
      items: root.playerState.upcoming
      numbered: true
      maxItems: 100
    }

    Text {
      width: parent.width
      visible: (root.playerState.upcoming || []).length === 0
      text: root.playerState.queueLength > 0
        ? "Última pista de la cola." : "La cola está vacía."
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }
  }

  // ---- Lyrics ------------------------------------------------------------

  QobuzLyrics {
    width: parent.width
    bar: root.bar
    service: root.service
    visible: root.showing(Model.VIEW_LYRICS)
  }

  // ---- Browse ------------------------------------------------------------

  Column {
    width: parent.width
    spacing: Style.space(20)
    visible: root.showing(Model.VIEW_BROWSE)

    Text {
      width: parent.width
      visible: root.playerState.browseRunning
      text: "Cargando…"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      textFormat: Text.PlainText
    }

    // Header: big cover beside the identity and the actions.
    Row {
      width: parent.width
      visible: !!root.detail
      spacing: Style.space(20)

      Rectangle {
        id: heroFrame
        width: Style.space(180)
        height: width
        radius: root.isArtist ? width / 2 : Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        clip: true

        Image {
          id: hero
          anchors.fill: parent
          source: root.detail ? root.detail.imageUrl : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: Math.round(Style.space(180) * 2)
          sourceSize.height: Math.round(Style.space(180) * 2)
          visible: status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: hero.status !== Image.Ready
          text: root.isArtist ? "󰠃" : "󰀥"
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
          textFormat: Text.PlainText
        }
      }

      Column {
        width: parent.width - heroFrame.width - Style.space(20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Text {
          width: parent.width
          text: root.detail ? root.detail.title : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
          elide: Text.ElideRight
          maximumLineCount: 2
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: root.detail ? root.detail.subtitle : ""
          color: Qt.darker(root.foreground, 1.3)
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Row {
          spacing: Style.space(8)

          QobuzHiResBadge {
            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            track: root.detail
            showRate: false
            markSize: Style.space(20)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: {
              if (!root.detail) return ""
              var bits = []
              if (root.detail.trackCount > 0) bits.push(root.detail.trackCount + " pistas")
              if (root.detail.duration > 0) bits.push(Model.formatDuration(root.detail.duration))
              return bits.join("  ·  ")
            }
            color: Qt.darker(root.foreground, 1.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
          }
        }

        Row {
          spacing: Style.space(6)
          topPadding: Style.space(4)

          Button {
            text: "Reproducir"
            iconText: "󰐊"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (root.service) root.service.playItem(root.detail)
          }

          Button {
            iconText: root.service && root.service.isFavorite(root.detail) ? "󰋑" : "󰋕"
            tooltipText: root.service && root.service.isFavorite(root.detail)
              ? "Quitar de favoritos" : "Añadir a favoritos"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            // Only track, album and artist take the favourites route.
            visible: root.detail && root.detail.kind !== "playlist"
            onClicked: if (root.service) root.service.favoriteToggle(root.detail)
          }
        }
      }
    }

    // Albums and playlists: the track listing.
    QobuzItemList {
      width: parent.width
      bar: root.bar
      service: root.service
      label: "PISTAS"
      numbered: true
      maxItems: 200
      items: root.detail && !root.isArtist ? (root.detail.tracks || []) : []
    }

    // Artists: top tracks, then a grid per release group.
    QobuzItemList {
      width: parent.width
      bar: root.bar
      service: root.service
      label: "MÁS ESCUCHADAS"
      numbered: true
      maxItems: 10
      items: root.isArtist ? (root.detail.topTracks || []) : []
    }

    Repeater {
      model: root.isArtist ? (root.detail.releaseGroups || []) : []

      delegate: QobuzGrid {
        required property var modelData

        width: parent.width
        bar: root.bar
        service: root.service
        label: modelData.label
        items: modelData.items
        maxItems: 18
      }
    }
  }
}
