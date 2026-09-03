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
    lastError: "",
    search: { query: "", albums: [], tracks: [], artists: [], playlists: [], total: 0 },
    searchRunning: false,
    searchError: "",

    // Which section of the panel is on screen below the transport.
    view: VIEW_QUEUE,
    // Favourites and the user's own playlists.
    libraryType: "albums",   // "albums" | "tracks" | "artists" | "playlists"
    library: [],
    libraryRunning: false,
    // A drilled-into album, artist or playlist. Null when not browsing.
    browse: null,
    browseRunning: false,
    // Where "back" returns to, so browse can be entered from any view.
    browseFrom: VIEW_QUEUE,
    discover: [],
    discoverRunning: false,
    lyrics: null,
    lyricsRunning: false,
    // The diagnostic half of /api/status, which the bar has no room for but
    // the app's status page shows: audio backend, device, Connect, errors.
    daemon: null
  }
}

var VIEW_QUEUE = "queue"
var VIEW_SEARCH = "search"
var VIEW_LIBRARY = "library"
var VIEW_DISCOVER = "discover"
var VIEW_BROWSE = "browse"
var VIEW_LYRICS = "lyrics"

function num(value, fallback) {
  var n = Number(value)
  return isFinite(n) ? n : fallback
}

function str(value) {
  return value === null || value === undefined ? "" : String(value)
}

// The same logical field is a plain string on the playback endpoints and a
// nested object on the catalogue ones: now-playing's `artist` is "Miles
// Davis", search's `performer` is {id, name, ...} and its `album` is
// {id, title, image, ...}. Unwrap both rather than stringifying an object.
function nameOf(value) {
  if (value === null || value === undefined) return ""
  if (typeof value !== "object") return str(value)
  // Artist pages and release lists nest one level deeper again:
  // {name: {display: "Miles Davis"}}, and sometimes just {display: ...}.
  if (value.display !== undefined) return str(value.display)
  var inner = value.name !== undefined ? value.name : value.title
  if (inner && typeof inner === "object") return str(inner.display || inner.name || inner.title)
  return str(inner)
}

// Albums name their artist in one of two places and never both: search and
// artist pages fill `artist`, the discover rails leave it null and fill
// `artists[]` instead. Credit the main artists, and don't let a long
// collaboration list swamp the row.
function artistsLabel(raw) {
  if (!raw) return ""
  var single = nameOf(raw.artist)
  if (single) return single

  var list = raw.artists
  if (!list || !list.length) return ""

  var main = []
  for (var i = 0; i < list.length; i++) {
    var roles = list[i] && list[i].roles
    var isMain = !roles || roles.length === 0 || roles.indexOf("main-artist") !== -1
    if (isMain) {
      var name = nameOf(list[i])
      if (name) main.push(name)
    }
  }
  if (!main.length) main = [nameOf(list[0])]
  if (main.length > 2) return main.slice(0, 2).join(", ") + " y " + (main.length - 2) + " más"
  return main.join(", ")
}

// qbzd fills `album` with the literal string "Unknown Album" for anything it
// has not resolved, and it never resolves it for tracks queued from an album
// id. Showing that to the user is worse than showing nothing — the real title
// arrives later via applyAlbum().
function albumTitle(raw) {
  var value = nameOf(raw.album_title !== undefined ? raw.album_title : raw.album)
  return value === "Unknown Album" ? "" : value
}

