// Aalto University logo package
//
// #aalto-logo(
//   unit:     "ELEC",        // "Aalto" | "ARTS" | "ELEC" | "SCI" | "ENG" | "CHEM" | "BIZ"
//   language: "auto",        // "en" | "fi" | "se" | "fi-se-en" (Aalto unit only) | "auto"
//   size:     "small",       // "large" | "small"
//   color:    "black",       // "black" | "white", or any Typst color
//   mark:     "question",    // "question" | "quote" | "exclamation"
//   height:   auto,          // 25pt if width is also auto
//   width:    auto,          // defaults to the logo's native aspect ratio
//   draft:    false,         // if true, a same-sized "DRAFT" placeholder box
//   font:     "Inter",       // draft placeholder font; falls back to the
//                            // document's own fonts. auto = inherit only
// )

// Loads the generated curve data for one logo.
//
// The data files are read() + eval()'d rather than imported because Typst
// requires import paths to be string literals -- a static import would parse
// every logo on every compile, instead of only the one being used.
#let aalto-logo-data(name) = eval(
  read("logos/" + name + ".typ"),
  mode: "code",
)

// Resolves the box a logo occupies. Either dimension alone keeps the logo's
// native aspect ratio; neither given falls back to a fixed height.
//
// Both the real logo and the draft placeholder go through this, which is what
// makes a placeholder occupy exactly the footprint of the logo it replaces --
// toggling draft must never reflow the document.
#let aalto-logo-box(native, height: auto, width: auto) = {
  let (native-width, native-height) = native
  let height = if height == auto {
    if width == auto { 25pt } else { width * (native-height / native-width) }
  } else { height }
  let width = if width == auto { height * (native-width / native-height) } else { width }
  (width, height)
}

// Draws a logo from the generated curve data in logos/.
//
// The data files hold coordinates as ratios of the artwork's bounding box, so
// placing the curves inside a box() of the requested size scales them exactly.
#let aalto-logo-vector(name, fill: black, height: auto, width: auto) = {
  let data = aalto-logo-data(name)
  let (width, height) = aalto-logo-box(data.size, height: height, width: width)

  box(width: width, height: height, {
    for path in data.paths {
      place(curve(
        fill: fill,
        fill-rule: path.fill-rule,
        stroke: none,
        ..path.components,
      ))
    }
  })
}

// Preferred font for the draft stamp. Typst embeds no proportional sans-serif,
// so this is a preference rather than a guarantee: the families the document
// itself uses are appended as the fallback.
#let aalto-draft-font = "Inter"

// Resolves a font preference into a family list ending in the document's own
// fonts, so an unavailable preference degrades to the surrounding text instead
// of to Typst's built-in serif. Must be called from a context.
//
// Note that Typst warns once per use for every family it cannot find, with no
// way to suppress it (typst/typst#6010), so `auto` -- inherit, and name nothing
// that might be missing -- is the way to keep a document silent.
#let aalto-draft-families(preference) = {
  let inherited = if type(text.font) == str { (text.font,) } else { text.font }
  if preference == auto {
    inherited
  } else if type(preference) == str {
    (preference,) + inherited
  } else {
    preference + inherited
  }
}

// Placeholder standing in for a logo in draft documents: an outlined box of
// exactly the logo's size with "DRAFT" in it. Drawn natively, so it needs no
// asset and takes the same colour as the real logos.
#let aalto-logo-draft(
  name,
  fill: black,
  height: auto,
  width: auto,
  font: aalto-draft-font,
) = context {
  let (width, height) = aalto-logo-box(
    aalto-logo-data(name).size,
    height: height,
    width: width,
  )
  let inset = height / 12
  let border = calc.max(height / 25, 0.5pt)
  let families = aalto-draft-families(font)

  // Fit "DRAFT" to the box rather than assuming a size: which font actually
  // wins is unknown until layout, so measure it and scale to what fits.
  let stamp(size) = text(font: families, size: size, weight: "bold", "DRAFT")
  let measured = measure(stamp(100pt))
  let scale = calc.min(
    (width - 2 * inset - 2 * border) / measured.width,
    (height - 2 * inset - 2 * border) / measured.height,
  )

  box(
    width: width,
    height: height,
    stroke: border + fill,
    inset: inset,
    align(center + horizon, text(fill: fill, stamp(100pt * scale))),
  )
}

#let aalto-logo(
  unit: "Aalto",
  language: "auto",
  size: "small",
  height: auto,
  width: auto,
  color: "black",
  mark: "question",
  draft: false,
  font: aalto-draft-font,
) = context {
  let valid-units = ("Aalto", "ARTS", "ELEC", "SCI", "ENG", "CHEM", "BIZ")
  let valid-languages = ("en", "fi", "se", "fi-se-en")
  let language = if language == "auto" {
    let lang = text.lang
    if lang in valid-languages { lang } else { "en" }
  } else {
    language
  }
  let valid-sizes = ("large", "small")
  let valid-colors = ("black", "white")
  let valid-marks = ("question", "quote", "exclamation")

  for (param, value, valid) in (
    ("unit", unit, valid-units),
    ("language", language, valid-languages),
    ("size", size, valid-sizes),
    ("mark", mark, valid-marks),
  ) {
    assert(
      valid.contains(value),
      message: "aalto-logo: invalid "
        + param
        + " '"
        + value
        + "'. Valid values: "
        + valid.join(", "),
    )
  }
  // Sizing: either dimension alone keeps the logo's native aspect ratio;
  // neither given falls back to a fixed height.
  let height = if height == auto and width == auto { 25pt } else { height }

  assert(type(draft) == bool, message: "aalto-logo: draft must be a boolean")

  // Logos are recoloured at compile time, so they accept any colour.
  assert(
    type(color) == std.color or valid-colors.contains(color),
    message: "aalto-logo: invalid color. Use "
      + valid-colors.map(c => "\"" + c + "\"").join(" or ")
      + ", or any Typst color.",
  )
  // Applies to drafts too: the placeholder is sized from the logo it stands in
  // for, so that logo has to exist.
  assert(
    not (unit == "Aalto" and size == "small" and language != "fi-se-en"),
    message: "aalto-logo: the small single-language Aalto University logo has been decommissioned. Use language \"fi-se-en\" or size \"large\".",
  )

  let name = (unit, language, size, mark).join("_")
  let fill = if type(color) == std.color {
    color
  } else if color == "white" { white } else { black }

  if draft {
    aalto-logo-draft(name, fill: fill, height: height, width: width, font: font)
  } else {
    aalto-logo-vector(name, fill: fill, height: height, width: width)
  }
}

#let aalto-color(..color, unit: "Aalto") = {
  assert(color.pos().len() <= 1)
  let color = if color.pos().len() == 1 { color.pos().first() } else { "red" }
  let style-guide-colors = (
    red: rgb("FD6360"),
    yellow: rgb("F7E159"),
    blue: rgb("46A5FF"),
    gray: rgb("86807B"), // actually this one isn't official
  )
  let unit-colors = (
    Aalto: style-guide-colors.at(color),
    ARTS: rgb("FFC341"),
    ELEC: rgb("A987FF"),
    SCI: rgb("FF8D4F"),
    ENG: rgb("DC6ADE"),
    CHEM: rgb("5DD089"),
    BIZ: rgb("9BD84C"),
  )
  unit-colors.at(unit)
}
