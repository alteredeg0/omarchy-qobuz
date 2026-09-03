import QtQuick
import qs.Commons
import "QobuzModel.js" as Model

// The Japan Audio Society "Hi-Res AUDIO" mark, optionally followed by the
// actual rate ("24-bit 192 kHz"). See assets/README.md on the trademark.
//
// The mark is a fixed gold-and-black square by definition — it must not be
// recoloured — so it is the one thing in this plugin that does not follow the
// theme. It carries its own contrast, so it reads on light and dark alike.
Row {
  id: root

  property var bar: null
  property var track: null
  // Show the sample rate next to the mark. The logo says "this is hi-res";
  // the text says how hi-res, which is the part people actually want.
  property bool showRate: true
  property real markSize: Style.space(20)

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string rateText: Model.qualityLabel(track)
  readonly property bool hires: Model.isHiRes(track)

  // Nothing to say when the track is neither hi-res nor rate-tagged.
  visible: hires || (showRate && rateText !== "")
  spacing: Style.space(6)

  Image {
    id: mark
    anchors.verticalCenter: parent.verticalCenter
    visible: root.hires && status === Image.Ready
    source: root.hires ? Qt.resolvedUrl("assets/hi-res-audio.svg") : ""
    // The source is square; rendering it at the target size keeps the SVG
    // rasterised sharp instead of scaling a default-sized bitmap.
    sourceSize.width: Math.round(root.markSize * 2)
    sourceSize.height: Math.round(root.markSize * 2)
    width: root.markSize
    height: root.markSize
    smooth: true
    asynchronous: true
  }

  // If Qt's SVG subset ever fails on the mark, fall back to a plain wordmark
  // rather than showing nothing at all.
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    visible: root.hires && mark.status !== Image.Ready
    radius: Style.cornerRadius
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
    implicitWidth: fallbackText.implicitWidth + Style.space(8)
    implicitHeight: fallbackText.implicitHeight + Style.space(2)

    Text {
      id: fallbackText
      anchors.centerIn: parent
      text: "HI-RES"
      color: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      textFormat: Text.PlainText
    }
  }

  Text {
    anchors.verticalCenter: parent.verticalCenter
    visible: root.showRate && root.rateText !== ""
    text: root.rateText
    color: Qt.darker(root.foreground, 1.3)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    textFormat: Text.PlainText
  }
}
