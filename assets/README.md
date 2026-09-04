# assets

`hi-res-audio.svg` — the Japan Audio Society "Hi-Res AUDIO" mark, from
<https://en.wikipedia.org/wiki/File:Hi-Res_Audio_(logo).svg>.

Wikipedia tags it **PD-textlogo**: it is "not original enough" to attract
copyright, so there is no copyright restriction on shipping it.

It is, however, a **registered trademark of the Japan Audio Society**, which
licenses it to manufacturers whose products meet its specification. This plugin
uses it descriptively — to mark tracks Qobuz reports as hi-res — not to certify
anything about the software. Do not recolour or redraw it, and if you fork this
into something that ships as a product, check JAS's terms first.

`qobuz-mark.svg` — the Qobuz "qbz" icon, from
<https://commons.wikimedia.org/wiki/File:Qobuz_qbz_icon.svg> (Commons' copy of
Qobuz's own `static.qobuz.com/images/favicon/favicon.svg`).

Commons tags it **PD-textlogo** for the same reason: simple geometric shapes and
text, below the threshold of originality, so no copyright attaches.

It is still **Qobuz's trademark**. This plugin is not by or endorsed by Qobuz; it
uses the mark nominatively, to say which service the plugin plays from. If you
fork this into a product, read Qobuz's terms first.

`qobuz-mark-symbolic.svg` — the same mark reduced to its "qbz" letterforms on a
transparent ground, cropped to their bounding box. Nothing is redrawn: the three
paths are lifted verbatim out of `qobuz-mark.svg` and the black rounded square
behind them is dropped, so the shape is carried by the alpha channel and the bar
can tint it to the theme the way it tints every other icon. The full mark is a
black square with white glyphs; at 16 px in a themed bar it would read as a
blob, which is why the symbolic form exists — the same reason a tray icon ships
a symbolic variant. Use the full mark wherever the surface can afford it.
