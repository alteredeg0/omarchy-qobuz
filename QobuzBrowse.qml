import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// A drilled-into album, artist or playlist. Albums and playlists show their
// track listing; an artist shows top tracks and its release groups.
Column {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var detail: playerState.browse
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool isArtist: detail && detail.kind === "artist"

  spacing: Style.space(8)

  Text {
    width: parent.width
    visible: root.playerState.browseRunning
    text: "Cargando…"
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  Text {
    width: parent.width
    visible: !root.playerState.browseRunning && !root.detail
    text: "No se pudo abrir."
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
  }

  // ---- Header ------------------------------------------------------------

  Row {
    width: parent.width
    visible: !!root.detail
    spacing: Style.space(10)

    Rectangle {
      id: coverFrame
      width: Style.space(64)
      height: Style.space(64)
      anchors.verticalCenter: parent.verticalCenter
      radius: root.isArtist ? width / 2 : Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      Image {
        id: cover
        anchors.fill: parent
        source: root.detail ? root.detail.imageUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: root.isArtist ? "󰠃" : "󰀥"
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        textFormat: Text.PlainText
      }
    }

    Column {
      width: parent.width - coverFrame.width - Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)

      Text {
        width: parent.width
        text: root.detail ? root.detail.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
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
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Row {
        spacing: Style.space(6)

        QobuzHiResBadge {
          anchors.verticalCenter: parent.verticalCenter
          bar: root.bar
          track: root.detail
          showRate: false
          markSize: Style.space(16)
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
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }
      }

      Row {
        spacing: Style.space(4)

        Button {
          text: "Reproducir"
          iconText: "󰐊"
          bordered: true
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: if (root.service) root.service.playItem(root.detail)
        }

        Button {
          // Artists cannot be favourited through a track/album/artist pair
          // any differently — the same route takes all three.
          iconText: root.service && root.service.isFavorite(root.detail) ? "󰋑" : "󰋕"
          tooltipText: root.service && root.service.isFavorite(root.detail)
            ? "Quitar de favoritos" : "Añadir a favoritos"
          fontSize: Style.font.caption
          foreground: root.foreground
          fontFamily: root.fontFamily
          visible: root.detail && root.detail.kind !== "playlist"
          onClicked: if (root.service) root.service.favoriteToggle(root.detail)
        }
      }
    }
  }

  // ---- Body --------------------------------------------------------------

  // Albums and playlists: a numbered track listing.
  QobuzItemList {
    width: parent.width
    bar: root.bar
    service: root.service
    label: "PISTAS"
    numbered: true
    maxItems: 100
    items: root.detail && !root.isArtist ? (root.detail.tracks || []) : []
  }

  // Artists: top tracks first, then each release group.
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

    delegate: QobuzItemList {
      required property var modelData

      width: root.width
      bar: root.bar
      service: root.service
      label: modelData.label
      items: modelData.items
      maxItems: 8
    }
  }
}