// Qobuz images come as {thumbnail, small, large, extralarge, mega}, any of
// which may be null. Playlists use images150/images300 arrays instead.
function imageUrl(raw, preferLarge) {
  if (!raw) return ""
  var img = raw.image || raw
  if (img && typeof img === "object" && !Array.isArray(img)) {
    var order = preferLarge
      ? ["large", "extralarge", "small", "thumbnail", "mega"]
      : ["small", "thumbnail", "large", "extralarge", "mega"]
    for (var i = 0; i < order.length; i++) {
      var candidate = str(img[order[i]])
      if (candidate) return candidate
    }
  }
  var arrays = [raw.images300, raw.images150, raw.images]
  for (var j = 0; j < arrays.length; j++) {
    var list = arrays[j]
    if (list && list.length) {
      var first = str(list[0])
      if (first) return first
    }
  }
  return ""
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
    artist: nameOf(raw.artist_name || raw.artist || raw.performer),
    album: albumTitle(raw),
    artworkUrl: str(raw.artwork_url || raw.album_image_url) || imageUrl(raw.album, true),
    duration: num(raw.duration_secs !== undefined ? raw.duration_secs : raw.duration, 0),
    // now-playing reports kHz (192.0), /api/status reports Hz (192000).
    sampleRate: num(raw.sample_rate, 0),
    bitDepth: num(raw.bit_depth, 0),
    hires: raw.hires === true,
    // What the track was played from. The only handle we get on the album,
    // since album_id is null on everything qbzd returns.
    contextKind: str(raw.context_kind),
    contextId: str(raw.context_id)
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

  next.daemon = {
    version: str(status.version),
    apiVersion: num(status.api_version, 0),
    uptime: num(status.uptime_secs, 0),
    online: !status.network || status.network.online !== false,
    audio: status.audio || {},
    qconnect: status.qconnect || {},
    errors: status.last_errors || {}
  }

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
    // Keep an album title/cover already resolved via applyAlbum(): this
    // endpoint reports "Unknown Album" and a null artwork_url forever.
    var prev = state.track
    if (prev && prev.id === track.id) {
      if (!track.album && prev.album) track.album = prev.album
      if (!track.artworkUrl && prev.artworkUrl) track.artworkUrl = prev.artworkUrl
    }
    next.track = track
    if (track.duration > 0) next.duration = track.duration
  } else if (payload.track === null) {
    next.track = null
  }

  // The real payload nests everything transport-related under `playback`;
  // there is no top-level position_secs or state.
  var pb = payload.playback
  if (pb && typeof pb === "object") {
    if (pb.position !== undefined) next.position = num(pb.position, next.position)
    if (pb.duration !== undefined) next.duration = num(pb.duration, next.duration)
    if (pb.volume !== undefined) next.volume = num(pb.volume, next.volume)
    if (pb.muted !== undefined) next.muted = pb.muted === true
    if (pb.shuffle !== undefined) next.shuffle = pb.shuffle === true
    if (pb.repeat !== undefined) next.repeat = normalizeRepeat(pb.repeat)
    if (pb.queue_len !== undefined) next.queueLength = num(pb.queue_len, next.queueLength)
    if (pb.is_playing !== undefined) {
      next.playback = pb.is_playing === true ? PLAYBACK_PLAYING
        : (next.playback === PLAYBACK_PLAYING ? PLAYBACK_PAUSED : next.playback)
    }
  }
  return next
}

// /api/album?id=<upc> — the only way to get a cover and a real album title.
// qbzd leaves track.artwork_url null and track.album "Unknown Album", and
// /api/artwork/current 404s as a direct consequence.
function applyAlbum(state, payload) {
  var next = shallowCopy(state)
  if (!next.track || !payload || typeof payload !== "object" || errorOf(payload)) return next

  var album = payload.album || payload
  if (!album || typeof album !== "object") return next

  // Only adopt it if it really is this track's album.
  var id = str(album.id)
  if (id && next.track.contextId && id !== next.track.contextId) return next

  var image = album.image || {}
  var cover = str(image.large || image.small || image.thumbnail || image.extralarge)
  var title = str(album.title)

  if (!cover && !title) return next
  var track = shallowCopy(next.track)
  if (title) track.album = title
  if (cover) track.artworkUrl = cover
  next.track = track
  return next
}

