#!/usr/bin/env python3
"""Turn the vector PDFs in sources/pdf/ into native Typst curve data.

Each logo becomes logos/<unit>_<lang>_<size>_<mark>.typ, holding an
evaluable Typst dictionary of curve components with coordinates expressed as
ratios of the artwork's bounding box. lib.typ reads one of these on demand and
draws it with curve(), so the logo is resolution-independent and takes any
Typst colour.

The colour axis is dropped deliberately: the black and white artwork is
geometrically identical (verified per logo by --check-white, on by default),
so lib.typ recolours a single set of outlines at compile time.

Pipeline: PDF --(mutool)--> SVG --(parse/flatten/normalise)--> Typst data.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.abspath(__file__))
PDF_DIR = os.path.join(ROOT, "sources", "pdf")
OUT_DIR = os.path.join(ROOT, "logos")

SVG_NS = "http://www.w3.org/2000/svg"
NUMBER_RE = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
TOKEN_RE = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|" + NUMBER_RE.pattern)
MATRIX_RE = re.compile(r"matrix\(([^)]*)\)")

# Coordinates are emitted as percentages with this many decimals. 3 decimals of
# a percent is ~0.0024pt on a 243pt-wide logo -- far below any output device.
PRECISION = 3

# Black and white artwork is accepted as identical below this deviation, in
# percent of the bounding box. 0.05%% is ~0.1pt on a 200pt-wide logo.
WHITE_TOLERANCE = 0.05


# Logos where Aalto's own black and white source files disagree. For
# ELEC_se_small_quote the A-mark sits 1.35pt higher relative to the wordmark in
# the white artwork than in the black; their published PNGs differ the same way
# (825x168 black vs 825x163 white), so this is an upstream inconsistency rather
# than a conversion error. The black geometry is used for every colour.
KNOWN_COLOUR_VARIANTS = {
    "ELEC_se_small_quote": "A-mark placed 1.35pt apart in the source artwork",
}


class BuildError(Exception):
    pass


def tag(elem):
    """Local tag name, namespace stripped."""
    return elem.tag.rsplit("}", 1)[-1]


def parse_matrix(transform):
    """SVG matrix(a,b,c,d,e,f) -> tuple. Only matrix() is emitted by mutool."""
    if not transform:
        return (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    m = MATRIX_RE.fullmatch(transform.strip())
    if not m:
        raise BuildError(f"unsupported transform {transform!r}")
    values = [float(v) for v in NUMBER_RE.findall(m.group(1))]
    if len(values) != 6:
        raise BuildError(f"malformed matrix {transform!r}")
    return tuple(values)


def compose(outer, inner):
    """Matrix product, outer applied after inner."""
    a1, b1, c1, d1, e1, f1 = outer
    a2, b2, c2, d2, e2, f2 = inner
    return (
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1,
    )


def apply(matrix, x, y):
    a, b, c, d, e, f = matrix
    return (a * x + c * y + e, b * x + d * y + f)


def parse_path(d):
    """SVG path data -> list of absolute subpath segments in user space.

    Returns a list of ("move"|"line"|"cubic"|"close", points...) tuples.
    Only the subset a PDF can produce is accepted; anything else is an error
    rather than being silently dropped.
    """
    tokens = TOKEN_RE.findall(d)
    segments = []
    i = 0
    cx = cy = 0.0  # current point
    sx = sy = 0.0  # start of current subpath
    command = None

    def number():
        nonlocal i
        if i >= len(tokens):
            raise BuildError(f"path ended mid-command in {d[:60]!r}")
        value = tokens[i]
        if not NUMBER_RE.fullmatch(value):
            raise BuildError(f"expected number, got {value!r} in {d[:60]!r}")
        i += 1
        return float(value)

    while i < len(tokens):
        token = tokens[i]
        if NUMBER_RE.fullmatch(token):
            if command is None:
                raise BuildError(f"path starts with a number: {d[:60]!r}")
            # Implicit repetition: a moveto repeats as lineto, others as self.
            if command == "M":
                command = "L"
            elif command == "m":
                command = "l"
        else:
            command = token
            i += 1
            if command in "Zz":
                segments.append(("close",))
                cx, cy = sx, sy
                continue

        rel = command.islower()
        base_x, base_y = (cx, cy) if rel else (0.0, 0.0)
        upper = command.upper()

        if upper == "M":
            cx, cy = base_x + number(), base_y + number()
            sx, sy = cx, cy
            segments.append(("move", (cx, cy)))
        elif upper == "L":
            cx, cy = base_x + number(), base_y + number()
            segments.append(("line", (cx, cy)))
        elif upper == "H":
            cx = base_x + number()
            segments.append(("line", (cx, cy)))
        elif upper == "V":
            cy = base_y + number()
            segments.append(("line", (cx, cy)))
        elif upper == "C":
            c1 = (base_x + number(), base_y + number())
            c2 = (base_x + number(), base_y + number())
            cx, cy = base_x + number(), base_y + number()
            segments.append(("cubic", c1, c2, (cx, cy)))
        else:
            raise BuildError(
                f"unsupported path command {command!r}; PDF-derived paths "
                f"should only use M/L/H/V/C/Z"
            )

    return segments


def is_full_box_rect(d, matrix, width, height, tol=1e-3):
    """True if a clip path is the whole page, i.e. has no effect."""
    try:
        segments = parse_path(d)
    except BuildError:
        return False
    xs, ys = [], []
    for seg in segments:
        for point in seg[1:]:
            px, py = apply(matrix, *point)
            xs.append(px)
            ys.append(py)
    if not xs or any(s[0] == "cubic" for s in segments):
        return False
    return (
        abs(min(xs)) < tol
        and abs(min(ys)) < tol
        and abs(max(xs) - width) < tol
        and abs(max(ys) - height) < tol
    )


def collect_paths(svg_path):
    """Parse an SVG into (width, height, [(fill, [segments])]) in viewBox space."""
    tree = ET.parse(svg_path)
    root = tree.getroot()

    view_box = root.get("viewBox")
    if not view_box:
        raise BuildError(f"{svg_path}: no viewBox")
    vx, vy, width, height = [float(v) for v in NUMBER_RE.findall(view_box)]
    if abs(vx) > 1e-6 or abs(vy) > 1e-6:
        raise BuildError(f"{svg_path}: viewBox origin is not (0,0)")

    # Validate that every clip path is a no-op before ignoring clipping.
    clips = {}
    for defs in root.iter(f"{{{SVG_NS}}}defs"):
        for clip in defs.iter(f"{{{SVG_NS}}}clipPath"):
            ok = all(
                is_full_box_rect(
                    child.get("d", ""), parse_matrix(child.get("transform")), width, height
                )
                for child in clip
                if tag(child) == "path"
            )
            clips[clip.get("id")] = ok

    results = []

    def walk(elem, matrix):
        for child in elem:
            name = tag(child)
            if name == "defs":
                continue
            child_matrix = compose(matrix, parse_matrix(child.get("transform")))

            clip_ref = child.get("clip-path")
            if clip_ref:
                clip_id = clip_ref.strip()[len("url(#") : -1]
                if not clips.get(clip_id, False):
                    raise BuildError(
                        f"{svg_path}: clip path {clip_id!r} is not a full-page "
                        f"no-op; real clipping is not supported"
                    )

            if name == "path":
                segments = parse_path(child.get("d", ""))
                transformed = [
                    (seg[0], *[apply(child_matrix, *p) for p in seg[1:]])
                    for seg in segments
                ]
                results.append((child.get("fill", "#000000").lower(), transformed))
            elif name in ("g", "svg"):
                walk(child, child_matrix)
            else:
                raise BuildError(f"{svg_path}: unexpected element <{name}>")

    walk(root, (1.0, 0.0, 0.0, 1.0, 0.0, 0.0))
    return width, height, results


def cubic_extrema(p0, p1, p2, p3):
    """Parameters in (0,1) where a cubic Bezier reaches an axis extremum."""
    a = -p0 + 3 * p1 - 3 * p2 + p3
    b = 2 * (p0 - 2 * p1 + p2)
    c = p1 - p0
    roots = []
    if abs(a) < 1e-12:
        if abs(b) > 1e-12:
            roots.append(-c / b)
    else:
        disc = b * b - 4 * a * c
        if disc >= 0:
            root = disc ** 0.5
            roots.extend(((-b + root) / (2 * a), (-b - root) / (2 * a)))
    return [t for t in roots if 0 < t < 1]


def cubic_at(p0, p1, p2, p3, t):
    u = 1 - t
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3


def ink_bounds(paths):
    """Tight bounding box of the drawn artwork.

    The PDF page box carries generous padding around the logo while the
    reference PNGs are cropped to the ink, so the artwork is normalised
    against this box instead. Bezier extrema are solved rather than using the
    control-point hull, which would overestimate the extent.
    """
    xs, ys = [], []
    for _fill, segments in paths:
        current = None
        for seg in segments:
            if seg[0] == "close":
                continue
            if seg[0] == "cubic" and current is not None:
                (c1, c2, end) = seg[1:]
                for axis in (0, 1):
                    values = xs if axis == 0 else ys
                    p0, p1, p2, p3 = current[axis], c1[axis], c2[axis], end[axis]
                    values.append(p0)
                    values.append(p3)
                    for t in cubic_extrema(p0, p1, p2, p3):
                        values.append(cubic_at(p0, p1, p2, p3, t))
                current = end
            else:
                point = seg[-1]
                xs.append(point[0])
                ys.append(point[1])
                current = point
    if not xs:
        raise BuildError("artwork has no drawable geometry")
    return min(xs), min(ys), max(xs), max(ys)


def fmt(value):
    """Compact fixed-point number, trailing zeros stripped."""
    text = f"{value:.{PRECISION}f}".rstrip("0").rstrip(".")
    return "0" if text in ("", "-0") else text


def components(paths, bounds):
    """Flatten every subpath into Typst curve components in ratio coordinates."""
    min_x, min_y, max_x, max_y = bounds
    width = max_x - min_x
    height = max_y - min_y
    out = []
    for _fill, segments in paths:
        for seg in segments:
            points = [
                f"({fmt((x - min_x) / width * 100)}%,{fmt((y - min_y) / height * 100)}%)"
                for x, y in seg[1:]
            ]
            if seg[0] == "move":
                out.append(f"curve.move({points[0]})")
            elif seg[0] == "line":
                out.append(f"curve.line({points[0]})")
            elif seg[0] == "cubic":
                out.append(f"curve.cubic({','.join(points)})")
            else:
                out.append('curve.close(mode:"straight")')
    return out


def geometry_deviation(a, b):
    """Largest coordinate difference between two component lists, in percent.

    Returns None if the two are not even structurally comparable. The black
    and white artwork is drawn from independent PDFs, so their bounding boxes
    can differ in the 4th decimal and flip the last rounded digit of many
    coordinates; comparing numerically with a tolerance distinguishes that
    noise from genuinely different artwork.
    """
    if len(a) != len(b):
        return None
    direct = _deviation_in_order(a, b)
    if direct is not None:
        return direct
    # Some logos draw the same glyphs in a different order between colour
    # variants. For a filled single-colour path that is not a visual
    # difference, so fall back to comparing the components as a multiset.
    return _deviation_in_order(sorted(a), sorted(b))


def _deviation_in_order(a, b):
    worst = 0.0
    for left, right in zip(a, b):
        head_l = left.split("(", 1)[0]
        head_r = right.split("(", 1)[0]
        if head_l != head_r:
            return None
        nums_l = [float(v) for v in re.findall(r"-?[\d.]+(?=%)", left)]
        nums_r = [float(v) for v in re.findall(r"-?[\d.]+(?=%)", right)]
        if len(nums_l) != len(nums_r):
            return None
        for x, y in zip(nums_l, nums_r):
            worst = max(worst, abs(x - y))
    return worst


def pdf_to_svg(pdf_path, work_dir):
    pattern = os.path.join(work_dir, "page%d.svg")
    subprocess.run(
        ["mutool", "convert", "-F", "svg", "-O", "text=path", "-o", pattern, pdf_path],
        check=True,
        capture_output=True,
    )
    produced = sorted(f for f in os.listdir(work_dir) if f.endswith(".svg"))
    if len(produced) != 1:
        raise BuildError(f"{pdf_path}: expected 1 page, got {len(produced)}")
    return os.path.join(work_dir, produced[0])


def render(pdf_path, work_dir):
    svg_path = pdf_to_svg(pdf_path, work_dir)
    _page_width, _page_height, paths = collect_paths(svg_path)
    # Source artwork uses several near-blacks (#000000, #231f20, #1d1d1b) that
    # all recolour to the same thing. What would break recolouring is a
    # knockout, i.e. light and dark ink in one logo -- that is the real check.
    fills = {fill for fill, _ in paths}
    light = {f for f in fills if f == "#ffffff"}
    if light and light != fills:
        raise BuildError(
            f"{pdf_path}: artwork mixes light and dark fills {sorted(fills)}; "
            f"it cannot be recoloured as a single-colour logo"
        )
    bounds = ink_bounds(paths)
    min_x, min_y, max_x, max_y = bounds
    return max_x - min_x, max_y - min_y, components(paths, bounds)


def emit(stem, width, height, comps):
    body = ",\n        ".join(comps)
    return f"""// Generated by build_vectors.py -- do not edit.
