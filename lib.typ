// Aalto University logo package
//
// #aalto-logo(
//   unit:     "ELEC",        // "Aalto" | "ARTS" | "ELEC" | "SCI" | "ENG" | "CHEM" | "BIZ"
//   language: "en",          // "en" | "fi" | "se" | "fi-se-en" (Aalto unit only)
//   size:     "large",       // "large" | "small"
//   color:    "black",       // "black" | "white"
//   mark:     "question",    // "question" | "quote" | "exclamation"
//   ..image-args,            // forwarded to image()
// )

#let aalto-logo(
  unit: "Aalto",
  language: "en",
  size: "large",
  color: "black",
  mark: "question",
  ..args,
) = {
  let valid-units = ("Aalto", "ARTS", "ELEC", "SCI", "ENG", "CHEM", "BIZ")
  let valid-languages = ("en", "fi", "se", "fi-se-en")
  let valid-sizes = ("large", "small")
  let valid-colors = ("black", "white")
  let valid-marks = ("question", "quote", "exclamation")

  for (param, value, valid) in (
    ("unit", unit, valid-units),
    ("language", language, valid-languages),
    ("size", size, valid-sizes),
    ("color", color, valid-colors),
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
  assert(
    not (unit == "Aalto" and size == "small" and language != "fi-se-en"),
    message: "aalto-logo: the small single-language Aalto University logo has been decommissioned. Use language \"fi-se-en\" or size \"large\".",
  )

  let path = "logos/" + (unit, language, size, color, mark).join("_") + ".png"
  image(path, ..args)
}
