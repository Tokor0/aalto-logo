// The illustration embedded in README.md. Rendered with `make example`.
//
// docs/ is excluded from the published bundle: Universe asks that README
// images not be shipped to everyone who imports the package.
#import "../lib.typ": aalto-logo, aalto-color

#set page(width: 460pt, height: auto, margin: 14pt, fill: white)

#let caption(body) = block(
  below: 6pt,
  text(size: 6.5pt, tracking: 0.5pt, fill: rgb("55504c"), upper(body)),
)

#stack(
  dir: ttb,
  spacing: 18pt,

  [
    #caption[Every unit, at any size]
    #stack(dir: ltr, spacing: 16pt, ..("Aalto", "ARTS", "ELEC", "SCI").map(unit =>
      aalto-logo(unit: unit, language: "en", size: "large", height: 26pt)))
  ],

  [
    #caption[Any colour, from one set of outlines]
    #grid(
      columns: (1fr, 1fr),
      rows: 2,
      gutter: 12pt,
      ..("ARTS", "BIZ", "CHEM", "ENG").map(unit =>
        aalto-logo(unit: unit, language: "en", size: "small", height: 20pt,
          color: aalto-color(unit: unit))),
    )
  ],

  [
    #caption[White on a dark ground; language follows the document]
    #block(fill: rgb("1a1a1a"), inset: 9pt, width: 100%,
      aalto-logo(unit: "ELEC", language: "fi", size: "small", height: 22pt, color: "white"))
  ],

  [
    #caption[Draft placeholders occupy the exact footprint of the logo]
    #stack(dir: ltr, spacing: 16pt, ..("ELEC", "SCI").map(unit => box(stack(
      dir: ttb,
      spacing: 5pt,
      aalto-logo(unit: unit, language: "en", size: "small", height: 22pt),
      aalto-logo(unit: unit, language: "en", size: "small", height: 22pt, draft: true),
    ))))
  ],
)
