# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the package
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

Initial release.

- `aalto-logo()` draws any Aalto University or school logo as native Typst
  curves: 7 units × 3 languages (plus the trilingual Aalto lockup) × 2 sizes ×
  3 marks.
- Logos are resolution independent and accept any Typst colour, recoloured at
  compile time from a single set of outlines.
- `language: "auto"` follows `text.lang`.
- `draft: true` substitutes a natively drawn `DRAFT` placeholder occupying
  exactly the footprint of the logo it replaces.
- `aalto-color()` returns the school identity colours and the Aalto style-guide
  colours.
