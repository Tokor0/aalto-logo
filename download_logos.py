#!/usr/bin/env python3
"""Download Aalto logo assets from aaltologo.fi.

The site serves each logo both as a PNG and as a vector PDF. Neither is
shipped: the PDFs in sources/pdf/ are the input to build_vectors.py, which
turns them into the Typst curve data in logos/, and the PNGs in sources/png/
are the reference tests/compare_render.py diffs that curve data against.
"""
import argparse
import json
import os
import time
import urllib.request

BASE_URL = "https://aaltologo.fi"
ROOT = os.path.dirname(os.path.abspath(__file__))
PNG_DIR = os.path.join(ROOT, "sources", "png")
PDF_DIR = os.path.join(ROOT, "sources", "pdf")

UNITS = [
    "WtL2",  # Aalto University
    "qBQb",  # School of Arts, Design and Architecture
    "RKfg",  # School of Electrical Engineering
    "6fcM",  # School of Science
    "9s9B",  # School of Engineering
    "VR7S",  # School of Chemical Engineering
    "bD_j",  # School of Business
]

SIZE_LABELS = {"13": "small", "21": "large"}
MARK_LABELS = {"1": "question", "2": "quote", "3": "exclamation"}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


def fetch_json(unit_id):
    url = f"{BASE_URL}/files_{unit_id}.json"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def download_file(file_name, fmt, output_path):
    url = f"{BASE_URL}/dl.php?type={fmt}&file={file_name}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    if not data:
        raise RuntimeError(f"empty response for {file_name} ({fmt})")
    with open(output_path, "wb") as f:
        f.write(data)


def unit_name(folder_name):
    """"Aalto_ELEC" -> "ELEC"; "Aalto-yliopisto" -> "Aalto"."""
    if folder_name == "Aalto-yliopisto":
        return "Aalto"
    return folder_name.removeprefix("Aalto_")


def canonical_name(entry):
    """Canonical stem, e.g. "ELEC_en_small_black_question".

    Returns None for entries we do not ship.
    """
    mark_num = entry["Filename"].rsplit("_", 1)[-1]
    if mark_num not in MARK_LABELS:
        return None
    size_label = SIZE_LABELS.get(entry["Size"])
    if size_label is None:
        return None

    unit = unit_name(entry["FolderName"])
    language = entry["Language"].lower()

    # The small single-language Aalto University logo was decommissioned; the
    # site still lists a few stragglers. lib.typ rejects this combination too.
    if unit == "Aalto" and size_label == "small" and language != "fi-se-en":
        return None

    return "_".join(
        (unit, language, size_label, entry["Style"].lower(), MARK_LABELS[mark_num])
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        choices=("png", "pdf", "both"),
        default="both",
        help="which asset format(s) to download (default: both)",
    )
    args = parser.parse_args()

    formats = ("png", "pdf") if args.format == "both" else (args.format,)
    out_dirs = {"png": PNG_DIR, "pdf": PDF_DIR}
    for fmt in formats:
        os.makedirs(out_dirs[fmt], exist_ok=True)

    total = 0
    skipped = 0

    for unit_id in UNITS:
        print(f"Fetching index for unit {unit_id}...")
        entries = fetch_json(unit_id)

        for entry in entries:
            fmt = entry["Format"]
            if fmt not in formats:
                continue

            stem = canonical_name(entry)
            if stem is None:
                continue

            output_name = f"{stem}.{fmt}"
            output_path = os.path.join(out_dirs[fmt], output_name)

            if os.path.exists(output_path):
                skipped += 1
                continue

            print(f"  Downloading: {output_name}")
            download_file(entry["File"], fmt, output_path)
            total += 1
            time.sleep(0.2)  # be polite

    print(f"\nDone. Downloaded {total} files, skipped {skipped} existing.")


if __name__ == "__main__":
    main()
