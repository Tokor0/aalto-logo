// Every logo next to the DRAFT placeholder that stands in for it, to show that
// the placeholder occupies exactly the same footprint. Compile with:
//   typst compile --root . tests/draft-side-by-side.typ draft-side-by-side.pdf
//
// tests/draft.typ asserts the footprint equality numerically; this is the
// version you can look at.
#import "../lib.typ": aalto-logo

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
      Aalto logos — vector vs. DRAFT placeholder
      #h(1fr)
      page #counter(page).display()
    ]
  },
)
#set text(size: 7pt)

#align(center)[
  #text(size: 15pt, weight: "bold")[Aalto logos: vector vs. DRAFT placeholder]

  #text(size: 8.5pt, fill: luma(35%))[
    Left column the real logo, right column the placeholder `draft: true` puts
    in its place. The two occupy an identical box, so switching a document into
    draft never reflows it. 123 logos.
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

// Prints the box the logo actually occupies, so the equality is legible as a
// number and not only as a shape.
#let measured(..args) = context {
  let size = measure(aalto-logo(..args))
  text(size: 6pt, fill: luma(50%))[
    #calc.round(size.width.pt(), digits: 1) x
    #calc.round(size.height.pt(), digits: 1) pt
  ]
}

#table(
  columns: (auto, 1fr, 1fr),
  align: (left + horizon, center + horizon, center + horizon),
  stroke: 0.4pt + luma(80%),
  inset: (x: 5pt, y: 4pt),
  table.header(
    header[logo],
    header[vector — #raw("curve()")],
    header[placeholder — #raw("draft: true")],
  ),
  ..combinations
    .map(((unit, language, size, mark)) => {
      let common = (unit: unit, language: language, size: size, mark: mark)
      let height = height-for(size)
      (
        {
          raw((unit, language, size, mark).join("_"))
          linebreak()
          measured(..common, height: height)
        },
        aalto-logo(..common, height: height),
        aalto-logo(..common, height: height, draft: true),
      )
    })
    .flatten(),
)