// The album lookup is worth doing only when there is something to gain and a
// handle to do it with.
function albumLookupId(state) {
  var t = state.track
  if (!t || t.contextKind !== "album" || !t.contextId) return ""
  if (t.artworkUrl && t.album) return ""
  return t.contextId
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
  if (current) {
    // Don't discard an album title/cover already resolved for this same track.
    var prev = state.track
    if (prev && prev.id === current.id) {
      if (!current.album && prev.album) current.album = prev.album
      if (!current.artworkUrl && prev.artworkUrl) current.artworkUrl = prev.artworkUrl
    }
    next.track = current
  }
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

// ---- Search ---------------------------------------------------------------

// /api/search?q=&type=<all|albums|tracks|artists|playlists>  — note the
// plurals; the wiki's singular values are rejected with bad_request. Each
// bucket comes back as {items, total, limit, offset}, or null when the type
// filter excluded it.
var SEARCH_KINDS = ["albums", "tracks", "artists", "playlists"]

function albumsCountLabel(count) {
  if (count <= 0) return ""
  return count === 1 ? "1 álbum" : count + " álbumes"
}

// One shape for every result kind, so the list delegate stays simple and the
// play action knows which id field qbzd wants.
function normalizeSearchItem(kind, raw) {
  if (!raw) return null
  var id = str(raw.id)
  if (!id) return null

  switch (kind) {
    case "albums":
      return {
        kind: "album", id: id,
        title: str(raw.title),
        subtitle: artistsLabel(raw),
        imageUrl: imageUrl(raw, false),
        duration: num(raw.duration, 0),
        trackCount: num(raw.tracks_count !== undefined ? raw.tracks_count : raw.track_count, 0),
        hires: raw.hires === true
      }
    case "tracks":
      return {
        kind: "track", id: id,
        title: str(raw.title),
        // The track's own `artist` is null in search results; the name lives
        // under `performer`, and the album title under `album.title`.
        subtitle: nameOf(raw.performer || raw.artist) ,
        imageUrl: imageUrl(raw.album, false),
        duration: num(raw.duration, 0),
        trackCount: 0,
        hires: raw.hires === true,
        albumTitle: nameOf(raw.album)
      }
    case "artists":
      return {
        kind: "artist", id: id,
        title: str(raw.name),
        subtitle: albumsCountLabel(num(raw.albums_count, 0)),
        imageUrl: imageUrl(raw, false),
        duration: 0, trackCount: 0, hires: false
      }
    case "playlists":
      return {
        kind: "playlist", id: id,
        // Playlists carry `name`; `title` is always null on them.
        title: str(raw.name || raw.title),
        subtitle: nameOf(raw.owner),
        imageUrl: imageUrl(raw, false),
        duration: num(raw.duration, 0),
        trackCount: num(raw.tracks_count, 0),
        hires: false
      }
  }
  return null
}

function normalizeSearch(payload) {
  var out = { query: "", albums: [], tracks: [], artists: [], playlists: [], total: 0 }
  if (!payload || typeof payload !== "object" || errorOf(payload)) return out
  out.query = str(payload.query)

  for (var i = 0; i < SEARCH_KINDS.length; i++) {
    var kind = SEARCH_KINDS[i]
    var bucket = payload[kind]
    if (!bucket || typeof bucket !== "object") continue
    var items = bucket.items || bucket
    if (!items || !items.length) continue
    for (var j = 0; j < items.length; j++) {
      var item = normalizeSearchItem(kind, items[j])
      if (item) { out[kind].push(item); out.total++ }
    }
  }
  return out
}

function applySearch(state, payload, query) {
  var next = shallowCopy(state)
  next.searchRunning = false
  var err = errorOf(payload)
  if (err) {
    next.searchError = err.message
    next.search = normalizeSearch(null)
    next.search.query = str(query)
    return next
  }
  next.searchError = ""
  next.search = normalizeSearch(payload)
  if (!next.search.query) next.search.query = str(query)
  return next
}

// ---- Catalogue: favourites, playlists, artist pages, album detail --------

// Every catalogue endpoint returns the same four entity shapes, so the search
// normalisers double as the generic ones and one delegate renders them all.
function normalizeCatalogItem(kind, raw) { return normalizeSearchItem(kind, raw) }

function normalizeItems(kind, list) {
  var out = []
  if (!list || !list.length) return out
  for (var i = 0; i < list.length; i++) {
    var item = normalizeCatalogItem(kind, list[i])
    if (item) out.push(item)
  }
  return out
}

// Buckets come as {items, total, limit, offset} on some endpoints and as a
// bare array on others.
function itemsOf(bucket) {
  if (!bucket) return []
  if (bucket.length !== undefined) return bucket
  return bucket.items || []
}

// /api/favorites?type=<albums|tracks|artists>
// -> {type, favorites: {albums|tracks|artists: {items, ...}, user}}
//
// The request takes the plural, but the response echoes `type` back in the
// SINGULAR ("album") while the bucket stays plural ("albums"), so the echoed
// value cannot be used as the key.
function pluralKind(kind) {
  var k = str(kind)
  if (k === "") return ""
  return k.charAt(k.length - 1) === "s" ? k : k + "s"
}

function normalizeFavorites(payload) {
  var out = { type: "albums", items: [] }
  if (!payload || typeof payload !== "object" || errorOf(payload)) return out

  var buckets = payload.favorites || {}
  var kind = pluralKind(payload.type)
  // Fall back to whichever bucket is actually populated.
  if (!kind || !buckets[kind]) {
    var candidates = ["albums", "tracks", "artists"]
    for (var i = 0; i < candidates.length; i++) {
      if (buckets[candidates[i]]) { kind = candidates[i]; break }
    }
  }
  if (!kind) return out

  out.type = kind
  out.items = normalizeItems(kind, itemsOf(buckets[kind]))
  return out
}

// /api/playlists -> {playlists: [...]}, a bare array, no envelope.
function normalizePlaylists(payload) {
  if (!payload || typeof payload !== "object" || errorOf(payload)) return []
  return normalizeItems("playlists", itemsOf(payload.playlists))
}

// /api/album?id=<upc> -> {album: {..., tracks: {items, total}}, similar}
function normalizeAlbumDetail(payload) {
  if (!payload || typeof payload !== "object" || errorOf(payload)) return null
  var album = payload.album || payload
  if (!album || !album.id) return null
  return {
    kind: "album",
    id: str(album.id),
    title: str(album.title),
    subtitle: artistsLabel(album),
    imageUrl: imageUrl(album, true),
    duration: num(album.duration, 0),
    trackCount: num(album.tracks_count !== undefined ? album.tracks_count : album.track_count, 0),
    hires: album.hires === true,
    // Album tracks carry no album of their own; stamp the parent on so rows
    // and the play action have it.
    tracks: normalizeItems("tracks", itemsOf(album.tracks))
  }
}

// /api/playlist?id=<n> -> {playlist: {..., tracks: [...]}}
function normalizePlaylistDetail(payload) {
  if (!payload || typeof payload !== "object" || errorOf(payload)) return null
  var pl = payload.playlist || payload
  if (!pl || !pl.id) return null
  return {
    kind: "playlist",
    id: str(pl.id),
    title: str(pl.name || pl.title),
    subtitle: nameOf(pl.owner),
    imageUrl: imageUrl(pl, true),
    duration: num(pl.duration, 0),
    trackCount: num(pl.tracks_count, 0),
    hires: false,
    tracks: normalizeItems("tracks", itemsOf(pl.tracks))
  }
}

// /api/artist?id=<n> -> {view, page: {name: {display}, images: {portrait},
//                        top_tracks, releases: [{type, items, has_more}]}}
var RELEASE_GROUP_LABELS = {
  album: "ÁLBUMES", live: "EN DIRECTO", compilation: "RECOPILATORIOS",
  epSingle: "EPS Y SINGLES", download: "SOLO DESCARGA",
  awardedRelease: "PREMIADOS", other: "OTROS"
}

// An artist page gives its portrait as {hash, format}, not a URL — unlike
// search results, which hand over the finished link. The path is the one
// those links use:
//   https://static.qobuz.com/images/artists/covers/<size>/<hash>.<format>
function artistPortraitUrl(portrait, size) {
  if (!portrait || typeof portrait !== "object") return ""
  var hash = str(portrait.hash)
  if (!hash) return ""
  var format = str(portrait.format) || "jpg"
  return "https://static.qobuz.com/images/artists/covers/" + (size || "large") +
         "/" + hash + "." + format
}

function normalizeArtistPage(payload) {
  if (!payload || typeof payload !== "object" || errorOf(payload)) return null
  var page = payload.page || payload
  if (!page || !page.id) return null

  var groups = []
  var seen = {}
  var releases = page.releases || []
  for (var i = 0; i < releases.length; i++) {
    var group = releases[i]
    if (!group) continue
    var items = normalizeItems("albums", itemsOf(group.items))
    if (!items.length) continue
    var type = str(group.type)
    // qbzd repeats `awardedRelease` twice with different contents; merge
    // rather than rendering the same heading twice.
    if (seen[type] !== undefined) {
      groups[seen[type]].items = groups[seen[type]].items.concat(items)
      continue
    }
    seen[type] = groups.length
    groups.push({ type: type, label: RELEASE_GROUP_LABELS[type] || type.toUpperCase(), items: items })
  }

  return {
    kind: "artist",
    id: str(page.id),
    title: nameOf(page.name),
    subtitle: str(page.artist_category),
    imageUrl: artistPortraitUrl(page.images ? page.images.portrait : null, "large"),
    duration: 0, trackCount: 0, hires: false,
    topTracks: normalizeItems("tracks", itemsOf(page.top_tracks)),
    releaseGroups: groups
  }
}

// /api/discover?section=index -> {section, data: {containers: {<key>: {id, data: {items}}}}}
var DISCOVER_LABELS = {
  new_releases: "NOVEDADES",
  most_streamed: "MÁS ESCUCHADOS",
  press_awards: "PREMIOS DE LA PRENSA",
  qobuzissims: "QOBUZISSIMS",
  album_of_the_week: "ÁLBUM DE LA SEMANA",
  ideal_discography: "DISCOGRAFÍA IDEAL",
  playlists: "PLAYLISTS",
  playlists_tags: "POR GÉNERO"
}
// Order matters more than the map iteration order the daemon happens to use.
var DISCOVER_ORDER = ["album_of_the_week", "new_releases", "most_streamed",
                      "qobuzissims", "press_awards", "ideal_discography", "playlists"]

function normalizeDiscover(payload) {
  var out = []
  if (!payload || typeof payload !== "object" || errorOf(payload)) return out
  var data = payload.data || {}
  var containers = data.containers || {}

  var keys = []
  for (var i = 0; i < DISCOVER_ORDER.length; i++)
    if (containers[DISCOVER_ORDER[i]]) keys.push(DISCOVER_ORDER[i])
  for (var key in containers)
    if (Object.prototype.hasOwnProperty.call(containers, key) && keys.indexOf(key) === -1)
      keys.push(key)

  for (var j = 0; j < keys.length; j++) {
    var container = containers[keys[j]]
    var bucket = container && container.data
    // The playlist rails hold playlists; everything else holds albums.
    var kind = keys[j].indexOf("playlist") === 0 ? "playlists" : "albums"
    var items = normalizeItems(kind, itemsOf(bucket))
    if (!items.length) continue
    out.push({ key: keys[j], label: DISCOVER_LABELS[keys[j]] || keys[j].replace(/_/g, " ").toUpperCase(), items: items })
  }
  return out
}

// /api/lyrics?id=current -> {track_id, synced, lines}
function normalizeLyrics(payload) {
  var out = { trackId: "", synced: false, lines: [] }
  if (!payload || typeof payload !== "object" || errorOf(payload)) return out
  out.trackId = str(payload.track_id)
  out.synced = payload.synced === true
  var lines = payload.lines || []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var text = typeof line === "object" ? str(line.text || line.line) : str(line)
    out.lines.push(text)
  }
  return out
}

