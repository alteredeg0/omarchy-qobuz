import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// A titled list of catalogue rows. Every view in the panel — search sections,
// favourites, playlists, discover rails, album and playlist track listings —
// is one of these, so the click behaviour stays identical everywhere.
Column {
  id: root

  property var bar: null
  property var service: null
  property string label: ""
  property var items: []
  property int maxItems: 12
  // Track listings read better numbered than thumbnailed.
  property bool numbered: false

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var shown: (items || []).slice(0, maxItems)

  spacing: Style.space(2)
  visible: (items || []).length > 0

  PanelSectionHeader {
    visible: root.label !== ""
    text: root.label
    foreground: root.foreground
    fontFamily: root.fontFamily
    topPadding: Style.space(6)
  }

  Repeater {
    model: root.shown

    delegate: QobuzResultRow {
      required property var modelData
      required property int index

      width: root.width
      bar: root.bar
      item: modelData
      indexLabel: root.numbered ? String(index + 1) : ""
      fallbackGlyph: root.glyphFor(modelData.kind)
      hintText: root.service ? root.service.secondaryLabel(modelData) : ""
      onActivated: if (root.service) root.service.activateItem(modelData)
      onQueued: if (root.service) root.service.secondaryItem(modelData)
    }
  }

  Text {
    visible: (root.items || []).length > root.maxItems
    text: "+" + ((root.items || []).length - root.maxItems) + " más"
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
    leftPadding: Style.space(4)
  }

  function glyphFor(kind) {
    if (kind === "album") return "󰀥"
    if (kind === "track") return "󰝚"
    if (kind === "artist") return "󰠃"
    return "󰲹"
  }
}
