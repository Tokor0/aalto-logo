// Exercises the parts of the API that the pixel regression does not cover:
// scaling, arbitrary colours, the white variant, the draft stamp and the
// raster fallback.
#import "../lib.typ": aalto-logo, aalto-color

#set page(width: 460pt, height: auto, margin: 12pt, fill: white)
#set text(size: 8pt)

= Scaling — one data file at 10pt, 25pt and 90pt

#aalto-logo(unit: "SCI", language: "en", size: "small", height: 10pt)

#aalto-logo(unit: "SCI", language: "en", size: "small", height: 25pt)

#aalto-logo(unit: "SCI", language: "en", size: "small", height: 90pt)

= Arbitrary colours from the same outlines

#aalto-logo(unit: "ARTS", language: "en", size: "small", height: 22pt, color: aalto-color(unit: "ARTS"))

#aalto-logo(unit: "BIZ", language: "en", size: "small", height: 22pt, color: aalto-color(unit: "BIZ"))

#aalto-logo(unit: "ENG", language: "en", size: "small", height: 22pt, color: aalto-color("red"))

#block(fill: rgb("1a1a1a"), inset: 8pt, width: 100%)[
  #aalto-logo(unit: "CHEM", language: "en", size: "small", height: 22pt, color: "white")
]

= Draft placeholders, drawn natively (no asset)

Each placeholder occupies exactly the footprint of the logo it replaces, so
turning draft on and off never reflows the document. See tests/draft.typ, which
asserts that for every logo.

#let side-by-side(..args) = box(stack(dir: ttb, spacing: 4pt,
  aalto-logo(..args, height: 26pt),
  aalto-logo(..args, height: 26pt, draft: true),
))

#side-by-side(unit: "ELEC", language: "en", size: "small")
#h(1em)
#side-by-side(unit: "SCI", language: "fi", size: "large")
#h(1em)
#side-by-side(unit: "ARTS", language: "fi", size: "small")

Any colour:

#aalto-logo(unit: "BIZ", language: "en", size: "small", height: 22pt, draft: true, color: aalto-color("red"))

= Every unit, large, English

#for unit in ("Aalto", "ARTS", "BIZ", "CHEM", "ELEC", "ENG", "SCI") {
  box(aalto-logo(unit: unit, language: "en", size: "large", height: 30pt))
  h(6pt)
}

= Language variants (auto-detect follows text.lang)

#for lang in ("en", "fi", "se") {
  set text(lang: lang)
  block(aalto-logo(unit: "ELEC", size: "small", height: 20pt))
}
// "fi-se-en" is not a valid text.lang code, so it must be passed explicitly.
#aalto-logo(unit: "Aalto", language: "fi-se-en", size: "small", height: 30pt)