// /api/favorites/add and /remove want a typed pair, and the singular kind.
function favoriteBodyFor(item) {
  if (!item || !item.id) return null
  var kind = str(item.kind)
  if (kind !== "track" && kind !== "album" && kind !== "artist") return null
  return { fav_type: kind, item_id: String(item.id) }
}

// Which POST body /api/play wants for a given result. The wiki's
// {"content": "album:ID"} is rejected — the daemon wants a typed id field.
function playBodyFor(item) {
  if (!item || !item.id) return null
  switch (item.kind) {
    case "album": return { album_id: String(item.id) }
    case "track": return { track_id: Number(item.id) }
    case "artist": return { artist_id: Number(item.id) }
    case "playlist": return { playlist_id: Number(item.id) }
  }
  return null
}

// ---- View navigation ------------------------------------------------------

// Browse is a drill-down, not a tab: entering it remembers where to go back
// to, so the same album row works from search, library and discover alike.
function enterBrowse(state, detail) {
  var next = shallowCopy(state)
  next.browseFrom = state.view === VIEW_BROWSE ? state.browseFrom : state.view
  next.browse = detail
  next.browseRunning = false
  next.view = VIEW_BROWSE
  return next
}

function beginBrowse(state) {
  var next = shallowCopy(state)
  next.browseFrom = state.view === VIEW_BROWSE ? state.browseFrom : state.view
  next.browse = null
  next.browseRunning = true
  next.view = VIEW_BROWSE
  return next
}

