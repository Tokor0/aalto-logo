// Every logo drawn as native Typst curves next to its reference PNG, for
// eyeballing the conversion. Compile with:
//   typst compile --root . tests/side-by-side.typ side-by-side.pdf
#import "../lib.typ": aalto-logo

// The reference PNGs are build input, not a shipped asset, so they are loaded
// straight from sources/png/ rather than through the library.
#let reference(unit, language, size, mark, ..args) = image(
  "../sources/png/" + (unit, language, size, "black", mark).join("_") + ".png",
  ..args,
)

// The "large" variants stack their wordmark beneath the mark, so they need
// more height than the wide "small" ones to stay legible. Both columns of a
// row always use the same height, which is what makes the pair comparable.
#let height-for(size) = if size == "large" { 46pt } else { 20pt }

#set page(
  paper: "a4",
  margin: (x: 28pt, y: 34pt),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 7pt, fill: luma(45%))
      Aalto logos — native curves vs. reference PNG
      #h(1fr)
      page #counter(page).display()
    ]
  },
)
#set text(size: 7pt)

#align(center)[
  #text(size: 15pt, weight: "bold")[Aalto logos: vector vs. raster]

  #text(size: 8.5pt, fill: luma(35%))[
    Left column drawn by Typst #raw("curve()") from #raw("logos/"),
    right column the scraped PNG. 123 logos, paired at identical heights.
  ]
]

#v(6pt)

#let combinations = {
  let out = ()
  for unit in ("Aalto", "ARTS", "BIZ", "CHEM", "ELEC", "ENG", "SCI") {
    for language in ("en", "fi", "se", "fi-se-en") {
      for size in ("large", "small") {
        // Skip combinations that do not exist upstream.
        let exists = if unit == "Aalto" {
          if size == "small" { language == "fi-se-en" } else { true }
        } else {
          language != "fi-se-en"
        }
        if exists {
          for mark in ("question", "quote", "exclamation") {
            out.push((unit, language, size, mark))
          }
        }
      }
    }
  }
  out
}

#let header(body) = table.cell(
  fill: luma(92%),
  text(weight: "bold", size: 7.5pt, body),
)

#table(
  columns: (auto, 1fr, 1fr),
  align: (left + horizon, center + horizon, center + horizon),
  stroke: 0.4pt + luma(80%),
  inset: (x: 5pt, y: 4pt),
  table.header(
    header[logo],
    header[vector — #raw("curve()")],
    header[raster — PNG],
  ),
  ..combinations
    .map(((unit, language, size, mark)) => (
      raw((unit, language, size, mark).join("_")),
      aalto-logo(
        unit: unit, language: language, size: size, mark: mark,
        height: height-for(size),
      ),
      reference(unit, language, size, mark, height: height-for(size)),
    ))
    .flatten(),
)
