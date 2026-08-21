// Smoke test for the packaged form of the library.
//
// Every other test imports ../lib.typ relatively, which never exercises the
// package at all. This one goes through the package resolver, so it is what
// catches a wrong `entrypoint`, an `exclude` pattern that swallows logos/, or
// a read() path that only happens to work relative to the repo.
//
// Run it after `make install-local`, or inside `nix develop` (which points
// TYPST_PACKAGE_PATH at a built copy of the package).
#import "@local/aalto-logo:0.1.0": aalto-logo, aalto-color

#set page(width: 300pt, height: auto, margin: 12pt, fill: white)
#set text(size: 8pt)

Imported through `@local/aalto-logo:0.1.0`.

// A vector logo: proves logos/ came along with the entrypoint and that
// lib.typ's read() resolves inside the package directory.
#aalto-logo(unit: "ELEC", language: "en", size: "small", height: 26pt)

// A second data file, recoloured, so a single lucky read is not enough.
#aalto-logo(
  unit: "ARTS",
  language: "fi",
  size: "large",
  height: 26pt,
  color: aalto-color(unit: "ARTS"),
)

// The draft placeholder, which reads the same data for its dimensions but
// draws nothing from it.
#aalto-logo(unit: "SCI", language: "en", size: "small", height: 26pt, draft: true)
