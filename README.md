# javih.qobuz

Qobuz for Omarchy, on two surfaces that share one session:

- a **bar widget** — the current track next to the clock, and a panel with
  cover art, transport, progress, volume and the queue;
- a **full-screen app** — sidebar, cover grids, artist and album pages, search,
  your library, the discover rails and lyrics.

Qobuz has no public third-party API — partner credentials have to be requested
from `api@qobuz.com` — so this plugin does not talk to Qobuz at all. It is a
front-end for [**qbzd**](https://github.com/vicrodh/qbz), the headless QBZ
daemon, which does the OAuth login itself and exposes a local control API. Same
relationship the Omarchy Spotify plugin has with `spotifyd`.

## Requirements

- An active Qobuz subscription.
- `qbzd` 2.0.2 or newer, running and logged in.
- Omarchy 4.0.0.alpha or newer (Quickshell 0.3.1).

## Install

### 1. The daemon

`qbzd` ships only as a standalone tarball in the qbz releases — the AUR's
`qbz-bin` installs the desktop GUI and nothing else. A PKGBUILD is included:

```bash
cd packaging
BUILDDIR=/tmp/qbzd-build SRCDEST=/tmp/qbzd-build PKGDEST=/tmp/qbzd-build makepkg -si
```

The three variables keep `src/`, `pkg/` and the downloaded tarball out of the
plugin folder — `omarchy plugin validate` rejects the symlinks makepkg would
otherwise leave behind.

That installs `/usr/bin/qbzd` plus the upstream systemd **user** unit and shell
completions. Then log in and start it:

```bash
qbzd setup                      # six-screen configurator: login, audio device, name
systemctl --user enable --now qbzd
```

`qbzd setup` covers `qbzd login` (browser OAuth — there are no password
fields) as its first screen.

> **Bind address.** qbzd listens on `0.0.0.0:8182` by default, so anyone on your
> network can control playback. Unless you actually want that, put this in
> `~/.config/qbzd/qbzd.toml`:
>
> ```toml
> [server]
> bind = "127.0.0.1"
> ```
>
> A `token` in the same section is also honoured by this plugin.

### 2. The plugin

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable javih.qobuz right
```

## Settings

Set with `omarchy bar set javih.qobuz <key> <value>`.

| Key | Default | What it does |
|---|---|---|
| `host` | `127.0.0.1:8182` | qbzd control API. Point it at another machine to drive a remote player. |
| `showLabel` | `true` | Off leaves just the play/pause glyph. A vertical bar always collapses to the glyph. |
| `maxLabelChars` | `32` | Elision point for the bar label. |
| `hideWhenIdle` | `false` | Collapse the widget out of the bar while qbzd is stopped. |
| `language` | `auto` | UI language: `auto`, `en` or `es`. |

### Language

Every word this plugin writes lives in `QobuzStrings.js`, in English and
Spanish. `auto` follows `$LANG` and falls back to English for anything else:

```bash
omarchy bar set javih.qobuz language es
```

What it does **not** change is catalogue text, which arrives in whatever
language Qobuz serves the account — playlist names, an artist's `performer`
category, "Qobuz España" as a playlist owner. No plugin setting reaches that.

Adding a language means adding one block to `STRINGS` in `QobuzStrings.js` and
listing its code in `LANGUAGES`. `tests/strings.test.js` then enforces that it
has exactly the same keys as English, none of them empty, with matching `{0}`
placeholders — the failure mode of every hand-rolled translation table.

## Controls

**In the bar:** left click opens the panel · middle click toggles playback ·
scroll changes volume.

**In the panel:** `Space` play/pause · `←`/`→` previous/next · `s` shuffle ·
`l` repeat · `r` refresh · `o` open the app · `Esc` close · `Tab` next panel.

**In the app:** `/` search · `Space` play/pause · `←`/`→` previous/next ·
`Esc` back out of a page, or close the app. Clicking outside closes it.

**In any list:** left click **opens** an album, artist or playlist and
**plays** a track; right click does the other one — plays the album, or
appends the track to the queue. Hovering a row says which.

**IPC:** `omarchy-shell javih.qobuz {open,close,toggle,refresh,status}` drives
the panel; `search <query>`, `view <queue|search|library|discover|lyrics>` and
`browse <album|artist|playlist> <id>` open the **app** at that spot, because
that is where the results have room. `results` prints the current search.

```lua
o.bind("SUPER SHIFT, Q", "Search Qobuz", "omarchy-shell javih.qobuz search ''")
o.bind("SUPER SHIFT, L", "Qobuz library", "omarchy-shell javih.qobuz view library")
```

Media keys need no setup: qbzd publishes MPRIS as
`org.mpris.MediaPlayer2.com.blitzfc.qbz`, which Omarchy's own media bindings
already drive.

## Two surfaces, one session

| Gesture | Opens |
|---|---|
| `omarchy-shell shell toggle javih.qobuz` — bind it to a key | the **app** |
| Clicking the bar widget · `omarchy-shell javih.qobuz toggle` | the **panel** |

```lua
o.bind("SUPER, M", "Qobuz", "omarchy-shell shell toggle javih.qobuz")
```

The split is not a convention this plugin invented: declaring the `overlay`
kind alongside `bar-widget` takes the plugin off the bar-widget path in
`shell.qml`'s `isBarWidgetPanelPlugin`, which is what re-points `shell toggle`
at the app. The panel keeps its own `IpcHandler`, which never went through that
route.

**The panel** is the glanceable half: what is playing, transport, and the queue,
plus an *Abrir Qobuz* button. Nothing that needs room.

**The app** is a full-screen overlay with a sidebar, a main area and a player
bar along the bottom:

| Section | What it holds |
|---|---|
| **Descubrir** | Qobuz's editorial rails — album of the week, new releases, most streamed, press awards. |
| **Buscar** | Catalogue search across albums, tracks, artists and playlists. |
| **Cola** | The upcoming queue. Click a track to jump to it. |
| **Letra** | Lyrics for the current track. |
| **Tu biblioteca** | Favourite albums, tracks and artists, and your playlists — each one also listed in the sidebar. |
| **Estado** | The half of `/api/status` the bar has no room for: daemon version and uptime, audio backend and device, bit-perfect, format, Qobuz Connect and the last errors. |

Collections are cover grids; tracks are dense numbered lists. Opening an album,
artist or playlist drills into its own page — big cover, a play button, a
favourite toggle, and the track listing (an artist gets top tracks plus every
release group). The back button names wherever you came from, so the same album
behaves identically whether you reached it from search, your library or a
discover rail.

Both surfaces read the same `QobuzService` singleton: `shell.qml` injects it
into the overlay (`item.service = shell.serviceFor(pluginId)`), so playing
something in the app moves the bar widget in the same tick, with no state to
reconcile. Each section fetches on first open and not before.

## The Hi-Res mark

Tracks Qobuz reports as hi-res are marked with the official Japan Audio Society
**Hi-Res AUDIO** logo — in the panel beside the sample rate, and on search
results. `assets/hi-res-audio.svg` comes from Wikipedia, which tags it
**PD-textlogo**: too simple to attract copyright, so shipping it is fine. It is
still a JAS **trademark**, used here descriptively to mark content, not to
certify this software. Don't recolour or redraw it, and check JAS's terms
before shipping a fork as a product.

The mark is a fixed gold-and-black square by definition, so it is the one
element that deliberately ignores the theme — it carries its own contrast and
reads on light and dark alike. Qt's SVG renderer handles it (`qt6-svg` is
required, and it is already a Quickshell dependency); if it ever fails to load,
the badge falls back to a themed `HI-RES` wordmark rather than vanishing.

`Model.isHiRes()` trusts qbzd's own `hires` flag first and otherwise applies
the specification's threshold — at least 24-bit **and** 96 kHz — so a track
carrying only its format still gets marked correctly.

## How it works

`QobuzService.qml` is a `service`-kind singleton — the bar instantiates widgets
once *per monitor*, so the daemon connection and the state live there rather
than in the widget, which reaches it via `bar.shell.serviceFor("javih.qobuz")`.
The app gets the same instance handed to it by the shell's panel loader.

Two shell helpers do all the I/O, because qbzd answers **403 to any request
carrying an `Origin` header** (its CSRF guard) and QML's `XMLHttpRequest` sends
one:

- `bin/qbzd-api` — one request, one line of JSON, qbzd's exit codes preserved
  (`3` unreachable, `4` needs auth).
- `bin/qbzd-events` — the event stream as newline-delimited JSON.

Cover art needs a detour. qbzd leaves every track's `artwork_url` null and its
`album` set to the literal `"Unknown Album"` when the track was queued from an
album id, and `/api/artwork/current` 404s as a direct consequence. The track
does carry `context_kind`/`context_id`, so the service does one
`/api/album?id=<upc>` lookup per album and takes the cover and the real title
from there.

State comes from **polling `/api/status`**, with the event stream only as an
accelerator. That is deliberate: on qbzd 2.0.2 `/api/events` sends zero bytes —
not even HTTP response headers — until the first event fires, so an idle stream
and a dead one are indistinguishable. `/api/status` also works while logged
out, which is what lets the panel tell "daemon down" apart from "not logged
in". The poll backs off from 1 s while playing to 15 s while the daemon is
unreachable.

## Development

```bash
node --test tests/                                    # reducer, against real captures
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell *.qml
omarchy plugin validate .
bash -n bin/qbzd-api bin/qbzd-events
```

`tests/fixtures/` holds verbatim responses from a live qbzd 2.0.2. They are the
authority over the wiki, which is wrong in at least three places: `/api/queue`
returns `upcoming`/`history`/`current_track` rather than a flat `tracks` array,
the previous-track route is `/api/playback/previous` (`/prev` 404s), and
`/api/playback/mute` does not exist. `/api/search` takes **plural** type
values (`albums`, not `album`), and `/api/play` takes a typed id —
`{"album_id": "..."}`, `{"track_id": N}`, `{"artist_id": N}`,
`{"playlist_id": N}` — not the documented `{"content": "album:ID"}`.

Catalogue responses also nest what the playback ones keep flat, inconsistently
enough to be worth listing:

- A search track's artist is `performer.name`; its own `artist` is null.
- An artist page names itself in `name.display`, and release lists nest again
  as `artist.name.display`.
- Discover albums leave `artist` null and fill `artists[]` instead.
- An artist page's portrait is `{hash, format}`, not a URL — it has to be
  assembled as `static.qobuz.com/images/artists/covers/<size>/<hash>.<format>`.
- `/api/favorites?type=albums` answers with `type: "album"`, **singular**,
  while the bucket it fills stays plural — so the echoed value cannot be used
  as the key to read the response back.

Anything reading these has to unwrap them or it renders `[object Object]`,
which is what `nameOf`, `artistsLabel` and `artistPortraitUrl` are for.

Saving any file under `~/.config/omarchy/plugins/` hot-reloads the plugin —
**except** `QobuzModel.js`. QML caches imported JS libraries past
`Qt.clearComponentCache()`, so changes to the reducer need `omarchy restart
shell` to take effect. Editing QML alone reloads normally.

## Scope

Everything qbzd exposes for listening is wired up: now playing with cover art,
transport, progress, volume, shuffle/repeat, the queue, search, favourites
(add and remove), your playlists, album/artist/playlist pages, the discover
rails and lyrics.

Not covered: creating or editing playlists (`/api/playlist/create`, `/update`,
`/tracks/add`, `/tracks/remove`), Qobuz Connect device control, scrobbler
setup, and the radio/suggestion endpoints. All are reachable through `qbzd`
on the command line.

## License

MIT.
