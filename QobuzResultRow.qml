import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// One catalogue row — search result, favourite, playlist, discover item or
// track listing. Left click activates it (opens an album/artist/playlist,
// plays a track), right click does the other useful thing.
Item {
  id: root

  property var bar: null
  property var item: null
  property string fallbackGlyph: "󰝚"

  // `activated` is the left click, `queued` the right one; what each means
  // per kind is decided by the service, not here.
  signal activated()
  signal queued()

  property string hintText: ""
  // Track listings show a position number where a cover would otherwise go.
  property string indexLabel: ""

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real thumbSize: Style.space(34)
  // Every kind has a secondary action, so the row is always right-clickable.
  readonly property string secondaryHint: hintText

  implicitHeight: Math.max(thumbSize, labels.implicitHeight) + Style.space(8)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: hover.containsMouse
      ? Style.hoverFillFor(root.foreground, Color.accent, Color.urgent)
      : "transparent"
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: Style.space(4)
    anchors.rightMargin: Style.space(4)
    spacing: Style.space(8)

    // A numbered listing already sits under its album's cover, so repeating
    // the same thumbnail on every row would just be noise.
    Text {
      width: root.thumbSize
      height: root.thumbSize
      anchors.verticalCenter: parent.verticalCenter
      visible: root.indexLabel !== ""
      text: root.indexLabel
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignRight
      verticalAlignment: Text.AlignVCenter
      rightPadding: Style.space(4)
      textFormat: Text.PlainText
    }

    Rectangle {
      width: root.thumbSize
      height: root.thumbSize
      anchors.verticalCenter: parent.verticalCenter
      visible: root.indexLabel === ""
      radius: root.item && root.item.kind === "artist" ? width / 2 : Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      clip: true

      Image {
        id: thumb
        anchors.fill: parent
        source: root.item ? root.item.imageUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: thumb.status !== Image.Ready
        text: root.fallbackGlyph
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        textFormat: Text.PlainText
      }
    }

    Column {
      id: labels
      // The Row has two gaps, not one: thumb|labels and labels|duration.
      // Subtracting a single gap overflows the row and clips the duration.
      width: parent.width - root.thumbSize - durationLabel.width - Style.space(16)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Row {
        width: parent.width
        spacing: Style.space(5)

        Text {
          width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + Style.space(5) : 0))
          text: root.item ? root.item.title : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        // Just the mark here: a search row has no space for the rate, and
        // the catalogue endpoints do not report one anyway.
        QobuzHiResBadge {
          id: badge
          anchors.verticalCenter: parent.verticalCenter
          bar: root.bar
          track: root.item
          showRate: false
          markSize: Style.space(15)
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.subtitleText
        color: Qt.darker(root.foreground, 1.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }
    }

    Text {
      id: durationLabel
      anchors.verticalCenter: parent.verticalCenter
      text: root.trailingText
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }

  readonly property string subtitleText: {
    if (!item) return ""
    if (item.kind === "track" && item.albumTitle)
      return item.subtitle ? item.subtitle + "  ·  " + item.albumTitle : item.albumTitle
    return item.subtitle || ""
  }

  // Albums and playlists read better as a track count than as a total runtime.
  readonly property string trailingText: {
    if (!item) return ""
    if (item.kind === "track") return item.duration > 0 ? Model.formatDuration(item.duration) : ""
    if (item.trackCount > 0) return item.trackCount + " ♪"
    return ""
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) root.queued()
      else root.activated()
    }
    onEntered: if (root.bar && root.secondaryHint !== "") root.bar.showTooltip(root, root.secondaryHint)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
