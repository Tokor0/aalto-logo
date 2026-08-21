// Visual regression: native curve() output against the reference PNG.
#import "../lib.typ": aalto-logo, aalto-color

// The reference PNGs are build input, not a shipped asset.
#let reference(..args) = image("../sources/png/ELEC_en_small_black_question.png", ..args)

#set page(width: 420pt, height: 320pt, margin: 12pt, fill: white)
#set text(size: 8pt)

*native curve()* #h(1em) #aalto-logo(unit: "ELEC", language: "en", size: "small", height: 40pt)

*reference PNG* #h(1em) #reference(height: 40pt)

*overlaid* — PNG underneath, curve in translucent red on top; any black or red fringe is a mismatch

#block(height: 46pt)[
  #place(top + left, reference(height: 40pt))
  #place(top + left, aalto-logo(unit: "ELEC", language: "en", size: "small", height: 40pt, color: rgb(255, 0, 0, 130)))
]

*scaled and recoloured*

#aalto-logo(unit: "ELEC", mark: "quote", size: "small", language: "en", height: 12pt)
#h(1em)
#aalto-logo(unit: "ELEC", mark: "exclamation", size: "small", language: "en", height: 30pt, color: aalto-color("red"))

#block(fill: black, inset: 5pt, aalto-logo(unit: "ELEC", size: "small", language: "en", height: 20pt, color: "white"))
