// Asserts that a DRAFT placeholder occupies exactly the footprint of the logo
// it stands in for, for every logo and every way of specifying the size.
// Toggling draft must never reflow a document, so Typst checks it here rather
// than leaving it to the eye: a mismatch aborts compilation and names the logo.
//
//   typst compile --root . tests/draft.typ
#import "../lib.typ": aalto-logo

#set page(width: 400pt, height: auto, margin: 16pt)
#set text(size: 8pt)

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

// Each entry is a way of asking for a size: by height, by width, and by
// neither (the built-in default). All three go through the shared resolver.
#let sizings = (
  ("height only", (height: 30pt)),
  ("width only", (width: 120pt)),
  ("neither", (:)),
)

#context {
  let checked = 0
  for (unit, language, size, mark) in combinations {
    for (label, args) in sizings {
      let common = (unit: unit, language: language, size: size, mark: mark)
      let real = measure(aalto-logo(..common, ..args))
      let placeholder = measure(aalto-logo(..common, ..args, draft: true))
      let name = (unit, language, size, mark).join("_")
      // Compared with a tolerance, not exactly: measure() round-trips through
      // layout and loses the last bit or two of a float (~1e-13pt). A real
      // mismatch would be percent-scale, so 1/1000pt still catches everything
      // that matters while ignoring that noise.
      let off = calc.max(
        calc.abs(real.width.pt() - placeholder.width.pt()),
        calc.abs(real.height.pt() - placeholder.height.pt()),
      )
      assert(
        off < 0.001,
        message: "draft placeholder for "
          + name
          + " (" + label + ") is "
          + repr(placeholder.width) + " x " + repr(placeholder.height)
          + " but the logo is "
          + repr(real.width) + " x " + repr(real.height),
      )
      checked += 1
    }
  }

  [*#checked* size checks passed across *#combinations.len()* logos
   and *#sizings.len()* ways of specifying the size.]
}

= Placeholder beside the logo it replaces

At the two aspect-ratio extremes, plus a mid-range case.

#let pair(caption, ..args) = {
  block(breakable: false)[
    #text(fill: luma(40%), raw(caption))
    #v(3pt)
    #aalto-logo(..args, height: 34pt)
    #v(3pt)
    #aalto-logo(..args, height: 34pt, draft: true)
  ]
  v(8pt)
}

#pair("SCI_fi_large_question (narrowest, 0.87)", unit: "SCI", language: "fi", size: "large")
#pair("ARTS_fi_small_question (widest, 6.12)", unit: "ARTS", language: "fi", size: "small")
#pair("ELEC_en_small_question (mid, 4.85)", unit: "ELEC", language: "en", size: "small")

= Colours and modes

#aalto-logo(unit: "ELEC", language: "en", size: "small", height: 22pt, draft: true)

#block(fill: rgb("1a1a1a"), inset: 6pt, width: 100%,
  aalto-logo(unit: "ELEC", language: "en", size: "small", height: 22pt, draft: true, color: "white"))

#aalto-logo(unit: "ELEC", language: "en", size: "small", height: 22pt, draft: true, color: rgb("FD6360"))

= Font

The stamp prefers Inter and falls back to whatever the document itself uses, so
an unavailable preference degrades to the surrounding text rather than to
Typst's built-in serif. `font: auto` inherits only, which is the way to keep a
document free of "unknown font family" warnings -- Typst emits one per use for
every family it cannot find, with no way to suppress it.

#let variants = (
  ([default (`"Inter"`)], (:)),
  ([`font: auto`], (font: auto)),
  ([`font: "Abril Fatface"`], (font: "Abril Fatface")),
)

#for (label, args) in variants {
  block(breakable: false)[
    #label
    #v(2pt)
    #aalto-logo(unit: "ELEC", language: "en", size: "small", height: 24pt, draft: true, ..args)
  ]
  v(5pt)
}

The font never affects the footprint, since the box comes from the logo data
rather than from the text -- the size assertions above cover the default, and
these all match it.

#context {
  let base = measure(aalto-logo(unit: "ELEC", language: "en", size: "small", height: 24pt, draft: true))
  for (label, args) in variants {
    let m = measure(aalto-logo(unit: "ELEC", language: "en", size: "small", height: 24pt, draft: true, ..args))
    assert(
      calc.abs(m.width.pt() - base.width.pt()) < 0.001
        and calc.abs(m.height.pt() - base.height.pt()) < 0.001,
      message: "font choice changed the placeholder footprint",
    )
  }
  [All #variants.len() font variants occupy an identical box.]
}
