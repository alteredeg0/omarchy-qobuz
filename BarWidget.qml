import QtQuick
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

  readonly property bool idle: !playerState.track && playerState.playback === Model.PLAYBACK_STOPPED
  readonly property string playGlyph: playerState.playback === Model.PLAYBACK_PLAYING ? "󰏤" : "󰐊"
  readonly property string label: root.vertical || !showLabel
    ? "" : Model.trackLabel(playerState, maxLabelChars)

  readonly property string tooltip: {
    if (!playerState.daemonUp) return "qbzd no responde en " + hostSetting
    if (playerState.authState === "needs_auth") return "Qobuz — sin sesión (qbzd login)"
    if (!playerState.track) return "Qobuz — nada sonando"
    var q = Model.qualityLabel(playerState.track)
    return Model.trackLabel(playerState, 0) + (q ? "  ·  " + q : "")
  }

  // Services get no `settings` injection, so the widget hands the host over.
  function syncService() {
    if (service && service.host !== hostSetting) service.host = hostSetting
  }
  onServiceChanged: syncService()
  onHostSettingChanged: syncService()
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
  }

  function refreshFromIpc() { if (service) service.refresh() }

  WidgetButton {
    id: button
    bar: root.bar
    tooltipText: root.tooltip
    text: root.label === "" ? root.playGlyph : root.playGlyph + "  " + root.label
    dimmed: !root.playerState.daemonUp || root.playerState.authState === "needs_auth"
    active: root.opened
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
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight + Style.space(28), Style.space(620))

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
              text: "qbzd no responde en " + root.hostSetting + ".\nArráncalo con: systemctl --user start qbzd"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
            }

            Button {
              text: "Reintentar"
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
              text: "El login de Qobuz es OAuth por navegador; se abrirá una terminal."
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
            }

            Button {
              text: "Iniciar sesión"
              bordered: true
              foreground: root.barForeground
              onClicked: {
                if (root.bar) root.bar.run("omarchy-launch-terminal qbzd login")
                root.close()
              }
            }
          }

          // ---- Normal operation -------------------------------------------

          PanelSeparator {
            width: parent.width
            foreground: root.barForeground
            visible: root.playerState.daemonUp && root.playerState.authState !== "needs_auth"
          }

          QobuzTransport {
            width: parent.width
            bar: root.bar
            service: root.service
            visible: root.playerState.daemonUp && root.playerState.authState !== "needs_auth"
          }

          PanelSeparator {
            width: parent.width
            foreground: root.barForeground
            visible: root.playerState.daemonUp && root.playerState.authState === "ok"
          }

          QobuzQueueView {
            width: parent.width
            bar: root.bar
            service: root.service
            visible: root.playerState.daemonUp && root.playerState.authState === "ok"
          }
        }
      }
    }
  }
}
