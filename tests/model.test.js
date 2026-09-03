// node --test tests/model.test.js
//
// Fixtures under tests/fixtures/ are verbatim responses from a live qbzd
// 2.0.2, captured with the daemon running but logged out.

const test = require("node:test")
const assert = require("node:assert")
const fs = require("node:fs")
const path = require("node:path")

const M = require("../QobuzModel.js")

const fixture = (name) =>
  JSON.parse(fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8"))

test("emptyState starts fully offline", () => {
  const s = M.emptyState()
  assert.equal(s.daemonUp, false)
  assert.equal(s.authState, "unknown")
  assert.equal(s.playback, "stopped")
  assert.deepEqual(s.upcoming, [])
})

test("applyStatus on the real logged-out payload", () => {
  const s = M.applyStatus(M.emptyState(), fixture("status-needs-auth.json"))
  assert.equal(s.daemonUp, true, "reaching /api/status proves the daemon is up")
  assert.equal(s.authState, "needs_auth")
  assert.equal(s.playback, "stopped")
  assert.equal(s.volume, 0.75)
  assert.equal(s.muted, false)
  assert.equal(s.queueLength, 0)
  assert.equal(s.track, null)
})

test("applyStatus marks the daemon up even while logged out", () => {
  // The whole point of polling /api/status rather than /api/now-playing.
  const s = M.applyStatus(M.emptyState(), fixture("status-needs-auth.json"))
  assert.equal(s.daemonUp, true)
  assert.equal(M.canHandle(s, "playPause"), false)
})

test("applyStatus keeps the richer track when the id is unchanged", () => {
  let s = M.emptyState()
  s = M.applyNowPlaying(s, {
    track: { id: 77, title: "So What", artist_name: "Miles Davis",
             album_title: "Kind of Blue", artwork_url: "http://x/a.jpg",
             duration_secs: 545, bit_depth: 24, sample_rate: 192000 }
  })
  assert.equal(s.track.album, "Kind of Blue")

  // A later status poll carries only the flat title/artist — it must not
  // clobber the album and artwork we already have for the same track.
  s = M.applyStatus(s, {
    auth: { state: "ok" },
    playback: { state: "playing", track_id: 77, title: "So What",
                artist: "Miles Davis", position: 30, duration: 545,
                volume: 0.75, muted: false, queue_len: 5 }
  })
  assert.equal(s.track.album, "Kind of Blue")
  assert.equal(s.track.artworkUrl, "http://x/a.jpg")
  assert.equal(s.position, 30)
})

test("applyStatus replaces the track when the id changes", () => {
  let s = M.applyNowPlaying(M.emptyState(), {
    track: { id: 77, title: "So What", album_title: "Kind of Blue" }
  })
  s = M.applyStatus(s, {
    auth: { state: "ok" },
    playback: { state: "playing", track_id: 88, title: "Blue in Green", volume: 0.5 }
  })
  assert.equal(s.track.id, "88")
  assert.equal(s.track.album, "")
})

test("applyQueue on the real empty-queue payload", () => {
  const s = M.applyQueue(M.emptyState(), fixture("queue-empty.json"))
  assert.equal(s.queueLength, 0)
  assert.equal(s.queueIndex, -1)
  assert.equal(s.shuffle, false)
  assert.equal(s.repeat, "off")
  assert.deepEqual(s.upcoming, [])
})

test("applyQueue reads upcoming, not the wiki's tracks array", () => {
  const s = M.applyQueue(M.emptyState(), {
    current_index: 2,
    current_track: { id: 5, title: "Flamenco Sketches" },
    upcoming: [
      { id: 6, title: "All Blues", artist_name: "Miles Davis", duration_secs: 693 },
      { id: 7, title: "Freddie Freeloader" }
    ],
    history: [{ id: 4, title: "Blue in Green" }],
    total_tracks: 5, shuffle: true, repeat: "all"
  })
  assert.equal(s.queueIndex, 2)
  assert.equal(s.queueLength, 5)
  assert.equal(s.shuffle, true)
  assert.equal(s.repeat, "all")
  assert.equal(s.upcoming.length, 2)
  assert.equal(s.upcoming[0].artist, "Miles Davis")
  assert.equal(s.track.title, "Flamenco Sketches")
})

test("the real needs_auth error payload sets the auth state, not lastError", () => {
  const s = M.applyNowPlaying(M.emptyState(), fixture("error-needs-auth.json"))
  assert.equal(s.authState, "needs_auth")
  assert.equal(s.lastError, "")

  const e = M.errorOf(fixture("error-needs-auth.json"))
  assert.equal(e.code, "needs_auth")
  assert.equal(e.hint, "run: qbzd login")
})

test("reduceEvent handles every event type the binary emits", () => {
  for (const type of M.EVENT_TYPES) {
    assert.doesNotThrow(() => M.reduceEvent(M.emptyState(), { type, data: {} }),
      `${type} must not throw`)
  }
  assert.equal(M.EVENT_TYPES.length, 14)
})

test("TrackStarted sets the track and starts playing from zero", () => {
  const s = M.reduceEvent(M.emptyState(), {
    type: "TrackStarted",
    data: { track: { id: 9, title: "All Blues", artist_name: "Miles Davis", duration_secs: 693 } }
  })
  assert.equal(s.track.title, "All Blues")
  assert.equal(s.duration, 693)
  assert.equal(s.position, 0)
  assert.equal(s.playback, "playing")
  assert.equal(s.daemonUp, true, "receiving an event proves the daemon is up")
})

test("PositionUpdated and VolumeChanged update only their own fields", () => {
  let s = M.reduceEvent(M.emptyState(), { type: "PositionUpdated", data: { position_secs: 42, duration_secs: 337 } })
  assert.equal(s.position, 42)
  assert.equal(s.duration, 337)

  s = M.reduceEvent(s, { type: "VolumeChanged", data: { volume: 0.4, muted: true } })
  assert.equal(s.volume, 0.4)
  assert.equal(s.muted, true)
  assert.equal(s.position, 42, "volume must not disturb position")
})

test("RepeatModeChanged accepts the Rust enum casing and the lowercase form", () => {
  assert.equal(M.reduceEvent(M.emptyState(), { type: "RepeatModeChanged", data: { repeat: "All" } }).repeat, "all")
  assert.equal(M.reduceEvent(M.emptyState(), { type: "RepeatModeChanged", data: { mode: "one" } }).repeat, "one")
  assert.equal(M.reduceEvent(M.emptyState(), { type: "RepeatModeChanged", data: { repeat: "nonsense" } }).repeat, "off")
})

test("LoggedOut clears playback", () => {
  let s = M.reduceEvent(M.emptyState(), { type: "TrackStarted", data: { track: { id: 1, title: "x" } } })
  s = M.reduceEvent(s, { type: "LoggedOut", data: {} })
  assert.equal(s.authState, "needs_auth")
  assert.equal(s.track, null)
  assert.equal(s.playback, "stopped")
})

test("reduceEvent survives malformed input", () => {
  for (const bad of [null, undefined, {}, { type: "" }, { type: "Nonsense", data: null }, "string"]) {
    assert.doesNotThrow(() => M.reduceEvent(M.emptyState(), bad))
  }
})

test("needsQueueRefetch flags the events whose payload is not enough", () => {
  assert.equal(M.needsQueueRefetch({ type: "QueueUpdated" }), true)
  assert.equal(M.needsQueueRefetch({ type: "TrackStarted" }), true)
  assert.equal(M.needsQueueRefetch({ type: "VolumeChanged" }), false)
})

test("pollIntervalMs backs off when there is nothing to watch", () => {
  const down = M.emptyState()
  assert.equal(M.pollIntervalMs(down), 15000)

  const loggedOut = M.applyStatus(M.emptyState(), fixture("status-needs-auth.json"))
  assert.equal(M.pollIntervalMs(loggedOut), 10000)

  const paused = { ...loggedOut, authState: "ok", playback: "paused" }
  assert.equal(M.pollIntervalMs(paused), 5000)

  const playing = { ...paused, playback: "playing" }
  assert.equal(M.pollIntervalMs(playing), 1000)
})

test("exitCodeMeaning maps the qbzd-api exit codes", () => {
  assert.equal(M.exitCodeMeaning(0), "ok")
  assert.equal(M.exitCodeMeaning(3), "unreachable")
  assert.equal(M.exitCodeMeaning(4), "needs_auth")
  assert.equal(M.exitCodeMeaning(6), "not_found")
  assert.equal(M.exitCodeMeaning(99), "error")
})

test("formatDuration", () => {
  assert.equal(M.formatDuration(0), "0:00")
  assert.equal(M.formatDuration(62), "1:02")
  assert.equal(M.formatDuration(693), "11:33")
  assert.equal(M.formatDuration(3725), "1:02:05")
  assert.equal(M.formatDuration(-5), "0:00")
  assert.equal(M.formatDuration("nonsense"), "0:00")
})

test("qualityLabel", () => {
  assert.equal(M.qualityLabel({ bitDepth: 24, sampleRate: 192000 }), "24-bit 192 kHz")
  assert.equal(M.qualityLabel({ bitDepth: 16, sampleRate: 44100 }), "16-bit 44.1 kHz")
  assert.equal(M.qualityLabel({ bitDepth: 0, sampleRate: 0, hires: true }), "Hi-Res")
  assert.equal(M.qualityLabel({ bitDepth: 0, sampleRate: 0, hires: false }), "")
  assert.equal(M.qualityLabel(null), "")
})

test("trackLabel reflects each degraded state and elides long titles", () => {
  const down = M.emptyState()
  assert.equal(M.trackLabel(down, 40), "qbzd")

  const loggedOut = M.applyStatus(M.emptyState(), fixture("status-needs-auth.json"))
  assert.equal(M.trackLabel(loggedOut, 40), "Sin sesión")

  const idle = { ...loggedOut, authState: "ok", track: null }
  assert.equal(M.trackLabel(idle, 40), "Qobuz")

  const playing = { ...idle, track: { title: "So What", artist: "Miles Davis" } }
  assert.equal(M.trackLabel(playing, 40), "Miles Davis — So What")
  assert.equal(M.trackLabel(playing, 12), "Miles Davis…")
  assert.equal(M.trackLabel(playing, 0), "Miles Davis — So What", "0 means no limit")
})

test("progressFraction stays inside 0..1", () => {
  assert.equal(M.progressFraction({ position: 0, duration: 0 }), 0)
  assert.equal(M.progressFraction({ position: 50, duration: 100 }), 0.5)
  assert.equal(M.progressFraction({ position: 500, duration: 100 }), 1)
  assert.equal(M.progressFraction({ position: -5, duration: 100 }), 0)
})

test("canHandle gates every action while logged out or offline", () => {
  const loggedOut = M.applyStatus(M.emptyState(), fixture("status-needs-auth.json"))
  for (const action of ["playPause", "next", "previous", "seek", "volume"]) {
    assert.equal(M.canHandle(loggedOut, action), false, `${action} needs a session`)
  }

  const live = { ...loggedOut, authState: "ok", queueLength: 3, duration: 300,
                 track: { id: "1", title: "x" } }
  assert.equal(M.canHandle(live, "playPause"), true)
  assert.equal(M.canHandle(live, "next"), true)
  assert.equal(M.canHandle(live, "seek"), true)
  assert.equal(M.canHandle(live, "volume"), true)
})

test("reducers never mutate the state they are given", () => {
  const base = M.emptyState()
  const frozen = JSON.stringify(base)
  M.applyStatus(base, fixture("status-needs-auth.json"))
  M.applyQueue(base, fixture("queue-empty.json"))
  M.reduceEvent(base, { type: "VolumeChanged", data: { volume: 0.9 } })
  assert.equal(JSON.stringify(base), frozen)
})

// ---------------------------------------------------------------------------
// Captures from a logged-in qbzd playing an album queued by id — the case
// where qbzd resolves neither the cover nor the album title.
// ---------------------------------------------------------------------------

test("applyStatus on the real playing payload", () => {
  const s = M.applyStatus(M.emptyState(), fixture("status-playing.json"))
  assert.equal(s.daemonUp, true)
  assert.equal(s.authState, "ok", "'logged_in' is not 'needs_auth', so it counts as ok")
  assert.equal(s.playback, "playing")
  assert.equal(s.track.title, "Freddie Freeloader")
  assert.equal(s.track.artist, "Miles Davis")
  assert.equal(s.position, 146)
  assert.equal(s.duration, 588)
  assert.equal(s.queueLength, 5)
})

test("applyNowPlaying reads the nested playback block", () => {
  // The wiki implies top-level position_secs/state; the daemon nests them.
  const s = M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json"))
  assert.equal(s.track.title, "So What")
  assert.equal(s.track.id, "13176083")
  assert.equal(s.position, 5, "position comes from payload.playback")
  assert.equal(s.duration, 547)
  assert.equal(s.volume, 0.75)
  assert.equal(s.playback, "playing", "derived from playback.is_playing")
  assert.equal(s.shuffle, false)
  assert.equal(s.repeat, "off")
  assert.equal(s.queueLength, 5)
})

test("'Unknown Album' is suppressed rather than shown", () => {
  const s = M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json"))
  assert.equal(s.track.album, "", "qbzd's placeholder must not reach the UI")
  assert.equal(M.albumTitle({ album: "Unknown Album" }), "")
  assert.equal(M.albumTitle({ album: "Kind Of Blue" }), "Kind Of Blue")
})

test("the track keeps the context it was played from", () => {
  const s = M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json"))
  assert.equal(s.track.contextKind, "album")
  assert.equal(s.track.contextId, "5099749522428")
  assert.equal(s.track.artworkUrl, "", "qbzd leaves artwork_url null")
})

test("qualityLabel handles now-playing's kHz and status's Hz alike", () => {
  const np = M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json"))
  assert.equal(M.qualityLabel(np.track), "24-bit 192 kHz", "sample_rate is 192.0 here")

  const st = M.applyStatus(M.emptyState(), fixture("status-playing.json"))
  assert.equal(st.track.sampleRate, 0, "status carries no per-track rate")
})

test("applyAlbum fills in the cover and the real album title", () => {
  let s = M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json"))
  assert.equal(M.albumLookupId(s), "5099749522428", "a lookup is worth doing")

  s = M.applyAlbum(s, fixture("album.json"))
  assert.equal(s.track.album, "Kind Of Blue")
  assert.equal(s.track.artworkUrl,
    "https://static.qobuz.com/images/covers/28/24/5099749522428_600.jpg")
  assert.equal(M.albumLookupId(s), "", "nothing left to gain, so no second lookup")
})

test("applyAlbum ignores a response for a different album", () => {
  const s = M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json"))
  const other = M.applyAlbum(s, { album: { id: "9999999999999", title: "Wrong", image: { large: "http://x" } } })
  assert.equal(other.track.album, "")
  assert.equal(other.track.artworkUrl, "")
})

test("albumLookupId declines when there is no handle or nothing to gain", () => {
  assert.equal(M.albumLookupId(M.emptyState()), "", "no track")
  assert.equal(M.albumLookupId({ track: { contextKind: "playlist", contextId: "7" } }), "",
    "only albums have a cover to look up this way")
  assert.equal(M.albumLookupId({ track: { contextKind: "album", contextId: "" } }), "")
  assert.equal(M.albumLookupId({ track: { contextKind: "album", contextId: "1", album: "A", artworkUrl: "u" } }), "")
})

test("a resolved cover survives the next status and queue poll", () => {
  let s = M.applyAlbum(
    M.applyNowPlaying(M.emptyState(), fixture("nowplaying-playing.json")),
    fixture("album.json"))
  assert.equal(s.track.artworkUrl.length > 0, true)

  // Same track id, so neither poll may clobber what we resolved.
  s = M.applyQueue(s, fixture("queue-playing.json"))
  assert.equal(s.track.album, "Kind Of Blue")
  assert.equal(s.track.artworkUrl.length > 0, true)

  s = M.applyNowPlaying(s, fixture("nowplaying-playing.json"))
  assert.equal(s.track.album, "Kind Of Blue")
  assert.equal(s.track.artworkUrl.length > 0, true)
})

test("applyQueue on the real 5-track queue", () => {
  const s = M.applyQueue(M.emptyState(), fixture("queue-playing.json"))
  assert.equal(s.queueLength, 5)
  assert.equal(s.queueIndex, 0)
  assert.equal(s.upcoming.length, 4)
  assert.equal(s.upcoming[0].title, "Freddie Freeloader")
  assert.equal(s.upcoming[0].artist, "Miles Davis")
  assert.equal(s.upcoming[0].duration, 588)
  assert.equal(s.track.title, "So What")
})

// ---------------------------------------------------------------------------
// Search. Catalogue endpoints nest what the playback endpoints keep flat.
// ---------------------------------------------------------------------------

test("nameOf unwraps the object form the catalogue endpoints use", () => {
  assert.equal(M.nameOf("Miles Davis"), "Miles Davis")
  assert.equal(M.nameOf({ id: 6760, name: "Miles Davis" }), "Miles Davis")
  assert.equal(M.nameOf({ id: 1, title: "Kind Of Blue" }), "Kind Of Blue")
  assert.equal(M.nameOf(null), "")
  assert.equal(M.nameOf(undefined), "")
})

test("normalizeTrack never stringifies an object into the UI", () => {
  // Regression: search tracks carry performer/album as objects, and
  // String({}) would have put "[object Object]" on screen.
  const t = M.normalizeTrack({
    id: 1, title: "So What",
    performer: { id: 6760, name: "Miles Davis" },
    album: { id: "509", title: "Kind Of Blue", image: { large: "http://c/l.jpg" } }
  })
  assert.equal(t.artist, "Miles Davis")
  assert.equal(t.album, "Kind Of Blue")
  assert.equal(t.artworkUrl, "http://c/l.jpg")
  assert.equal(t.artist.indexOf("object"), -1)
})

test("imageUrl walks the null-riddled Qobuz image objects", () => {
  assert.equal(M.imageUrl({ image: { small: null, large: "http://l", thumbnail: "http://t" } }, true), "http://l")
  assert.equal(M.imageUrl({ image: { small: null, large: "http://l", thumbnail: "http://t" } }, false), "http://t")
  assert.equal(M.imageUrl({ images300: ["http://p300"] }, false), "http://p300")
  assert.equal(M.imageUrl({ image: { small: null, large: null } }, false), "")
  assert.equal(M.imageUrl(null, false), "")
})

test("normalizeSearch on the real all-kinds response", () => {
  const r = M.normalizeSearch(fixture("search-all.json"))
  assert.equal(r.query, "miles davis")
  assert.equal(r.total, 12)
  assert.equal(r.albums.length, 3)
  assert.equal(r.tracks.length, 3)
  assert.equal(r.artists.length, 3)
  assert.equal(r.playlists.length, 3)

  assert.deepEqual(
    { ...r.albums[0], imageUrl: r.albums[0].imageUrl.length > 0 },
    { kind: "album", id: "5099749522428", title: "Kind Of Blue", subtitle: "Miles Davis",
      imageUrl: true, duration: 2723, trackCount: 5, hires: true })

  assert.equal(r.tracks[0].title, "So What")
  assert.equal(r.tracks[0].subtitle, "Miles Davis", "from performer.name; artist is null")
  assert.equal(r.tracks[0].albumTitle, "Kind Of Blue")

  assert.equal(r.artists[0].title, "Miles Davis")
  // Playlists use `name`; their `title` is always null.
  assert.equal(r.playlists[0].title, "Hi-Res Masters: Miles Davis")
  assert.equal(r.playlists[0].trackCount, 41)
})

test("normalizeSearch tolerates missing buckets and junk", () => {
  for (const bad of [null, undefined, {}, { albums: null }, { albums: { items: null } }, "x"]) {
    const r = M.normalizeSearch(bad)
    assert.equal(r.total, 0)
    assert.deepEqual(r.albums, [])
  }
})

test("playBodyFor uses the typed id field, not the wiki's content selector", () => {
  assert.deepEqual(M.playBodyFor({ kind: "album", id: "5099749522428" }), { album_id: "5099749522428" })
  assert.deepEqual(M.playBodyFor({ kind: "track", id: "13176083" }), { track_id: 13176083 })
  assert.deepEqual(M.playBodyFor({ kind: "artist", id: "6760" }), { artist_id: 6760 })
  assert.deepEqual(M.playBodyFor({ kind: "playlist", id: "6217029" }), { playlist_id: 6217029 })
  assert.equal(M.playBodyFor({ kind: "nonsense", id: "1" }), null)
  assert.equal(M.playBodyFor(null), null)
})

test("applySearch clears the running flag on success and on error", () => {
  const busy = { ...M.emptyState(), searchRunning: true }

  const ok = M.applySearch(busy, fixture("search-all.json"), "miles davis")
  assert.equal(ok.searchRunning, false)
  assert.equal(ok.searchError, "")
  assert.equal(ok.search.total, 12)

  const failed = M.applySearch(busy, fixture("error-needs-auth.json"), "miles davis")
  assert.equal(failed.searchRunning, false)
  assert.equal(failed.searchError, "not logged in to Qobuz")
  assert.equal(failed.search.total, 0)
  assert.equal(failed.search.query, "miles davis", "the query survives so the UI can say what failed")
})

test("search results do not disturb playback state", () => {
  let s = M.applyStatus(M.emptyState(), fixture("status-playing.json"))
  const before = { track: s.track, position: s.position, playback: s.playback }
  s = M.applySearch(s, fixture("search-all.json"), "miles davis")
  assert.deepEqual({ track: s.track, position: s.position, playback: s.playback }, before)
})

test("artist album counts are pluralised", () => {
  const one = M.normalizeSearchItem("artists", { id: 1, name: "X", albums_count: 1 })
  assert.equal(one.subtitle, "1 álbum")
  const many = M.normalizeSearchItem("artists", { id: 1, name: "X", albums_count: 11 })
  assert.equal(many.subtitle, "11 álbumes")
  const none = M.normalizeSearchItem("artists", { id: 1, name: "X", albums_count: 0 })
  assert.equal(none.subtitle, "")
})
