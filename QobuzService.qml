import QtQuick
import Quickshell.Io
import "QobuzModel.js" as Model

// Headless singleton: owns the one connection to qbzd and the one copy of the
// playback state. Declared as a `service` kind because the bar instantiates a
// bar widget *per monitor* — polling and the event stream must not be
// duplicated per screen. Reached from the widget with
// `bar.shell.serviceFor("javih.qobuz")`.
//
// shell.qml injects `shell`, `manifest`, `pluginRegistry` and friends into
// service roots, but NOT `settings` — the widget pushes `host` in instead.
Item {
  id: service
  visible: false

  property var shell: null
  property var manifest: null

  property string host: "127.0.0.1:8182"

  // The whole reduced state, replaced wholesale so QML bindings re-evaluate.
  property var playerState: Model.emptyState()

  readonly property bool daemonUp: playerState.daemonUp
  readonly property bool authenticated: playerState.authState === "ok"
  readonly property bool needsAuth: playerState.authState === "needs_auth"
  readonly property bool playing: playerState.playback === Model.PLAYBACK_PLAYING
  readonly property var track: playerState.track

  // Prefer the cover resolved from /api/album. qbzd's own
  // /api/artwork/current 404s for anything queued from an album id, because it
  // derives from the track's artwork_url, which qbzd leaves null — it is only
  // a fallback for the cases where qbzd did fill that field in. Qt follows its
  // 302 and sends no Origin header, so the CSRF guard stays happy; the ?t= is
  // cache-busting between tracks.
  readonly property string artworkUrl: {
    if (!playerState.track || !playerState.track.id) return ""
    if (playerState.track.artworkUrl) return playerState.track.artworkUrl
    return "http://" + host + "/api/artwork/current?t=" + playerState.track.id
  }

  readonly property string loginHint: "qbzd login"

  // Resolve bundled helpers from this QML file so the plugin works from any
  // plugin directory and from checkouts with spaces in the path.
  function bundledPath(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  readonly property string apiHelper: bundledPath("bin/qbzd-api")
  readonly property string eventsHelper: bundledPath("bin/qbzd-events")
  readonly property var helperEnv: ({ "QBZD_HOST": host })

  function apply(next) {
    playerState = next
  }

  function parseJson(text) {
    try {
      return JSON.parse(String(text || "").trim() || "{}")
    } catch (e) {
      return null
    }
  }

  // ---- Reads -------------------------------------------------------------

  function refreshStatus() {
    if (statusProcess.running) return
    statusProcess.command = [apiHelper, "/api/status"]
    statusProcess.running = true
  }

  function refreshQueue() {
    if (queueProcess.running) return
    queueProcess.command = [apiHelper, "/api/queue"]
    queueProcess.running = true
  }

  function refreshNowPlaying() {
    if (nowPlayingProcess.running || !authenticated) return
    nowPlayingProcess.command = [apiHelper, "/api/now-playing"]
    nowPlayingProcess.running = true
  }

  // qbzd never resolves a track's cover or album title (artwork_url is null,
  // album is "Unknown Album", and /api/artwork/current 404s as a result), but
  // it does tell us which album the track was played from. One lookup per
  // album fills in both.
  property string albumFetched: ""

  function refreshAlbum() {
    if (albumProcess.running || !authenticated) return
    var id = Model.albumLookupId(playerState)
    if (id === "" || id === albumFetched) return
    albumFetched = id
    albumProcess.command = [apiHelper, "/api/album?id=" + encodeURIComponent(id)]
    albumProcess.running = true
  }

  function refresh() {
    refreshStatus()
    refreshQueue()
  }

  // ---- Writes ------------------------------------------------------------

  // Fire-and-forget: every mutation is confirmed by the next status poll or by
  // an event, so nothing here has to parse its own response.
  function post(path, body) {
    if (!daemonUp && path !== "/api/status") return
    commandProcess.running = false
    commandProcess.command = body === undefined || body === null
      ? [apiHelper, "-X", "POST", path]
      : [apiHelper, "-d", JSON.stringify(body), path]
    commandProcess.running = true
  }

  function togglePlayback() { if (Model.canHandle(playerState, "playPause")) post("/api/playback/toggle", {}) }
  function next()           { if (Model.canHandle(playerState, "next")) post("/api/playback/next", {}) }
  // The route is /previous — /prev is a CLI alias only and 404s over HTTP.
  function previous()       { if (Model.canHandle(playerState, "previous")) post("/api/playback/previous", {}) }

  function seek(seconds) {
    if (!Model.canHandle(playerState, "seek")) return
    var target = Math.max(0, Math.min(playerState.duration, Math.round(seconds)))
    // Optimistic: the slider must not snap back while the poll catches up.
    post("/api/playback/seek", { position: target })
    apply(Object.assign({}, playerState, { position: target }))
  }

  function setVolume(value) {
    var v = Math.max(0, Math.min(1, value))
    post("/api/playback/volume", { volume: v })
    apply(Object.assign({}, playerState, { volume: v }))
  }

  function toggleShuffle() { post("/api/playback/shuffle", { mode: "toggle" }) }

  function cycleRepeat() {
    var order = ["off", "all", "one"]
    var idx = order.indexOf(playerState.repeat)
    post("/api/playback/repeat", { mode: order[(idx + 1) % order.length] })
  }

  function queueJump(index) {
    if (index < 0) return
    post("/api/queue/jump", { index: index })
  }

  function queueClear() { post("/api/queue/clear", {}) }

  // ---- Search ------------------------------------------------------------

  property string searchQuery: ""
  property int searchLimit: 8

  function search(query) {
    var q = String(query || "").trim()
    searchQuery = q
    if (q === "") { clearSearch(); return }
    if (!authenticated) return
    apply(Object.assign({}, playerState, { searchRunning: true, searchError: "" }))
    searchProcess.running = false
    searchProcess.command = [apiHelper,
      "/api/search?q=" + encodeURIComponent(q) + "&type=all&limit=" + searchLimit]
    searchProcess.running = true
  }

  function clearSearch() {
    searchQuery = ""
    apply(Object.assign({}, playerState, {
      search: Model.normalizeSearch(null), searchRunning: false, searchError: ""
    }))
  }

  // Replace what is playing with this album/track/artist/playlist.
  function playItem(item) {
    var body = Model.playBodyFor(item)
    if (!body) return
    post("/api/play", body)
  }

  // Append a single track without disturbing what is playing.
  function queueTrack(item) {
    if (!item || item.kind !== "track" || !item.id) return
    post("/api/queue/add", { track_ids: [Number(item.id)] })
  }

  // ---- Reads: process plumbing -------------------------------------------

  Process {
    id: statusProcess
    environment: service.helperEnv
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var payload = service.parseJson(text)
        if (payload === null) return
        var before = service.playerState.track ? service.playerState.track.id : ""
        var afterState = Model.applyStatus(service.playerState, payload)
        service.apply(afterState)
        // Status carries only a flat title/artist; pull the rich metadata
        // once per track change rather than on every poll.
        var after = afterState.track ? afterState.track.id : ""
        if (after !== "" && after !== before) service.refreshNowPlaying()
      }
    }
    onExited: function (code) {
      if (code === 3) service.apply(Object.assign({}, service.playerState, { daemonUp: false }))
      pollTimer.interval = Model.pollIntervalMs(service.playerState)
    }
  }

  Process {
    id: queueProcess
    environment: service.helperEnv
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var payload = service.parseJson(text)
        if (payload !== null) service.apply(Model.applyQueue(service.playerState, payload))
      }
    }
  }

  Process {
    id: nowPlayingProcess
    environment: service.helperEnv
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var payload = service.parseJson(text)
        if (payload === null) return
        service.apply(Model.applyNowPlaying(service.playerState, payload))
        // now-playing is where contextId first appears, so the album lookup
        // can only be decided after it lands.
        service.refreshAlbum()
      }
    }
  }

  Process {
    id: searchProcess
    environment: service.helperEnv
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var payload = service.parseJson(text)
        service.apply(Model.applySearch(service.playerState, payload, service.searchQuery))
      }
    }
    onExited: function (code) {
      if (code === 0) return
      // A failed search must not leave the spinner up forever.
      service.apply(Object.assign({}, service.playerState, {
        searchRunning: false,
        searchError: code === 3 ? "qbzd no responde"
                   : (code === 4 ? "Sin sesión" : "La búsqueda falló")
      }))
    }
  }

  Process {
    id: albumProcess
    environment: service.helperEnv
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var payload = service.parseJson(text)
        if (payload !== null) service.apply(Model.applyAlbum(service.playerState, payload))
      }
    }
  }

  Process {
    id: commandProcess
    environment: service.helperEnv
    stdout: StdioCollector { waitForEnd: true }
    onExited: function (code) {
      // A mutation lands before the next scheduled poll; reconcile at once.
      if (code === 0) service.refresh()
      else if (code === 3) service.apply(Object.assign({}, service.playerState, { daemonUp: false }))
    }
  }

  // ---- Events: the accelerator, not the source of truth -------------------

  // Measured on qbzd 2.0.2: /api/events sends zero bytes — not even HTTP
  // headers — until the first event fires, so an idle stream and a dead one
  // look identical. Hence pollTimer below is the real heartbeat and this
  // stream only shortens the latency when something actually happens.
  Process {
    id: eventProcess
    environment: service.helperEnv
    command: [service.eventsHelper]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function (line) {
        var event = service.parseJson(line)
        if (!event) return
        service.apply(Model.reduceEvent(service.playerState, event))
        if (Model.needsQueueRefetch(event)) service.refreshQueue()
        if (String(event.type) === "TrackStarted") service.refreshNowPlaying()
        pollTimer.interval = Model.pollIntervalMs(service.playerState)
      }
    }
    onExited: eventRestartTimer.restart()
  }

  Timer {
    id: eventRestartTimer
    interval: 5000
    repeat: false
    onTriggered: if (!eventProcess.running) eventProcess.running = true
  }

  // ---- Heartbeat ---------------------------------------------------------

  Timer {
    id: pollTimer
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      service.refreshStatus()
      // The queue changes far less often than playback position.
      if (queueTick >= 3) { queueTick = 0; service.refreshQueue() } else queueTick++
      interval = Model.pollIntervalMs(service.playerState)
    }
    property int queueTick: 0
  }

  // Position between polls. qbzd reports position on /api/status and in
  // PositionUpdated events, but neither arrives every second.
  Timer {
    interval: 1000
    repeat: true
    running: service.playing && service.playerState.duration > 0
    onTriggered: {
      var pos = Math.min(service.playerState.duration, service.playerState.position + 1)
      service.apply(Object.assign({}, service.playerState, { position: pos }))
    }
  }

  Component.onCompleted: {
    eventProcess.running = true
    refresh()
  }
}
