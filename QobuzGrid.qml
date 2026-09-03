import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// A titled, responsive grid of covers. Columns are derived from the available
// width rather than fixed, so the same component works in a narrow sidebar-
// squeezed area and on a 6K screen.
Column {
  id: root

  property var bar: null
  property var service: null
  property string label: ""
  property var items: []
  property int maxItems: 60
  property real targetCoverSize: Style.space(150)

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var shown: (items || []).slice(0, maxItems)

  readonly property real gap: Style.space(18)
  // Fit as many target-sized covers as the width allows, then share out the
  // remainder so the row ends flush instead of leaving a ragged gutter.
  readonly property int columns: Math.max(1, Math.floor((width + gap) / (targetCoverSize + gap)))
  readonly property real cellSize: columns > 0
    ? Math.floor((width - gap * (columns - 1)) / columns)
    : targetCoverSize

  spacing: Style.space(10)
  visible: shown.length > 0

  PanelSectionHeader {
    visible: root.label !== ""
    text: root.label
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Grid {
    columns: root.columns
    columnSpacing: root.gap
    rowSpacing: root.gap

    Repeater {
      model: root.shown

      delegate: QobuzCard {
        required property var modelData

        bar: root.bar
        service: root.service
        item: modelData
        coverSize: root.cellSize
      }
    }
  }
}
