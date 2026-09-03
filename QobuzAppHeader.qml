import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Back / title / close, with the search field folded in underneath when the
// search view is on.
Column {
  id: root

  property var bar: null
  property var service: null
  property string title: ""
  property bool showBack: false
  property bool searchVisible: false

  signal backRequested()
  signal closeRequested()

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }

  function focusSearch() { field.forceActiveFocus() }

  spacing: Style.space(12)

  Item {
    width: parent.width
    implicitHeight: Math.max(titleText.implicitHeight, closeButton.implicitHeight)

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(10)

      Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showBack
        iconText: "󰁍"
        tooltipText: root.t("action.back")
        bordered: true
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.backRequested()
      }

      Text {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
        textFormat: Text.PlainText
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Button {
        iconText: "󰑐"
        tooltipText: root.t("action.refresh")
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: if (root.service) root.service.refresh()
      }

      Button {
        id: closeButton
        iconText: "󰅖"
        tooltipText: root.t("action.close")
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.closeRequested()
      }
    }
  }

  Row {
    width: parent.width
    visible: root.searchVisible
    spacing: Style.space(8)

    TextField {
      id: field
      width: parent.width - searchButton.width - Style.space(8)
      placeholderText: root.t("search.placeholderLong")
      foreground: root.foreground
      accent: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.body

      // Mirrored imperatively, not bound: a `text:` binding dies the first
      // time the user types, and an IPC-driven search would stop filling in.
      Connections {
        target: root.service
        // `service` is injected after this component is built, so the target
        // is null at creation time and Qt cannot match the signal yet.
        ignoreUnknownSignals: true
        function onSearchQueryChanged() {
          if (field.text !== root.service.searchQuery) field.text = root.service.searchQuery
        }
      }

      onAccepted: if (root.service) root.service.search(text)
      Keys.onEscapePressed: {
        if (text !== "") { text = ""; if (root.service) root.service.clearSearch() }
        else focus = false
      }
    }

    Button {
      id: searchButton
      iconText: root.playerState.searchRunning ? "󰑐"
              : (root.playerState.search.total > 0 ? "󰅖" : "󰍉")
      iconSpinning: root.playerState.searchRunning
      tooltipText: root.t(root.playerState.search.total > 0 ? "action.clear" : "action.search")
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: {
        if (!root.service) return
        if (root.playerState.search.total > 0) { field.text = ""; root.service.clearSearch() }
        else root.service.search(field.text)
      }
    }
  }
}
