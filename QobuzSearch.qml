import QtQuick
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Catalogue search. Results are grouped by kind; clicking one plays it,
// right-clicking a track appends it to the queue instead.
Column {
  id: root

  property var bar: null
  property var service: null
  // The panel hands its key catcher over so typing in the field does not also
  // trigger the panel's single-letter shortcuts.
  property var keyCatcher: null

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property var results: playerState.search
  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool searching: playerState.searchRunning
  readonly property bool hasResults: results && results.total > 0

  function focusField() { field.forceActiveFocus() }

  spacing: Style.space(6)

  Row {
    width: parent.width
    spacing: Style.space(6)

    TextField {
      id: field
      width: parent.width - clearButton.width - Style.space(6)
      placeholderText: "Buscar en Qobuz"
      foreground: root.foreground
      accent: Color.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      enabled: root.playerState.authState === "ok"

      // A declarative `text:` binding would be destroyed the first time the
      // user types, so mirror the service imperatively instead: a search
      // driven from IPC (`omarchy-shell javih.qobuz search "..."`) fills the
      // field, and typing still owns it the rest of the time.
      Connections {
        target: root.service
        // `service` is injected after this component is built, so the target
        // is null at creation time and Qt cannot match the signal yet.
        ignoreUnknownSignals: true
        function onSearchQueryChanged() {
          if (field.text !== root.service.searchQuery) field.text = root.service.searchQuery
        }
      }

      // The panel's PanelKeyCatcher maps bare letters to transport actions;
      // block it while the field owns the keyboard or "s" toggles shuffle
      // mid-word.
      onActiveFocusChanged: if (root.keyCatcher) root.keyCatcher.blocked = activeFocus

      onAccepted: if (root.service) root.service.search(text)
      Keys.onEscapePressed: {
        if (text !== "") { text = ""; if (root.service) root.service.clearSearch() }
        else focus = false
      }
    }

    Button {
      id: clearButton
      iconText: root.searching ? "󰑐" : (root.hasResults ? "󰅖" : "󰍉")
      iconSpinning: root.searching
      tooltipText: root.hasResults ? "Limpiar" : "Buscar"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: root.playerState.authState === "ok"
      onClicked: {
        if (root.hasResults) { field.text = ""; if (root.service) root.service.clearSearch() }
        else if (root.service) root.service.search(field.text)
      }
    }
  }

  Text {
    width: parent.width
    visible: root.playerState.searchError !== ""
    text: root.playerState.searchError
    color: bar ? bar.urgent : Color.urgent
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  Text {
    width: parent.width
    visible: !root.searching && root.playerState.searchError === ""
             && root.results.query !== "" && !root.hasResults
    text: "Sin resultados para «" + root.results.query + "»."
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  // One section per result kind, in the order that matches how people search.
  Repeater {
    model: [
      { key: "albums", label: "ÁLBUMES" },
      { key: "tracks", label: "PISTAS" },
      { key: "artists", label: "ARTISTAS" },
      { key: "playlists", label: "PLAYLISTS" }
    ]

    delegate: Column {
      required property var modelData

      readonly property var items: root.results ? (root.results[modelData.key] || []) : []

      width: root.width
      spacing: Style.space(2)
      visible: items.length > 0

      PanelSectionHeader {
        text: modelData.label
        foreground: root.foreground
        fontFamily: root.fontFamily
        topPadding: Style.space(6)
      }

      Repeater {
        model: parent.items

        delegate: QobuzResultRow {
          required property var modelData
          width: root.width
          bar: root.bar
          item: modelData
          fallbackGlyph: root.glyphFor(modelData.kind)
          onActivated: if (root.service) root.service.playItem(modelData)
          onQueued: if (root.service) root.service.queueTrack(modelData)
        }
      }
    }
  }

  function glyphFor(kind) {
    if (kind === "album") return "󰀥"
    if (kind === "track") return "󰝚"
    if (kind === "artist") return "󰠃"
    return "󰲹"
  }
}
