# Fixtures

Verbatim responses from a live `qbzd` 2.0.2, kept because they are the
authority on the daemon's actual shapes — the wiki is wrong in several places
that these captures document.

They were taken from a real Qobuz account, so the fields that identify a person
are replaced with placeholders and nothing else is touched:

| Field | Replaced with |
|---|---|
| `favorites.user.id`, `auth.user_id` | `1000001` |
| `favorites.user.login` | `user@example.com` |
| `qconnect.device_name` | `QBZ (example-host)` |
| playlist `owner.name` (the account's own) | `example-user` |
| `data_root` | `/home/example-user/.local/share/qbzd` |

Catalogue content — album titles, artists, cover URLs, Qobuz's own editorial
playlists — is public catalogue data and is kept exactly as returned.

To refresh a fixture, capture it and run the same substitutions before
committing.
