import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// The full-screen surface. An `overlay`-kind plugin: shell.qml owns the
// Loader, keeps it alive between summons (keepLoaded), and injects
// `service` — the very same QobuzService instance the bar widget uses, so both
// surfaces share one session with no state to reconcile.
//
// Summoned with `omarchy-shell shell toggle javih.qobuz`. Note that declaring
// `overlay` alongside `bar-widget` is what routes that command here rather
// than to the bar popup (shell.qml isBarWidgetPanelPlugin); the popup stays
// reachable by clicking the widget and through the plugin's own IpcHandler.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  // The status page has no bar-panel equivalent, so it lives here rather than
  // in the shared view state.
  property bool statusSelected: false

  readonly property var playerState: service ? service.playerState : Model.emptyState()
  readonly property bool browsing: !statusSelected && playerState.view === Model.VIEW_BROWSE

  // The app is themed off the popup surface tokens, like every other overlay.
  readonly property color background: Color.popups.background
  readonly property color foreground: Color.popups.text
  readonly property string fontFamily: Style.font.family

  function open(payloadJson) {
    root.opened = true
    root.statusSelected = false
    if (service) {
      // Playlists in the sidebar are the one thing the app always needs.
      if ((playerState.library || []).length === 0) service.loadLibrary("playlists")
      if ((playerState.discover || []).length === 0 && playerState.view === Model.VIEW_DISCOVER) service.loadDiscover()
      service.refresh()
    }
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }
  function toggle() { root.opened ? close() : open("") }

  // Esc backs out of a detail page before closing the whole app.
  // Not named `escape` -- QML rejects that as an illegal method name, and the
  // component silently fails to load.
  function goBack() {
    if (statusSelected) { statusSelected = false; return }
    if (browsing && service) { service.closeBrowse(); return }
    close()
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "qobuz-app"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.round(parent.width * 0.92)
      height: Math.round(parent.height * 0.9)
      radius: Style.cornerRadius
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      // Swallow clicks so they don't reach the dismiss layer behind.
      MouseArea { anchors.fill: parent; onClicked: {} }

      // BorderSurface does NOT inset its children — `padding` only exposes
      // contentLeftInset and friends, which each child has to apply itself
      // (this is what /usr/share/omarchy/shell/plugins/clipboard/Clipboard.qml
      // does). Filling the parent instead bleeds covers, durations and the
      // player bar over the card's own border.
      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        focus: true

        Keys.onEscapePressed: root.goBack()
        Keys.onPressed: function (event) {
          if (!root.service) return
          switch (event.key) {
            case Qt.Key_Space:
              root.service.togglePlayback(); event.accepted = true; break
            case Qt.Key_Right:
              root.service.next(); event.accepted = true; break
            case Qt.Key_Left:
              root.service.previous(); event.accepted = true; break
            case Qt.Key_Slash:
              root.statusSelected = false
              root.service.goTo(Model.VIEW_SEARCH)
              header.focusSearch()
              event.accepted = true
              break
          }
        }

        // ---- Sidebar -----------------------------------------------------

        QobuzSidebar {
          id: sidebar
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: player.top
          anchors.bottomMargin: Style.space(12)
          width: Style.space(230)
          bar: root.shell && root.shell.bar ? root.shell.bar : null
          service: root.service
          statusSelected: root.statusSelected
          onStatusRequested: root.statusSelected = true
        }

        Rectangle {
          anchors.left: sidebar.right
          anchors.leftMargin: Style.space(14)
          anchors.top: parent.top
          anchors.bottom: player.top
          anchors.bottomMargin: Style.space(12)
          width: Math.max(1, Style.space(1))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
        }

        // ---- Main area ---------------------------------------------------

        Item {
          id: main
          anchors.left: sidebar.right
          anchors.leftMargin: Style.space(28)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.top: parent.top
          anchors.bottom: player.top
          anchors.bottomMargin: Style.space(12)

          QobuzAppHeader {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            bar: root.shell && root.shell.bar ? root.shell.bar : null
            service: root.service
            title: root.headerTitle
            showBack: root.browsing
            searchVisible: !root.statusSelected && root.playerState.view === Model.VIEW_SEARCH
            onBackRequested: if (root.service) root.service.closeBrowse()
            onCloseRequested: root.close()
          }

          Flickable {
            id: scroller
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Style.space(14)
            anchors.bottom: parent.bottom
            // Without an explicit contentWidth the content item does not track
            // the Flickable's width, and anything sizing off `parent.width`
            // computes its layout from the wrong number — which is how the
            // cover grid ended up one column wider than the card.
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: body
              // Cap the measure: a track list stretched across a 3000px
              // monitor puts the duration a screen away from the title.
              width: Math.min(scroller.width, Style.space(1180))
              spacing: Style.space(18)

              // Status is app-only and wins over the shared view.
              QobuzStatusView {
                width: parent.width
                bar: header.bar
                service: root.service
                visible: root.statusSelected
              }

              QobuzAppContent {
                width: parent.width
                bar: header.bar
                service: root.service
                visible: !root.statusSelected
              }
            }
          }
        }

        // ---- Player bar --------------------------------------------------

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.bottom: player.top
          height: Math.max(1, Style.space(1))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
        }

        QobuzPlayerBar {
          id: player
          anchors.left: parent.left
          anchors.right: parent.right
          // Match the main area's right inset so the volume slider lines up
          // with the content above it rather than reaching further out.
          anchors.rightMargin: Style.space(10)
          anchors.bottom: parent.bottom
          bar: header.bar
          service: root.service
        }
      }
    }
  }

  readonly property string headerTitle: {
    if (statusSelected) return "Estado"
    if (browsing) return playerState.browse ? playerState.browse.title : "Cargando…"
    switch (playerState.view) {
      case Model.VIEW_SEARCH: return "Buscar"
      case Model.VIEW_LIBRARY: {
        switch (playerState.libraryType) {
          case "tracks": return "Pistas favoritas"
          case "artists": return "Artistas favoritos"
          case "playlists": return "Tus playlists"
          default: return "Álbumes favoritos"
        }
      }
      case Model.VIEW_LYRICS: return "Letra"
      case Model.VIEW_QUEUE: return "Cola"
      default: return "Descubrir"
    }
  }
}
