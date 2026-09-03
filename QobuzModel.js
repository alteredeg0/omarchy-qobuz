// Pure state logic for the Qobuz widget. No QML imports here so the whole
// reducer can run under `node --test` — same split as Omarchy's own
// /usr/share/omarchy/shell/plugins/services/media/MediaModel.js.
//
// Shapes were captured from a live qbzd 2.0.2 (see tests/fixtures/), not from
// the wiki: the wiki's /api/queue documents a `tracks` array, the daemon
// actually returns `upcoming` + `history` + `current_track`.

var PLAYBACK_STOPPED = "stopped"
var PLAYBACK_PLAYING = "playing"
var PLAYBACK_PAUSED = "paused"

// Verbatim from the qbzd binary's event enum.
var EVENT_TYPES = [
  "TrackStarted", "TrackEnded", "PlaybackStateChanged", "PositionUpdated",
  "VolumeChanged", "QueueUpdated", "ShuffleChanged", "RepeatModeChanged",
  "FavoritesUpdated", "PlaylistCreated", "PlaylistUpdated", "PlaylistDeleted",
  "LoggedIn", "LoggedOut"
]

function emptyState() {
  return {
    daemonUp: false,
    authState: "unknown",     // "unknown" | "needs_auth" | "ok"
    subscription: "",
    playback: PLAYBACK_STOPPED,
    position: 0,
    duration: 0,
    volume: 0,
    muted: false,
    shuffle: false,
    repeat: "off",            // "off" | "all" | "one"
    track: null,
    queueLength: 0,
    queueIndex: -1,
    upcoming: [],
    lastError: ""
  }
}

function num(value, fallback) {
  var n = Number(value)
  return isFinite(n) ? n : fallback
}

function str(value) {
  return value === null || value === undefined ? "" : String(value)
}

// qbzd spells the same field several ways across endpoints (status carries a
// flat title/artist, now-playing a nested track object), so accept both.
function normalizeTrack(raw) {
  if (!raw) return null
  var id = str(raw.id !== undefined ? raw.id : raw.track_id)
  var title = str(raw.title)
  if (!id && !title) return null
  return {
    id: id,
    title: title,
    artist: str(raw.artist_name || raw.artist || raw.performer),
    album: str(raw.album_title || raw.album),
    artworkUrl: str(raw.artwork_url || raw.album_image_url || raw.image),
    duration: num(raw.duration_secs !== undefined ? raw.duration_secs : raw.duration, 0),
    sampleRate: num(raw.sample_rate, 0),
    bitDepth: num(raw.bit_depth, 0),
    hires: raw.hires === true
  }
}

// "off" | "all" | "one" — the daemon emits the Rust enum casing (Off/All/One)
// on events but lowercase in /api/queue.
function normalizeRepeat(value) {
  var v = str(value).toLowerCase()
  return (v === "all" || v === "one") ? v : "off"
}

function normalizePlayback(value) {
  var v = str(value).toLowerCase()
  if (v === PLAYBACK_PLAYING || v === PLAYBACK_PAUSED) return v
  return PLAYBACK_STOPPED
}

// /api/status — the backbone. Works without a Qobuz session, which is what
// makes it usable as the heartbeat.
function applyStatus(state, status) {
  var next = shallowCopy(state)
  if (!status || typeof status !== "object") return next

  var err = errorOf(status)
  if (err) {
    next.lastError = err.message
    if (err.code === "needs_auth") next.authState = "needs_auth"
    return next
  }

  next.daemonUp = true
  next.lastError = ""

  var auth = status.auth || {}
  var authState = str(auth.state)
  next.authState = authState === "" ? "unknown" : (authState === "needs_auth" ? "needs_auth" : "ok")
  next.subscription = str(auth.subscription)

  var pb = status.playback || {}
  next.playback = normalizePlayback(pb.state)
  next.position = num(pb.position, 0)
  next.duration = num(pb.duration, 0)
  next.volume = num(pb.volume, next.volume)
  next.muted = pb.muted === true
  next.queueLength = num(pb.queue_len, 0)

  // Status only carries a flat title/artist; keep the richer track from
  // /api/now-playing when it describes the same id.
  var flat = normalizeTrack(pb)
  if (flat) {
    var keep = state.track && state.track.id && flat.id && state.track.id === flat.id
    next.track = keep ? state.track : flat
  } else {
    next.track = null
  }
  return next
}

