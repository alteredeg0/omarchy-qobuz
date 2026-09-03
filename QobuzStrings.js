// UI text, in one place and in two languages.
//
// Nothing here comes from qbzd or from Omarchy — every string below was
// written for this plugin, which is why it was Spanish-only until now.
// Catalogue text (playlist names, an artist's `performer` category, "Qobuz
// España" as a playlist owner) still arrives in whatever language Qobuz serves
// the account, and no setting here changes that.
//
// t(lang, key, a, b) substitutes {0} and {1}. An unknown key returns the key
// itself, so a missing translation is visible rather than blank.

var DEFAULT_LANG = "en"
var LANGUAGES = ["en", "es"]

var STRINGS = {
  en: {
    // Identity and shell states
    "app.name": "Qobuz",
    "state.noSession": "No session",
    "state.nothingPlaying": "Nothing playing",
    "state.daemonDown": "qbzd is not responding at {0}",
    "state.daemonDownHint": "qbzd is not responding at {0}.\nStart it with: systemctl --user start qbzd",
    "state.noSessionTooltip": "Qobuz — no session (qbzd login)",
    "state.nothingPlayingTooltip": "Qobuz — nothing playing",
    "state.noSessionTitle": "No Qobuz session",
    "state.loginHint": "Qobuz login is browser-based OAuth; a terminal will open.",
    "state.loginPrompt": "No Qobuz session. Run “qbzd login” in a terminal.",
    "state.daemonUnreachable": "qbzd is not responding",

    // Actions
    "action.play": "Play",
    "action.pause": "Pause",
    "action.previous": "Previous",
    "action.next": "Next",
    "action.back": "Back",
    "action.close": "Close",
    "action.refresh": "Refresh",
    "action.retry": "Retry",
    "action.clear": "Clear",
    "action.search": "Search",
    "action.login": "Sign in",
    "action.openApp": "Open Qobuz",
    "action.favouriteAdd": "Add to favourites",
    "action.favouriteRemove": "Remove from favourites",
    "action.shuffleOn": "Shuffle on",
    "action.shuffleOff": "Shuffle off",
    "action.repeatOff": "Repeat off",
    "action.repeatAll": "Repeat all",
    "action.repeatOne": "Repeat track",

    // Views
    "view.discover": "Discover",
    "view.search": "Search",
    "view.queue": "Queue",
    "view.lyrics": "Lyrics",
    "view.library": "Library",
    "view.status": "Status",
    "view.results": "Results",

    // Library
    "library.heading": "YOUR LIBRARY",
    "library.albums": "Albums",
    "library.tracks": "Tracks",
    "library.artists": "Artists",
    "library.playlists": "Playlists",
    "library.titleAlbums": "Favourite albums",
    "library.titleTracks": "Favourite tracks",
    "library.titleArtists": "Favourite artists",
    "library.titlePlaylists": "Your playlists",
    "library.emptyFavourites": "No favourites in this category.",
    "library.emptyPlaylists": "You have no playlists.",

    // Section headings
    "section.albums": "ALBUMS",
    "section.tracks": "TRACKS",
    "section.artists": "ARTISTS",
    "section.playlists": "PLAYLISTS",
    "section.topTracks": "TOP TRACKS",
    "section.queue": "QUEUE",
    "section.upNext": "UP NEXT · {0} QUEUED",

    // Search
    "search.placeholder": "Search Qobuz",
    "search.placeholderLong": "Search Qobuz for albums, tracks, artists and playlists",
    "search.prompt": "Type above to search the catalogue.",
    "search.noResults": "No results for “{0}”.",
    "search.failed": "Search failed",

    // Queue
    "queue.empty": "The queue is empty.",
    "queue.last": "Last track in the queue.",

    // Lyrics
    "lyrics.loading": "Looking for the lyrics…",
    "lyrics.none": "This track has no lyrics on Qobuz.",
    "lyrics.noTrack": "Nothing is playing.",

    // Discover and browse
    "discover.loading": "Loading new releases…",
    "discover.empty": "Nothing to show right now.",
    "browse.loading": "Loading…",
    "browse.failed": "Could not open it.",
    "browse.trackCount": "{0} tracks",

    // Hints
    "hint.openOrPlay": "Click: open · Right click: play",
    "hint.playOrQueue": "Click: play · Right click: add to queue",
    "hint.more": "+{0} more",
    "hint.albumsOne": "1 album",
    "hint.albumsMany": "{0} albums",

    // Discover rails
    "rail.new_releases": "NEW RELEASES",
    "rail.most_streamed": "MOST STREAMED",
    "rail.press_awards": "PRESS AWARDS",
    "rail.qobuzissims": "QOBUZISSIMS",
    "rail.album_of_the_week": "ALBUM OF THE WEEK",
    "rail.ideal_discography": "IDEAL DISCOGRAPHY",
    "rail.playlists": "PLAYLISTS",
    "rail.playlists_tags": "BY GENRE",

    // Artist release groups
    "release.album": "ALBUMS",
    "release.live": "LIVE",
    "release.compilation": "COMPILATIONS",
    "release.epSingle": "EPS AND SINGLES",
    "release.download": "DOWNLOAD ONLY",
    "release.awardedRelease": "AWARD WINNERS",
    "release.other": "OTHER",

    // Status page
    "status.noData": "No daemon data yet.",
    "status.daemon": "DAEMON",
    "status.audio": "AUDIO",
    "status.connect": "QOBUZ CONNECT",
    "status.errors": "LAST ERRORS",
    "status.version": "Version",
    "status.uptime": "Up for",
    "status.network": "Network",
    "status.online": "Online",
    "status.offline": "Offline",
    "status.session": "Session",
    "status.signedIn": "Signed in",
    "status.signedOut": "Signed out",
    "status.host": "Host",
    "status.backend": "Backend",
    "status.device": "Device",
    "status.deviceDefault": "System default",
    "status.devicePresent": "Device present",
    "status.deviceOpen": "Device open",
    "status.bitPerfect": "Bit-perfect",
    "status.disabled": "Disabled",
    "status.format": "Format",
    "status.bits": "{0}-bit · {1}",
    "status.connectName": "Device name",
    "status.connectEnabled": "Enabled",
    "status.connectState": "State",
    "status.connectSession": "Session active",
    "status.noErrors": "None",
    "status.errorsLabel": "Errors",

    // Small words
    "word.yes": "Yes",
    "word.no": "No",
    "word.loading": "Loading…",
    "word.dash": "—"
  },

  es: {
    "app.name": "Qobuz",
    "state.noSession": "Sin sesión",
    "state.nothingPlaying": "Nada sonando",
    "state.daemonDown": "qbzd no responde en {0}",
    "state.daemonDownHint": "qbzd no responde en {0}.\nArráncalo con: systemctl --user start qbzd",
    "state.noSessionTooltip": "Qobuz — sin sesión (qbzd login)",
    "state.nothingPlayingTooltip": "Qobuz — nada sonando",
    "state.noSessionTitle": "Sin sesión de Qobuz",
    "state.loginHint": "El login de Qobuz es OAuth por navegador; se abrirá una terminal.",
    "state.loginPrompt": "Sin sesión de Qobuz. Ejecuta «qbzd login» en una terminal.",
    "state.daemonUnreachable": "qbzd no responde",

    "action.play": "Reproducir",
    "action.pause": "Pausar",
    "action.previous": "Anterior",
    "action.next": "Siguiente",
    "action.back": "Volver",
    "action.close": "Cerrar",
    "action.refresh": "Actualizar",
    "action.retry": "Reintentar",
    "action.clear": "Limpiar",
    "action.search": "Buscar",
    "action.login": "Iniciar sesión",
    "action.openApp": "Abrir Qobuz",
    "action.favouriteAdd": "Añadir a favoritos",
    "action.favouriteRemove": "Quitar de favoritos",
    "action.shuffleOn": "Aleatorio activado",
    "action.shuffleOff": "Aleatorio desactivado",
    "action.repeatOff": "Repetición desactivada",
    "action.repeatAll": "Repetir todo",
    "action.repeatOne": "Repetir pista",

    "view.discover": "Descubrir",
    "view.search": "Buscar",
    "view.queue": "Cola",
    "view.lyrics": "Letra",
    "view.library": "Biblioteca",
    "view.status": "Estado",
    "view.results": "Resultados",

    "library.heading": "TU BIBLIOTECA",
    "library.albums": "Álbumes",
    "library.tracks": "Pistas",
    "library.artists": "Artistas",
    "library.playlists": "Playlists",
    "library.titleAlbums": "Álbumes favoritos",
    "library.titleTracks": "Pistas favoritas",
    "library.titleArtists": "Artistas favoritos",
    "library.titlePlaylists": "Tus playlists",
    "library.emptyFavourites": "No tienes favoritos en esta categoría.",
    "library.emptyPlaylists": "No tienes playlists.",

    "section.albums": "ÁLBUMES",
    "section.tracks": "PISTAS",
    "section.artists": "ARTISTAS",
    "section.playlists": "PLAYLISTS",
    "section.topTracks": "MÁS ESCUCHADAS",
    "section.queue": "COLA",
    "section.upNext": "A CONTINUACIÓN · {0} EN COLA",

    "search.placeholder": "Buscar en Qobuz",
    "search.placeholderLong": "Buscar álbumes, pistas, artistas y playlists en Qobuz",
    "search.prompt": "Escribe arriba para buscar en el catálogo.",
    "search.noResults": "Sin resultados para «{0}».",
    "search.failed": "La búsqueda falló",

    "queue.empty": "La cola está vacía.",
    "queue.last": "Última pista de la cola.",

    "lyrics.loading": "Buscando la letra…",
    "lyrics.none": "Esta pista no tiene letra en Qobuz.",
    "lyrics.noTrack": "No hay nada sonando.",

    "discover.loading": "Cargando novedades…",
    "discover.empty": "Nada que mostrar ahora mismo.",
    "browse.loading": "Cargando…",
    "browse.failed": "No se pudo abrir.",
    "browse.trackCount": "{0} pistas",

    "hint.openOrPlay": "Clic: abrir · Clic derecho: reproducir",
    "hint.playOrQueue": "Clic: reproducir · Clic derecho: añadir a la cola",
    "hint.more": "+{0} más",
    "hint.albumsOne": "1 álbum",
    "hint.albumsMany": "{0} álbumes",

    "rail.new_releases": "NOVEDADES",
    "rail.most_streamed": "MÁS ESCUCHADOS",
    "rail.press_awards": "PREMIOS DE LA PRENSA",
    "rail.qobuzissims": "QOBUZISSIMS",
    "rail.album_of_the_week": "ÁLBUM DE LA SEMANA",
    "rail.ideal_discography": "DISCOGRAFÍA IDEAL",
    "rail.playlists": "PLAYLISTS",
    "rail.playlists_tags": "POR GÉNERO",

    "release.album": "ÁLBUMES",
    "release.live": "EN DIRECTO",
    "release.compilation": "RECOPILATORIOS",
    "release.epSingle": "EPS Y SINGLES",
    "release.download": "SOLO DESCARGA",
    "release.awardedRelease": "PREMIADOS",
    "release.other": "OTROS",

    "status.noData": "Sin datos del demonio todavía.",
    "status.daemon": "DEMONIO",
    "status.audio": "AUDIO",
    "status.connect": "QOBUZ CONNECT",
    "status.errors": "ÚLTIMOS ERRORES",
    "status.version": "Versión",
    "status.uptime": "Activo desde hace",
    "status.network": "Red",
    "status.online": "En línea",
    "status.offline": "Sin conexión",
    "status.session": "Sesión",
    "status.signedIn": "Iniciada",
    "status.signedOut": "Sin iniciar",
    "status.host": "Host",
    "status.backend": "Backend",
    "status.device": "Dispositivo",
    "status.deviceDefault": "Por defecto del sistema",
    "status.devicePresent": "Dispositivo presente",
    "status.deviceOpen": "Dispositivo abierto",
    "status.bitPerfect": "Bit-perfect",
    "status.disabled": "Desactivado",
    "status.format": "Formato",
    "status.bits": "{0} bits · {1}",
    "status.connectName": "Nombre del dispositivo",
    "status.connectEnabled": "Activado",
    "status.connectState": "Estado",
    "status.connectSession": "Sesión activa",
    "status.noErrors": "Ninguno",
    "status.errorsLabel": "Errores",

    "word.yes": "Sí",
    "word.no": "No",
    "word.loading": "Cargando…",
    "word.dash": "—"
  }
}