// Source: sources/pdf/{stem}.pdf
// Coordinates are ratios of the artwork's bounding box (the page padding in
// the source PDF is cropped away, matching the reference PNGs), so drawing
// this inside a box() of any size scales it exactly.
(
  size: ({fmt(width)}pt, {fmt(height)}pt),
  paths: (
    (
      fill-rule: "non-zero",
      components: (
        {body},
      ),
    ),
  ),
)
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--no-check-white",
        action="store_true",
        help="skip verifying that white artwork matches black geometry",
    )
    parser.add_argument("--only", help="substring filter for a single logo, for spikes")
    args = parser.parse_args()

    if not shutil.which("mutool"):
        sys.exit("mutool not found; run inside `nix develop`")
    if not os.path.isdir(PDF_DIR):
        sys.exit(f"{PDF_DIR} missing; run `python3 download_logos.py --format pdf`")

    black = sorted(f for f in os.listdir(PDF_DIR) if f.endswith("_black_question.pdf")
                   or f.endswith("_black_quote.pdf") or f.endswith("_black_exclamation.pdf"))
    if args.only:
        black = [f for f in black if args.only in f]

    os.makedirs(OUT_DIR, exist_ok=True)
    written = 0
    mismatches = []
    worst_deviation = 0.0
    known_variants = []

    for name in black:
        stem = name[: -len(".pdf")]
        out_stem = stem.replace("_black_", "_")
        with tempfile.TemporaryDirectory() as work_dir:
            width, height, comps = render(os.path.join(PDF_DIR, name), work_dir)

        if not args.no_check_white:
            white_name = name.replace("_black_", "_white_")
            white_path = os.path.join(PDF_DIR, white_name)
            if os.path.exists(white_path):
                with tempfile.TemporaryDirectory() as work_dir:
                    w2, h2, comps2 = render(white_path, work_dir)
                deviation = geometry_deviation(comps, comps2)
                if deviation is not None and deviation <= WHITE_TOLERANCE:
                    worst_deviation = max(worst_deviation, deviation)
                elif out_stem in KNOWN_COLOUR_VARIANTS:
                    known_variants.append(
                        f"{out_stem}: {KNOWN_COLOUR_VARIANTS[out_stem]}"
                    )
                elif deviation is None:
                    mismatches.append(f"{out_stem} (different path structure)")
                else:
                    mismatches.append(f"{out_stem} (max deviation {deviation:.4f}%)")
            else:
                mismatches.append(f"{out_stem} (no white variant)")

        out_path = os.path.join(OUT_DIR, out_stem + ".typ")
        with open(out_path, "w") as f:
            f.write(emit(stem, width, height, comps))
        written += 1
        print(f"  {out_stem}.typ  ({len(comps)} components)")

    print(f"\nWrote {written} logos to logos/.")
    if known_variants:
        print(
            "\nKnown upstream colour inconsistencies (black geometry used for all "
            "colours):\n  " + "\n  ".join(known_variants)
        )
    if mismatches:
        print(
            f"\nWARNING: {len(mismatches)} logo(s) where the white artwork is NOT\n"
            "geometrically identical to the black. Recolouring is unsafe for these:\n  "
            + "\n  ".join(mismatches)
        )
        return 1
    if not args.no_check_white:
        print(
            f"White artwork matches black geometry for every logo "
            f"(max deviation {worst_deviation:.4f}%, tolerance {WHITE_TOLERANCE}%); "
            f"recolouring is safe."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