function leaveBrowse(state) {
  var next = shallowCopy(state)
  next.view = state.browseFrom || VIEW_QUEUE
  next.browse = null
  next.browseRunning = false
  return next
}

function setView(state, view) {
  var next = shallowCopy(state)
  next.view = view
  if (view !== VIEW_BROWSE) { next.browse = null; next.browseRunning = false }
  return next
}

function applyFavorites(state, payload) {
  var next = shallowCopy(state)
  next.libraryRunning = false
  var favorites = normalizeFavorites(payload)
  next.libraryType = favorites.type
  next.library = favorites.items
  return next
}

function applyPlaylists(state, payload) {
  var next = shallowCopy(state)
  next.libraryRunning = false
  next.libraryType = "playlists"
  next.library = normalizePlaylists(payload)
  return next
}

function applyLyrics(state, payload) {
  var next = shallowCopy(state)
  next.lyricsRunning = false
  var err = errorOf(payload)
  // "no lyrics for this track" is an ordinary answer, not a failure.
  next.lyrics = err ? { trackId: "", synced: false, lines: [], message: err.message }
                    : normalizeLyrics(payload)
  return next
}

function applyDiscover(state, payload) {
  var next = shallowCopy(state)
  next.discoverRunning = false
  next.discover = normalizeDiscover(payload)
  return next
}