// "auto" follows the system locale; anything unknown falls back to English.
function resolve(setting, localeName) {
  var wanted = String(setting || "auto").toLowerCase()
  if (wanted !== "auto") {
    return LANGUAGES.indexOf(wanted) !== -1 ? wanted : DEFAULT_LANG
  }
  var locale = String(localeName || "").toLowerCase()
  for (var i = 0; i < LANGUAGES.length; i++) {
    var code = LANGUAGES[i]
    if (locale === code || locale.indexOf(code + "_") === 0 || locale.indexOf(code + "-") === 0)
      return code
  }
  return DEFAULT_LANG
}

function t(lang, key, a, b) {
  var table = STRINGS[lang] || STRINGS[DEFAULT_LANG]
  var value = table[key]
  // Fall back to English before falling back to the key, so a half-finished
  // translation degrades to readable text rather than to "status.bitPerfect".
  if (value === undefined) value = STRINGS[DEFAULT_LANG][key]
  if (value === undefined) return String(key)
  if (a !== undefined) value = value.replace("{0}", String(a))
  if (b !== undefined) value = value.replace("{1}", String(b))
  return value
}

// "1 album" / "5 albums" — the one count that needs a plural rule.
function albumsCountLabel(lang, count) {
  var n = Number(count) || 0
  if (n <= 0) return ""
  return n === 1 ? t(lang, "hint.albumsOne") : t(lang, "hint.albumsMany", n)
}

function railLabel(lang, key) {
  var table = STRINGS[lang] || STRINGS[DEFAULT_LANG]
  var id = "rail." + key
  if (table[id] !== undefined || STRINGS[DEFAULT_LANG][id] !== undefined) return t(lang, id)
  return String(key).replace(/_/g, " ").toUpperCase()
}

function releaseGroupLabel(lang, type) {
  var table = STRINGS[lang] || STRINGS[DEFAULT_LANG]
  var id = "release." + type
  if (table[id] !== undefined || STRINGS[DEFAULT_LANG][id] !== undefined) return t(lang, id)
  return String(type).toUpperCase()
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    DEFAULT_LANG: DEFAULT_LANG,
    LANGUAGES: LANGUAGES,
    STRINGS: STRINGS,
    resolve: resolve,
    t: t,
    albumsCountLabel: albumsCountLabel,
    railLabel: railLabel,
    releaseGroupLabel: releaseGroupLabel
  }
}
