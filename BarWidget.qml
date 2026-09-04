import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Ui
import "QobuzModel.js" as Model

// Pattern A (same shape as dimitar.openvpn): the widget root IS the Panel, so
// Bar.findPanelWidget can route `omarchy-shell shell toggle javih.qobuz` to
// it. That routing requires open() / close() / opened on the *root* — Panel
// provides all three.
Panel {
  id: root
  moduleName: "javih.qobuz"
  ipcTarget: "javih.qobuz"
  manageIpc: false   // own IpcHandler below adds refresh/status

  // The service is the single owner of the qbzd connection; the bar
  // instantiates this widget once per monitor, so per-widget polling would
  // multiply the work. serviceFor resolves any enabled plugin, not just
  // first-party ones (shell.qml:275).
  readonly property var service: bar?.shell?.serviceFor("javih.qobuz")
  readonly property var playerState: service ? service.playerState : Model.emptyState()

  // Settings arrive inline on the shell.json layout entry and are re-pushed
  // live by BarModel.inlineSettingsDelta, so read them as bindings — never
  // once in Component.onCompleted.
  readonly property string hostSetting: setting("host", "127.0.0.1:8182")
  readonly property bool showLabel: setting("showLabel", true) !== false
  readonly property int maxLabelChars: setting("maxLabelChars", 32)
  readonly property bool hideWhenIdle: setting("hideWhenIdle", false) === true
  readonly property string languageSetting: setting("language", "auto")

  function t(key, a, b) { return service ? service.t(key, a, b) : String(key) }

  // Ui/Panel is a bare Item — unlike Ui/BarWidget it carries no `vertical` —
  // so the rail check below read `undefined` and a vertical bar never
  // collapsed to the glyph the way the manifest says it does.
  readonly property bool vertical: bar ? bar.vertical : false

  readonly property bool idle: !playerState.track && playerState.playback === Model.PLAYBACK_STOPPED
  readonly property var labelFallbacks: ({
    daemonDown: "qbzd",
    noSession: t("state.noSession"),
    idle: t("app.name")
  })

  // The mark is the widget; the title is what it says while music is coming
  // out. Nothing playing — paused, stopped, no session, no daemon — leaves the
  // mark on its own rather than a stale title or a transport glyph the bar
  // cannot act on, and the tooltip still has the detail for all of those.
  readonly property bool playing: playerState.playback === Model.PLAYBACK_PLAYING
  readonly property string label: root.vertical || !showLabel || !playing
    ? "" : Model.trackLabel(playerState, maxLabelChars, labelFallbacks)

  readonly property string tooltip: {
    if (!playerState.daemonUp) return t("state.daemonDown", hostSetting)
    if (playerState.authState === "needs_auth") return t("state.noSessionTooltip")
    if (!playerState.track) return t("state.nothingPlayingTooltip")
    var q = Model.qualityLabel(playerState.track)
    return Model.trackLabel(playerState, 0, labelFallbacks) + (q ? "  ·  " + q : "")
  }

  // Services get no `settings` injection, so the widget hands the host over.
  function syncService() {
    if (!service) return
    if (service.host !== hostSetting) service.host = hostSetting
    if (service.languageSetting !== languageSetting) service.languageSetting = languageSetting
  }
  onServiceChanged: syncService()
  onHostSettingChanged: syncService()
  onLanguageSettingChanged: syncService()
  Component.onCompleted: syncService()

  visible: !(hideWhenIdle && idle)
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  onOpenedChanged: {
    if (!opened) return
    if (service) service.refresh()
    Qt.callLater(function () { keys.forceActiveFocus() })
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    // One widget instance exists per monitor: broadcast so every screen
    // refreshes, not just whichever one answered the IPC call.
    function refresh(): string { root.broadcast("refreshFromIpc"); return "ok" }
    function status(): string { return root.tooltip }
    // Lets a Hyprland binding or a script drop a query straight into the
    // panel: `omarchy-shell javih.qobuz search "kind of blue"`.
    function search(query: string): string {
      if (!root.service) return "no service"
      // Results need room, so this opens the app rather than the panel.
      if (root.bar && root.bar.shell) root.bar.shell.summon("javih.qobuz", "{}")
      root.service.goTo(Model.VIEW_SEARCH)
      root.service.search(query)
      return "searching: " + query
    }
    // Jump the panel straight to a section, for a keybinding or a script:
    // `omarchy-shell javih.qobuz view library`.
    function view(name: string): string {
      if (!root.service) return "no service"
      var wanted = String(name).toLowerCase()
      var allowed = [Model.VIEW_QUEUE, Model.VIEW_SEARCH, Model.VIEW_LIBRARY,
                     Model.VIEW_DISCOVER, Model.VIEW_LYRICS]
      if (allowed.indexOf(wanted) === -1) return "unknown view: " + wanted + " (" + allowed.join(", ") + ")"
      if (root.bar && root.bar.shell) root.bar.shell.summon("javih.qobuz", "{}")
      root.service.goTo(wanted)
      return wanted
    }
    // Open the library on one of its four kinds. `view library` lands on
    // whichever kind was last loaded, which is no good for a script — or for
    // retaking the README's screenshots:
    // `omarchy-shell javih.qobuz library tracks`.
    function library(kind: string): string {
      if (!root.service) return "no service"
      var wanted = String(kind).toLowerCase()
      var kinds = ["albums", "tracks", "artists", "playlists"]
      if (kinds.indexOf(wanted) === -1) return "unknown kind: " + wanted + " (" + kinds.join(", ") + ")"
      if (root.bar && root.bar.shell) root.bar.shell.summon("javih.qobuz", "{}")
      // Load first: goTo starts its own load when the library is empty, and
      // loadLibrary bails while one is already in flight.
      root.service.loadLibrary(wanted)
      root.service.goTo(Model.VIEW_LIBRARY)
      return wanted
    }
    // Open an album, artist or playlist page directly:
    // `omarchy-shell javih.qobuz browse album 5099749522428`.
    function browse(kind: string, id: string): string {
      if (!root.service) return "no service"
      var item = { kind: String(kind).toLowerCase(), id: String(id) }
      if (!Model.isBrowsable(item)) return "not browsable: " + item.kind + " (album, artist, playlist)"
      if (root.bar && root.bar.shell) root.bar.shell.summon("javih.qobuz", "{}")
      root.service.openItem(item)
      return "opening " + item.kind + " " + item.id
    }
    function results(): string {
      var r = root.playerState.search
      if (!r || r.total === 0) return root.playerState.searchError || "no results"
      var out = []
      var kinds = ["albums", "tracks", "artists", "playlists"]
      for (var i = 0; i < kinds.length; i++) {
        var list = r[kinds[i]] || []
        for (var j = 0; j < list.length; j++)
          out.push(kinds[i].slice(0, -1) + ": " + list[j].title
                   + (list[j].subtitle ? " — " + list[j].subtitle : ""))
      }
      return out.join("\n")
    }
  }

  function refreshFromIpc() { if (service) service.refresh() }

  // Qobuz's mark, and the track title beside it while something is playing.
  // WidgetButton centres its own label, which leaves no room next to it, so the
  // stock label is switched off and laid out below — the button still owns
  // hover, the tooltip, clicks and the dimming.
  WidgetButton {
    id: button
    bar: root.bar
    tooltipText: root.tooltip
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : Math.round(barContent.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.round(barContent.implicitHeight + scaledVerticalPadding * 2) : -1
    dimmed: !root.playerState.daemonUp || root.playerState.authState === "needs_auth"
    active: root.opened

    // Two cells: the mark, and the title when there is one. Grid rather than
    // Row for the vertical centring, and it closes the row up on its own when
    // the title cell goes invisible — which is most of the time, so the mark
    // has to stand alone without looking like something failed to load.
    Grid {
      id: barContent
      anchors.centerIn: parent
      columns: 2
      spacing: Style.space(6)
      verticalItemAlignment: Grid.AlignVCenter

      // What the button would have painted its own label in. The mark and the
      // title share it so the pair turns together.
      readonly property color ink: button.active && button.useActiveColor
                                 ? button.activeColor : button.foreground

      // The single-colour "qbz" wordmark, tinted to whatever the button is
      // painting in so it follows the theme like a glyph would. See
      // assets/README.md on the trademark. The mark is now the only thing the
      // widget is guaranteed to show, so if Qt's SVG subset ever fails on it
      // the note glyph takes the slot rather than leaving the bar blank.
      Item {
        id: markSlot
        implicitHeight: Math.round(button.fontSize * 1.15)
        implicitWidth: Math.round(implicitHeight * 138 / 97)   // the mark's aspect

        Image {
          id: barMark
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/qobuz-mark-symbolic.svg")
          // Twice the slot keeps it crisp on fractional scaling.
          sourceSize.width: Math.round(width * 2)
          sourceSize.height: Math.round(height * 2)
          fillMode: Image.PreserveAspectFit
          smooth: true
          visible: false   // painted through the effect below
        }

        MultiEffect {
          anchors.fill: barMark
          visible: barMark.status === Image.Ready
          source: barMark
          colorization: 1.0
          colorizationColor: barContent.ink
        }

        Text {
          anchors.centerIn: parent
          visible: barMark.status !== Image.Ready
          text: "󰝚"
          color: barContent.ink
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          renderType: Text.NativeRendering
          textFormat: Text.PlainText
        }
      }

      Text {
        id: barLabel
        visible: root.label !== ""
        text: root.label
        color: barContent.ink
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
        textFormat: Text.PlainText

        Behavior on color {
          enabled: !root.bar || root.bar.foregroundAnimationEnabled
          ColorAnimation { duration: 160 }
        }
      }
    }

    onPressed: function (code) {
      if (code === Qt.LeftButton) root.toggle()
      else if (code === Qt.MiddleButton && root.service) root.service.togglePlayback()
    }
    onWheelMoved: function (delta) {
      if (!root.service || !Model.canHandle(root.playerState, "volume")) return
      root.service.setVolume(root.playerState.volume + (delta > 0 ? 0.02 : -0.02))
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(content.implicitHeight + Style.space(28), Style.space(680))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onActivateRequested: if (root.service) root.service.togglePlayback()
      onMoveRequested: function (dx, dy) {
        if (!root.service) return
        if (dx > 0) root.service.next()
        else if (dx < 0) root.service.previous()
      }
      onTextKey: function (t) {
        if (!root.service) return
        var key = String(t).toLowerCase()
        if (key === " ") root.service.togglePlayback()
        else if (key === "r") root.service.refresh()
        else if (key === "s") root.service.toggleShuffle()
        else if (key === "l") root.service.cycleRepeat()
        // Anything that needs room opens the app instead.
        else if (key === "o" || key === "/") {
          if (root.bar && root.bar.shell) root.bar.shell.summon("javih.qobuz", "{}")
          root.close()
        }
      }

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          QobuzNowPlaying {
            width: parent.width
            bar: root.bar
            service: root.service
          }

          // ---- Degraded states, each with the one action that fixes it ----

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: !root.playerState.daemonUp

            PanelSeparator { width: parent.width; foreground: root.barForeground }

            Text {
              width: parent.width
              text: root.t("state.daemonDownHint", root.hostSetting)
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
            }

            Button {
              text: root.t("action.retry")
              bordered: true
              foreground: root.barForeground
              onClicked: if (root.service) root.service.refresh()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.playerState.daemonUp && root.playerState.authState === "needs_auth"

            PanelSeparator { width: parent.width; foreground: root.barForeground }

            Text {
              width: parent.width
              text: root.t("state.loginHint")
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
            }

            Button {
              text: root.t("action.login")
              bordered: true
              foreground: root.barForeground
              onClicked: {
                if (root.bar) root.bar.run("omarchy-launch-terminal qbzd login")
                root.close()
              }
            }
          }

          // ---- Normal operation -------------------------------------------
          //
          // The panel is deliberately the glanceable half: what is playing,
          // the transport and what comes next. Searching, the library,
          // discover and detail pages live in the full-screen app, which
          // shares this very same service instance.

          readonly property bool live: root.playerState.daemonUp
                                       && root.playerState.authState !== "needs_auth"

          PanelSeparator {
            width: parent.width
            foreground: root.barForeground
            visible: content.live
          }

          QobuzTransport {
            width: parent.width
            bar: root.bar
            service: root.service
            visible: content.live
          }

          PanelSeparator {
            width: parent.width
            foreground: root.barForeground
            visible: content.live
          }

          Button {
            width: parent.width
            visible: content.live
            text: root.t("action.openApp")
            iconText: "󰊓"
            bordered: true
            leftAlign: true
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onClicked: {
              // shell.summon routes to the overlay, not back to this panel:
              // declaring the overlay kind takes the plugin off the
              // bar-widget path in shell.qml's isBarWidgetPanelPlugin.
              if (root.bar && root.bar.shell) root.bar.shell.summon("javih.qobuz", "{}")
              root.close()
            }
          }

          QobuzQueueView {
            width: parent.width
            bar: root.bar
            service: root.service
            visible: content.live
          }

        }
      }
    }
  }
}