// /api/now-playing — richer, but 409s with needs_auth when logged out.
function applyNowPlaying(state, payload) {
  var next = shallowCopy(state)
  if (!payload || typeof payload !== "object") return next

  var err = errorOf(payload)
  if (err) {
    if (err.code === "needs_auth") next.authState = "needs_auth"
    else next.lastError = err.message
    return next
  }

  var track = normalizeTrack(payload.track || payload)
  if (track) {
    next.track = track
    if (track.duration > 0) next.duration = track.duration
  } else if (payload.track === null) {
    next.track = null
  }
  if (payload.position_secs !== undefined) next.position = num(payload.position_secs, next.position)
  if (payload.state !== undefined) next.playback = normalizePlayback(payload.state)
  return next
}

// /api/queue — note `upcoming`/`history`, not the wiki's `tracks`.
function applyQueue(state, payload) {
  var next = shallowCopy(state)
  if (!payload || typeof payload !== "object" || errorOf(payload)) return next

  next.shuffle = payload.shuffle === true
  next.repeat = normalizeRepeat(payload.repeat)
  next.queueLength = num(payload.total_tracks, 0)
  next.queueIndex = payload.current_index === null || payload.current_index === undefined
    ? -1 : num(payload.current_index, -1)

  var upcoming = []
  var raw = payload.upcoming
  if (raw && raw.length) {
    for (var i = 0; i < raw.length; i++) {
      var t = normalizeTrack(raw[i])
      if (t) upcoming.push(t)
    }
  }
  next.upcoming = upcoming

  var current = normalizeTrack(payload.current_track)
  if (current) next.track = current
  return next
}

// One NDJSON line from bin/qbzd-events: {"type": ..., "data": {...}}
function reduceEvent(state, event) {
  var next = shallowCopy(state)
  if (!event || typeof event !== "object") return next

  var type = str(event.type || event.event)
  var data = event.data || {}
  if (!type) return next

  next.daemonUp = true

  switch (type) {
    case "TrackStarted": {
      var track = normalizeTrack(data.track || data)
      if (track) {
        next.track = track
        if (track.duration > 0) next.duration = track.duration
      }
      next.position = num(data.position_secs, 0)
      next.playback = PLAYBACK_PLAYING
      break
    }
    case "TrackEnded":
      next.position = 0
      break
    case "PlaybackStateChanged":
      next.playback = normalizePlayback(data.state || data)
      break
    case "PositionUpdated":
      next.position = num(data.position_secs, next.position)
      if (data.duration_secs !== undefined) next.duration = num(data.duration_secs, next.duration)
      break
    case "VolumeChanged":
      next.volume = num(data.volume, next.volume)
      if (data.muted !== undefined) next.muted = data.muted === true
      break
    case "ShuffleChanged":
      next.shuffle = (data.shuffle !== undefined ? data.shuffle : data) === true
      break
    case "RepeatModeChanged":
      next.repeat = normalizeRepeat(data.repeat !== undefined ? data.repeat : (data.mode !== undefined ? data.mode : data))
      break
    case "LoggedIn":
      next.authState = "ok"
      break
    case "LoggedOut":
      next.authState = "needs_auth"
      next.track = null
      next.playback = PLAYBACK_STOPPED
      break
    // QueueUpdated / Favorites* / Playlist* carry no state we mirror inline;
    // the service refetches /api/queue when it sees them.
  }
  return next
}

// Events that mean "go refetch, the inline payload is not enough".
function needsQueueRefetch(event) {
  var type = event && str(event.type || event.event)
  return type === "QueueUpdated" || type === "TrackStarted" || type === "TrackEnded"
}