// Only albums, artists and playlists have a page worth opening; a track just
// plays.
function isBrowsable(item) {
  if (!item || !item.id) return false
  return item.kind === "album" || item.kind === "artist" || item.kind === "playlist"
}

function browsePath(item) {
  if (!isBrowsable(item)) return ""
  if (item.kind === "album") return "/api/album?id=" + encodeURIComponent(item.id)
  if (item.kind === "artist") return "/api/artist?id=" + encodeURIComponent(item.id)
  return "/api/playlist?id=" + encodeURIComponent(item.id)
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

// Normalise the sample rate to kHz. now-playing reports 192.0 while
// /api/status and the catalogue endpoints report 192000.
function sampleRateKhz(track) {
  if (!track) return 0
  var rate = num(track.sampleRate, 0)
  return rate > 1000 ? rate / 1000 : rate
}

// Whether the JAS "Hi-Res AUDIO" mark applies. Prefer qbzd's own flag, which
// mirrors what Qobuz says about the release; fall back to the specification's
// threshold (at least 24-bit and 96 kHz) when the flag is missing, so a track
// carrying only its format still gets marked correctly.
function isHiRes(track) {
  if (!track) return false
  if (track.hires === true) return true
  return num(track.bitDepth, 0) >= 24 && sampleRateKhz(track) >= 96
}

// "24-bit 192 kHz" / "Hi-Res" / "" — the rate shown beside the mark.
function qualityLabel(track) {
  if (!track) return ""
  var parts = []
  if (num(track.bitDepth, 0) > 0) parts.push(track.bitDepth + "-bit")
  var khz = sampleRateKhz(track)
  if (khz > 0) parts.push((Math.round(khz * 10) / 10) + " kHz")
  if (parts.length) return parts.join(" ")
  return track.hires === true ? "Hi-Res" : ""
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
    applyAlbum: applyAlbum,
    albumLookupId: albumLookupId,
    albumTitle: albumTitle,
    nameOf: nameOf,
    artistsLabel: artistsLabel,
    imageUrl: imageUrl,
    SEARCH_KINDS: SEARCH_KINDS,
    normalizeSearchItem: normalizeSearchItem,
    normalizeSearch: normalizeSearch,
    applySearch: applySearch,
    playBodyFor: playBodyFor,
    normalizeCatalogItem: normalizeCatalogItem,
    normalizeFavorites: normalizeFavorites,
    normalizePlaylists: normalizePlaylists,
    normalizeAlbumDetail: normalizeAlbumDetail,
    normalizePlaylistDetail: normalizePlaylistDetail,
    normalizeArtistPage: normalizeArtistPage,
    normalizeDiscover: normalizeDiscover,
    normalizeLyrics: normalizeLyrics,
    favoriteBodyFor: favoriteBodyFor,
    pluralKind: pluralKind,
    VIEW_QUEUE: VIEW_QUEUE,
    VIEW_SEARCH: VIEW_SEARCH,
    VIEW_LIBRARY: VIEW_LIBRARY,
    VIEW_DISCOVER: VIEW_DISCOVER,
    VIEW_BROWSE: VIEW_BROWSE,
    VIEW_LYRICS: VIEW_LYRICS,
    enterBrowse: enterBrowse,
    beginBrowse: beginBrowse,
    leaveBrowse: leaveBrowse,
    setView: setView,
    applyFavorites: applyFavorites,
    applyPlaylists: applyPlaylists,
    applyLyrics: applyLyrics,
    applyDiscover: applyDiscover,
    isBrowsable: isBrowsable,
    browsePath: browsePath,
    artistPortraitUrl: artistPortraitUrl,
    itemsOf: itemsOf,
    reduceEvent: reduceEvent,
    needsQueueRefetch: needsQueueRefetch,
    errorOf: errorOf,
    exitCodeMeaning: exitCodeMeaning,
    pollIntervalMs: pollIntervalMs,
    canHandle: canHandle,
    formatDuration: formatDuration,
    qualityLabel: qualityLabel,
    isHiRes: isHiRes,
    sampleRateKhz: sampleRateKhz,
    trackLabel: trackLabel,
    progressFraction: progressFraction
  }
}
