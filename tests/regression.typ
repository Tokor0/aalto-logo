// Renders every logo as either native curves or the reference PNG, so the two
// sheets can be pixel-diffed by tests/compare_render.py. Select the mode with
// `--input mode=vector|raster`.
//
// Both modes draw into a box of identical size, taken from the vector data's
// native aspect ratio. The PNGs are cropped to whole pixels and so are off
// true aspect by up to ~0.7%; forcing the same box corrects for that, leaving
// only genuine geometry differences in the diff.
#import "../lib.typ": aalto-logo

#let mode = sys.inputs.at("mode", default: "vector")

// The reference PNGs are build input, not a shipped asset, so they are loaded
// straight from sources/png/ rather than through the library.
#let reference(unit, language, size, mark, ..args) = image(
  "../sources/png/" + (unit, language, size, "black", mark).join("_") + ".png",
  ..args,
)
#let logo-height = 60pt

// Pin the layout so each logo occupies an exact, predictable band.
#set page(width: 330pt, height: auto, margin: 8pt, fill: white)
#set block(spacing: 0pt)
#set par(spacing: 0pt, leading: 0pt)

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

#for (unit, language, size, mark) in combinations {
  let data = eval(
    read("../logos/" + (unit, language, size, mark).join("_") + ".typ"),
    mode: "code",
  )
  let (native-width, native-height) = data.size
  let width = logo-height * (native-width / native-height)
  block(height: logo-height + 4pt, if mode == "vector" {
    aalto-logo(
      unit: unit,
      language: language,
      size: size,
      mark: mark,
      color: "black",
      height: logo-height,
      width: width,
    )
  } else {
    reference(unit, language, size, mark, height: logo-height, width: width)
  })
}
