import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// The strip that decides what fills the lower half of the panel. Browse is
// not a tab — it is a drill-down, so it replaces the strip with a back button
// naming where it will return to.
Item {
  id: root

  property var bar: null
  property var service: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool browsing: playerState.view === Model.VIEW_BROWSE

  implicitHeight: browsing ? backRow.implicitHeight : tabRow.implicitHeight

  Row {
    id: tabRow
    visible: !root.browsing
    spacing: Style.space(4)

    Repeater {
      model: [
        { view: Model.VIEW_QUEUE,    label: "Cola",      icon: "󰲸" },
        { view: Model.VIEW_SEARCH,   label: "Buscar",    icon: "󰍉" },
        { view: Model.VIEW_LIBRARY,  label: "Biblioteca", icon: "󰋕" },
        { view: Model.VIEW_DISCOVER, label: "Descubrir", icon: "󰉹" },
        { view: Model.VIEW_LYRICS,   label: "Letra",     icon: "󰊄" }
      ]

      // Five labelled tabs do not fit the panel width, so only the active
      // one is named; the rest are icons with the label in the tooltip.
      delegate: Button {
        required property var modelData

        readonly property bool current: root.playerState.view === modelData.view

        text: current ? modelData.label : ""
        iconText: modelData.icon
        tooltipText: current ? "" : modelData.label
        fontSize: Style.font.caption
        foreground: root.foreground
        fontFamily: root.fontFamily
        active: current
        onClicked: if (root.service) root.service.goTo(modelData.view)
      }
    }
  }

  Row {
    id: backRow
    visible: root.browsing
    spacing: Style.space(6)

    Button {
      iconText: "󰁍"
      text: root.backLabel
      bordered: true
      fontSize: Style.font.caption
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: if (root.service) root.service.closeBrowse()
    }
  }

  readonly property string backLabel: {
    switch (playerState.browseFrom) {
      case Model.VIEW_SEARCH: return "Resultados"
      case Model.VIEW_LIBRARY: return "Biblioteca"
      case Model.VIEW_DISCOVER: return "Descubrir"
      case Model.VIEW_LYRICS: return "Letra"
      default: return "Cola"
    }
  }
}
