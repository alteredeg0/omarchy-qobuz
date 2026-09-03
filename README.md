# javih.qobuz

Qobuz in the Omarchy bar: the current track next to the clock, and a panel with
cover art, transport, progress, volume and the queue.

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

## Controls

**In the bar:** left click opens the panel · middle click toggles playback ·
scroll changes volume.

**In the panel:** `/` focus search · `Space` play/pause · `←`/`→`
previous/next · `s` shuffle · `l` repeat · `r` refresh · `Esc` close ·
`Tab` next panel.

**In search results:** click plays the album/track/artist/playlist, right
click appends a track to the queue. The queue section hides itself while
results are on screen.

**IPC:** `omarchy-shell javih.qobuz {open,close,toggle,refresh,status}`, plus
`search <query>` and `results` — so a Hyprland binding can go straight to a
query:

```lua
o.bind("SUPER SHIFT, Q", "Search Qobuz", "omarchy-shell javih.qobuz search ''")
```

Media keys need no setup: qbzd publishes MPRIS as
`org.mpris.MediaPlayer2.com.blitzfc.qbz`, which Omarchy's own media bindings
already drive.

## How it works

`QobuzService.qml` is a `service`-kind singleton — the bar instantiates widgets
once *per monitor*, so the daemon connection and the state live there rather
than in the widget, which reaches it via `bar.shell.serviceFor("javih.qobuz")`.

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

Catalogue responses also nest what the playback ones keep flat: a search
track's artist is `performer.name` (its own `artist` is null) and its album is
an object, so anything reading those fields has to unwrap them or it renders
`[object Object]`.

Saving any file under `~/.config/omarchy/plugins/` hot-reloads the plugin —
**except** `QobuzModel.js`. QML caches imported JS libraries past
`Qt.clearComponentCache()`, so changes to the reducer need `omarchy restart
shell` to take effect. Editing QML alone reloads normally.

## Scope

Done: now playing with cover art, transport, progress, volume, shuffle/repeat,
the queue, and catalogue search across albums, tracks, artists and playlists
with play-or-queue from the results.

Not wired up yet: favourites, playlist management, album/artist browsing,
discover rails and lyrics. qbzd exposes all of them (`/api/favorites`,
`/api/playlists`, `/api/artist`, `/api/discover`, `/api/lyrics`) and the
service is shaped to take them without restructuring.

## License

MIT.
