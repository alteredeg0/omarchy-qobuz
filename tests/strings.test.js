// node --test tests/strings.test.js
//
// The point of these is the parity check: a key added to one language and
// forgotten in the other is the failure mode of every hand-rolled i18n table.

const test = require("node:test")
const assert = require("node:assert")

const S = require("../QobuzStrings.js")

test("every language carries exactly the same keys", () => {
  const reference = Object.keys(S.STRINGS[S.DEFAULT_LANG]).sort()
  for (const lang of S.LANGUAGES) {
    const keys = Object.keys(S.STRINGS[lang]).sort()
    const missing = reference.filter((k) => !keys.includes(k))
    const extra = keys.filter((k) => !reference.includes(k))
    assert.deepEqual(missing, [], `${lang} is missing keys`)
    assert.deepEqual(extra, [], `${lang} has keys no other language has`)
  }
})

test("no translation is left empty", () => {
  for (const lang of S.LANGUAGES) {
    for (const [key, value] of Object.entries(S.STRINGS[lang])) {
      assert.equal(typeof value, "string", `${lang}.${key} must be a string`)
      assert.equal(value.length > 0, true, `${lang}.${key} is empty`)
    }
  }
})

test("placeholders match across languages", () => {
  // "{0} tracks" must not become "pistas" with the count silently dropped.
  const placeholders = (s) => (s.match(/\{\d\}/g) || []).sort().join(",")
  for (const [key, value] of Object.entries(S.STRINGS[S.DEFAULT_LANG])) {
    for (const lang of S.LANGUAGES) {
      assert.equal(placeholders(S.STRINGS[lang][key]), placeholders(value),
        `${lang}.${key} does not use the same placeholders as ${S.DEFAULT_LANG}`)
    }
  }
})

test("t substitutes and falls back rather than blanking", () => {
  assert.equal(S.t("en", "action.play"), "Play")
  assert.equal(S.t("es", "action.play"), "Reproducir")
  assert.equal(S.t("es", "browse.trackCount", 5), "5 pistas")
  assert.equal(S.t("en", "browse.trackCount", 5), "5 tracks")
  assert.equal(S.t("en", "status.bits", 24, "192 kHz"), "24-bit · 192 kHz")

  // An unknown key shows itself, so a gap is visible instead of blank.
  assert.equal(S.t("en", "nope.nope"), "nope.nope")
  // An unknown language falls back to English rather than to keys.
  assert.equal(S.t("fr", "action.play"), "Play")
})

test("resolve honours an explicit choice and follows the locale on auto", () => {
  assert.equal(S.resolve("es", "en_US.UTF-8"), "es", "explicit wins over the locale")
  assert.equal(S.resolve("en", "es_ES.UTF-8"), "en")

  assert.equal(S.resolve("auto", "es_ES.UTF-8"), "es")
  assert.equal(S.resolve("auto", "es"), "es")
  assert.equal(S.resolve("auto", "es-ES"), "es")
  assert.equal(S.resolve("auto", "en_US.UTF-8"), "en")
  // Neither language available for the locale, nor a usable value.
  assert.equal(S.resolve("auto", "de_DE.UTF-8"), "en")
  assert.equal(S.resolve("auto", ""), "en")
  assert.equal(S.resolve("nonsense", "es_ES"), "en")
  assert.equal(S.resolve(undefined, "es_ES"), "es", "undefined means auto")
})

test("albumsCountLabel picks the right plural per language", () => {
  assert.equal(S.albumsCountLabel("en", 1), "1 album")
  assert.equal(S.albumsCountLabel("en", 11), "11 albums")
  assert.equal(S.albumsCountLabel("es", 1), "1 álbum")
  assert.equal(S.albumsCountLabel("es", 11), "11 álbumes")
  assert.equal(S.albumsCountLabel("en", 0), "")
  assert.equal(S.albumsCountLabel("en", -3), "")
})

test("rail and release-group labels degrade to the raw key", () => {
  assert.equal(S.railLabel("es", "new_releases"), "NOVEDADES")
  assert.equal(S.railLabel("en", "new_releases"), "NEW RELEASES")
  // qbzd can add a rail we have never seen; it must still render something.
  assert.equal(S.railLabel("en", "brand_new_thing"), "BRAND NEW THING")

  assert.equal(S.releaseGroupLabel("es", "epSingle"), "EPS Y SINGLES")
  assert.equal(S.releaseGroupLabel("en", "epSingle"), "EPS AND SINGLES")
  assert.equal(S.releaseGroupLabel("en", "remix"), "REMIX")
})

test("both languages cover every rail and release group the code emits", () => {
  const rails = ["new_releases", "most_streamed", "press_awards", "qobuzissims",
                 "album_of_the_week", "ideal_discography", "playlists", "playlists_tags"]
  const groups = ["album", "live", "compilation", "epSingle", "download",
                  "awardedRelease", "other"]
  for (const lang of S.LANGUAGES) {
    for (const r of rails) assert.equal(S.STRINGS[lang]["rail." + r] !== undefined, true, `${lang} rail.${r}`)
    for (const g of groups) assert.equal(S.STRINGS[lang]["release." + g] !== undefined, true, `${lang} release.${g}`)
  }
})
