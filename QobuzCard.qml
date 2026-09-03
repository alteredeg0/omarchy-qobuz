import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// One cell of the app's cover grid. Left click opens an album, artist or
// playlist; right click plays it. Same two service calls the panel rows use,
// so a given item behaves identically on both surfaces.
Item {
  id: root

  property var bar: null
  property var service: null
  property var item: null
  property real coverSize: Style.space(150)

  // Catalogue items carry `imageUrl`; player tracks carry `artworkUrl`.
  readonly property string imageSource: {
    if (!item) return ""
    return String(item.imageUrl || item.artworkUrl || "")
  }

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool isArtist: item && item.kind === "artist"

  implicitWidth: coverSize
  implicitHeight: coverSize + labels.implicitHeight + Style.space(8)

  Rectangle {
    anchors.fill: parent
    anchors.margins: -Style.space(6)
    radius: Style.cornerRadius
    color: hover.containsMouse
      ? Style.hoverFillFor(root.foreground, Color.accent, Color.urgent)
      : "transparent"
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(8)

    Rectangle {
      id: coverFrame
      width: root.coverSize
      height: root.coverSize
      radius: root.isArtist ? width / 2 : Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      Image {
        id: cover
        anchors.fill: parent
        source: root.imageSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Decode at the size actually drawn: a grid of 600px covers scaled
        // into 150px cells wastes memory and time on every repaint.
        sourceSize.width: Math.round(root.coverSize * 2)
        sourceSize.height: Math.round(root.coverSize * 2)
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: root.glyph
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
        font.family: root.fontFamily
        font.pixelSize: Style.font.displayLarge
        textFormat: Text.PlainText
      }

      QobuzHiResBadge {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(6)
        bar: root.bar
        track: root.item
        showRate: false
        markSize: Style.space(22)
      }

      // A play affordance that only shows on hover, so the grid stays calm.
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(6)
        width: Style.space(32)
        height: width
        radius: width / 2
        visible: hover.containsMouse
        color: Color.accent

        Text {
          anchors.centerIn: parent
          text: "󰐊"
          color: Color.background
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          textFormat: Text.PlainText
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.playItem(root.item)
        }
      }
    }

    Column {
      id: labels
      width: root.coverSize
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: root.item ? root.item.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
        horizontalAlignment: root.isArtist ? Text.AlignHCenter : Text.AlignLeft
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.subtitleText
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
        horizontalAlignment: root.isArtist ? Text.AlignHCenter : Text.AlignLeft
      }
    }
  }

  readonly property string subtitleText: {
    if (!item) return ""
    if (item.kind === "playlist" && item.trackCount > 0)
      return item.subtitle ? item.subtitle + "  ·  " + item.trackCount + " pistas"
                           : item.trackCount + " pistas"
    return item.subtitle || ""
  }

  readonly property string glyph: {
    if (!item) return "󰝚"
    if (item.kind === "album") return "󰀥"
    if (item.kind === "artist") return "󰠃"
    if (item.kind === "track") return "󰝚"
    return "󰲹"
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    // Sits under the play button, which takes its own clicks first.
    z: -1
    onClicked: function (mouse) {
      if (!root.service) return
      if (mouse.button === Qt.RightButton) root.service.secondaryItem(root.item)
      else root.service.activateItem(root.item)
    }
  }
}
