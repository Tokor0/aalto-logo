#!/usr/bin/env python3
"""Pixel-diff the native curve logos against the reference PNGs.

Renders tests/regression.typ twice -- once drawing every logo with Typst
curves, once with the reference PNGs from sources/png/ -- and compares the two
sheets band by band. The PNGs are build input rather than a shipped asset; get
them with `python3 download_logos.py --format png`.

Rasterising a vector never reproduces a resampled bitmap exactly, so both
sheets are blurred slightly before comparison. That washes out edge
antialiasing, which is not a defect, while leaving intact the things that are:
a wrong fill rule filling in a letter counter, a dropped subpath, a glyph in
the wrong place. Those survive any amount of blur.

Usage: python3 tests/compare_render.py [--ppi 200] [--keep]
"""
import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join("tests", "regression.typ")

LOGO_BLOCK_PT = 64  # must match `logo-height + 4pt` in regression.typ
MARGIN_PT = 8
# A pixel counts as damaged if it differs by more than this (0-255).
PIXEL_THRESHOLD = 96
# Fraction of a logo's ink allowed to differ before it is reported.
AREA_THRESHOLD = 0.02
# Blur radius at 200 ppi, scaled with resolution.
BLUR_AT_200_PPI = 2.0


# Logos where Aalto's PDF and PNG masters are different artwork, so the two
# sheets legitimately disagree. For CHEM_*_small_question the PDF sets the
# wordmark ~2% further from the A-mark than the PNG does; the mark itself and
# every letterform still match to a hairline, and the black and white PDFs
# agree with each other. The value is the largest difference tolerated, so a
# real regression on these logos would still be caught.
KNOWN_SOURCE_DIFFERENCES = {
    "CHEM_en_small_question": 0.40,
    "CHEM_fi_small_question": 0.40,
    "CHEM_se_small_question": 0.40,
}


def render(mode, out_path, ppi):
    subprocess.run(
        ["typst", "compile", "--root", ".", "--input", f"mode={mode}",
         SHEET, out_path, "--ppi", str(ppi)],
        check=True, cwd=ROOT,
    )
    return Image.open(out_path).convert("L")


def logo_names():
    """Same enumeration order as regression.typ."""
    names = []
    for unit in ("Aalto", "ARTS", "BIZ", "CHEM", "ELEC", "ENG", "SCI"):
        for language in ("en", "fi", "se", "fi-se-en"):
            for size in ("large", "small"):
                if unit == "Aalto":
                    exists = language == "fi-se-en" if size == "small" else True
                else:
                    exists = language != "fi-se-en"
                if exists:
                    for mark in ("question", "quote", "exclamation"):
                        names.append(f"{unit}_{language}_{size}_{mark}")
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ppi", type=int, default=200)
    parser.add_argument("--keep", action="store_true", help="keep the rendered sheets")
    args = parser.parse_args()

    png_dir = os.path.join(ROOT, "sources", "png")
    if not os.path.isdir(png_dir) or not os.listdir(png_dir):
        sys.exit(
            "sources/png/ is missing or empty. The reference PNGs are build "
            "input, not a shipped asset -- fetch them with\n"
            "    python3 download_logos.py --format png"
        )

    work = tempfile.mkdtemp(prefix="aalto-regression-")
    vector = render("vector", os.path.join(work, "vector.png"), args.ppi)
    raster = render("raster", os.path.join(work, "raster.png"), args.ppi)
    if vector.size != raster.size:
        sys.exit(f"sheet sizes differ: {vector.size} vs {raster.size}")

    names = logo_names()
    row_height = LOGO_BLOCK_PT / 72 * args.ppi
    margin = MARGIN_PT / 72 * args.ppi
    width = vector.size[0]

    # If the sheet is not the height the band arithmetic assumes, every slice
    # below would sample the wrong logo and the results would be meaningless.
    expected = 2 * margin + len(names) * row_height
    if abs(expected - vector.size[1]) > row_height / 2:
        sys.exit(
            f"sheet is {vector.size[1]}px tall but the {LOGO_BLOCK_PT}pt band "
            f"layout implies {expected:.0f}px; regression.typ spacing changed"
        )

    radius = BLUR_AT_200_PPI * args.ppi / 200
    blur = ImageFilter.GaussianBlur(radius)
    mask = ImageChops.difference(
        vector.filter(blur), raster.filter(blur)
    ).point(lambda v: 255 if v > PIXEL_THRESHOLD else 0)

    failures = []
    known_differences = []
    worst = 0.0
    for index, name in enumerate(names):
        top = int(margin + index * row_height)
        bottom = min(int(margin + (index + 1) * row_height), vector.size[1])
        damaged = mask.crop((0, top, width, bottom)).histogram()[255]
        ink = sum(raster.crop((0, top, width, bottom)).histogram()[:128])
        ratio = damaged / ink if ink else 0.0
        limit = KNOWN_SOURCE_DIFFERENCES.get(name)
        if limit is not None:
            if ratio > limit:
                failures.append((name, damaged, ink, ratio))
            else:
                known_differences.append((name, ratio))
            continue
        worst = max(worst, ratio)
        if ratio > AREA_THRESHOLD:
            failures.append((name, damaged, ink, ratio))

    checked = len(names) - len(known_differences)
    print(f"Compared {len(names)} logos at {args.ppi} ppi (blur radius {radius:.1f}px).")
    print(f"Worst of the {checked} strictly-checked logos differs from its "
          f"reference PNG over {worst:.2%} of its ink.")
    if known_differences:
        print("\nKnown PDF/PNG source differences (not a conversion error):")
        for name, ratio in known_differences:
            print(f"  {name}: {ratio:.1%} of ink")

    if failures:
        print(f"\n{len(failures)} logo(s) over the {AREA_THRESHOLD:.0%} threshold:")
        for name, damaged, ink, ratio in failures:
            print(f"  {name}: {damaged} damaged / {ink} ink px ({ratio:.1%})")
        mask.save(os.path.join(work, "diff.png"))
        print(f"\nSheets and diff mask in {work}")
        return 1

    print(f"\nEvery strictly-checked logo matches its reference PNG within "
          f"{AREA_THRESHOLD:.0%}.")
    if args.keep:
        mask.save(os.path.join(work, "diff.png"))
        print(f"Sheets and diff mask in {work}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