function errorOf(payload) {
  if (!payload || typeof payload !== "object" || !payload.error) return null
  var e = payload.error
  return { code: str(e.code), message: str(e.message), hint: str(e.hint) }
}

// The daemon reports needs_auth as HTTP 409, which bin/qbzd-api maps to 4.
function exitCodeMeaning(code) {
  switch (num(code, -1)) {
    case 0: return "ok"
    case 3: return "unreachable"
    case 4: return "needs_auth"
    case 5: return "audio"
    case 6: return "not_found"
    default: return "error"
  }
}

// Adaptive heartbeat. /api/events stays byte-silent while idle (no HTTP
// headers at all until the first event on qbzd 2.0.2), so polling is what
// actually proves the daemon is alive — but it can be lazy when nothing moves.
function pollIntervalMs(state) {
  if (!state.daemonUp) return 15000
  if (state.authState === "needs_auth") return 10000
  if (state.playback === PLAYBACK_PLAYING) return 1000
  return 5000
}

function canHandle(state, action) {
  if (!state.daemonUp || state.authState === "needs_auth") return false
  switch (action) {
    case "playPause": return !!state.track || state.queueLength > 0
    case "next": return state.queueLength > 0
    case "previous": return state.queueLength > 0 || state.position > 3
    case "seek": return state.duration > 0
    case "volume": return true
    default: return false
  }
}

function formatDuration(seconds) {
  var total = Math.max(0, Math.floor(num(seconds, 0)))
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  var s = total % 60
  var pad = function (n) { return n < 10 ? "0" + n : String(n) }
  return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
}

// "24-bit 192 kHz" / "Hi-Res" / "" — shown as a badge next to the title.
function qualityLabel(track) {
  if (!track) return ""
  var parts = []
  if (track.bitDepth > 0) parts.push(track.bitDepth + "-bit")
  if (track.sampleRate > 0) {
    var khz = track.sampleRate > 1000 ? track.sampleRate / 1000 : track.sampleRate
    parts.push((Math.round(khz * 10) / 10) + " kHz")
  }
  if (parts.length) return parts.join(" ")
  return track.hires ? "Hi-Res" : ""
}

function trackLabel(state, maxChars) {
  if (!state.daemonUp) return "qbzd"
  if (state.authState === "needs_auth") return "Sin sesión"
  if (!state.track) return "Qobuz"
  var text = state.track.artist
    ? state.track.artist + " — " + state.track.title
    : state.track.title
  var limit = num(maxChars, 0)
  if (limit > 3 && text.length > limit) return text.slice(0, limit - 1).trim() + "…"
  return text
}

function progressFraction(state) {
  if (!state.duration || state.duration <= 0) return 0
  return Math.min(1, Math.max(0, state.position / state.duration))
}

function shallowCopy(source) {
  var out = {}
  for (var key in source) {
    if (Object.prototype.hasOwnProperty.call(source, key)) out[key] = source[key]
  }
  return out
}

// Node-only: QML loads this file as a JS library and ignores the export.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    PLAYBACK_STOPPED: PLAYBACK_STOPPED,
    PLAYBACK_PLAYING: PLAYBACK_PLAYING,
    PLAYBACK_PAUSED: PLAYBACK_PAUSED,
    EVENT_TYPES: EVENT_TYPES,
    emptyState: emptyState,
    normalizeTrack: normalizeTrack,
    normalizeRepeat: normalizeRepeat,
    normalizePlayback: normalizePlayback,
    applyStatus: applyStatus,
    applyNowPlaying: applyNowPlaying,
    applyQueue: applyQueue,
    reduceEvent: reduceEvent,
    needsQueueRefetch: needsQueueRefetch,
    errorOf: errorOf,
    exitCodeMeaning: exitCodeMeaning,
    pollIntervalMs: pollIntervalMs,
    canHandle: canHandle,
    formatDuration: formatDuration,
    qualityLabel: qualityLabel,
    trackLabel: trackLabel,
    progressFraction: progressFraction
  }
}
