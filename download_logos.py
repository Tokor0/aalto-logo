#!/usr/bin/env python3
import urllib.request
import json
import os
import time

BASE_URL = "https://aaltologo.fi"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "logos")

UNITS = [
    "WtL2",  # Aalto University
    "qBQb",  # School of Arts, Design and Architecture
    "RKfg",  # School of Electrical Engineering
    "6fcM",  # School of Science
    "9s9B",  # School of Engineering
    "VR7S",  # School of Chemical Engineering
    "bD_j",  # School of Business
]

SIZE_LABELS = {"13": "Small", "21": "Large"}
MARK_LABELS = {"1": "question", "2": "quote", "3": "exclamation"}

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def fetch_json(unit_id):
    url = f"{BASE_URL}/files_{unit_id}.json"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

def download_file(file_name, output_path):
    url = f"{BASE_URL}/dl.php?type=png&file={file_name}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    with open(output_path, "wb") as f:
        f.write(data)

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    total = 0
    skipped = 0

    for unit_id in UNITS:
        print(f"Fetching index for unit {unit_id}...")
        entries = fetch_json(unit_id)

        for entry in entries:
            if entry["Format"] != "png":
                continue

            filename_field = entry["Filename"]  # e.g. "Aalto_ELEC_EN_13_BLACK_1"
            parts = filename_field.rsplit("_", 1)
            if len(parts) != 2:
                print(f"  Skipping unexpected filename: {filename_field}")
                continue

            mark_num = parts[1]
            if mark_num not in MARK_LABELS:
                print(f"  Skipping unknown mark number '{mark_num}' in {filename_field}")
                continue

            unit_name = entry["FolderName"]
            language = entry["Language"]
            size_code = entry["Size"]
            color = entry["Style"]
            size_label = SIZE_LABELS.get(size_code, size_code)
            mark_label = MARK_LABELS[mark_num]

            output_name = f"{unit_name}_{language}_{size_label}_{color}_{mark_label}.png"
            output_path = os.path.join(OUTPUT_DIR, output_name)

            if os.path.exists(output_path):
                print(f"  Skipping (exists): {output_name}")
                skipped += 1
                continue

            print(f"  Downloading: {output_name}")
            download_file(entry["File"], output_path)
            total += 1
            time.sleep(0.2)  # be polite

    print(f"\nDone. Downloaded {total} files, skipped {skipped} existing.")

if __name__ == "__main__":
    main()
