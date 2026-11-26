#!/usr/bin/env python3
"""Writes comparison images for the reference capture (interface-reference.md section 6).

Usage: python3 tools/reference/compare.py <capture_dir> <reference_dir>

For each state (gate_idle, gate_open, other_station) with <capture_dir>/<state>.png:
- <state>_compare.png: a 2 x 2 sheet at half size: capture | reference on top,
  capture under the overlay (50%) | per-pixel difference below.
- <state>_overlay.png: the capture under the overlay at full size, for checking
  regions against layout.json pixel by pixel.
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

STATES = (
    "gate_idle", "gate_open", "other_station", "base_build", "base_power", "base_staff", "lab"
)
# The overlay drawn for each state (the Base states share one).
OVERLAYS = {"base_build": "base", "base_power": "base", "base_staff": "base"}
SIZE = (1920, 1080)


def under_overlay(capture, overlay):
    """The capture with the overlay's lines and labels on top at 50%."""
    mask = overlay.convert("L").point(lambda v: 128 if v > 60 else 0)
    return Image.composite(overlay, capture, mask)


def label(im, text):
    draw = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    draw.rectangle((0, 0, 14 * len(text) + 16, 34), fill=(0, 0, 0))
    draw.text((8, 5), text, fill=(255, 220, 120), font=font)
    return im


def sheet(state, capture, reference, overlay):
    half = (SIZE[0] // 2, SIZE[1] // 2)
    tiles = [
        ("capture", capture),
        ("reference", reference),
        ("capture + overlay", under_overlay(capture, overlay)),
        ("difference", ImageChops.difference(capture, reference)),
    ]
    out = Image.new("RGB", SIZE)
    for i, (name, im) in enumerate(tiles):
        tile = label(im.resize(half, Image.LANCZOS), f"{state}: {name}")
        out.paste(tile, ((i % 2) * half[0], (i // 2) * half[1]))
    return out


def load(path):
    return Image.open(path).convert("RGB").resize(SIZE, Image.LANCZOS)


def main(capture_dir, reference_dir):
    cap_dir, ref_dir = Path(capture_dir), Path(reference_dir)
    written = 0
    for state in STATES:
        cap_path = cap_dir / f"{state}.png"
        if not cap_path.exists():
            print(f"compare: missing {cap_path}", file=sys.stderr)
            continue
        capture = load(cap_path)
        reference = load(ref_dir / f"ref_{state}.png")
        overlay = load(ref_dir / f"overlay_{OVERLAYS.get(state, state)}.png")
        sheet(state, capture, reference, overlay).save(cap_dir / f"{state}_compare.png")
        under_overlay(capture, overlay).save(cap_dir / f"{state}_overlay.png")
        print(f"compare: wrote {cap_dir / (state + '_compare.png')}")
        written += 1
    return 0 if written == len(STATES) else 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
