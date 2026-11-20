# Staff portraits and 2D-HD sprites

Owner decisions, 2026-11-20. Every member of staff gets a procedural pixel-art portrait and a matching full-body sprite, generated from one seeded appearance record. No hand-drawn art yet; hand-drawn part sheets can replace the code-drawn parts later without changing the record.

## Style (keep)

- Pixel art, late-90s military science fiction. Muted palette, dark outlines, readable at a glance, not cartoonish.
- Solid colour blocks with selective shading and small highlights. Dithering only for shadow and texture (stubble), never as a general fill; the background is a smooth dark navy gradient.
- Five-step colour ramps per material (outline, shadow, mid, light, highlight). Shadows shift cool, lights shift warm. Outlines never lighter than 26 % lightness (pale skin must not get a yellow edge).
- Light from the upper left.
- Rendered at native size, shown with nearest-neighbour scaling only, at whole multiples.

## Sizes

| Asset | Native | Typical display |
|---|---|---|
| Portrait | 96×96 | 288×288 (3×) in the Office and dialogue; 96×96 or 192×192 on cards |
| Full body | 64×128, transparent | Sprite3D in the 3D stations (2D-HD) |

## The appearance record

Generated once at hire from the staff member's seed, stored with the staff member (plain data in the sim, no images). The portrait and the sprite are drawn from it by the UI and cached.

- **Sex**, **age** (young adult, adult, older), **skin** (six tones), **hair colour** (nine plus three greys; older staff often grey).
- **Head**: round, oval, square, long; **jaw**: narrow, broad, angular.
- **Eyes**: small, round, narrow; **brows**: straight, angled, thick; **nose**: short, long, wide; **mouth**: thin, wide, neutral.
- **Facial hair**: clean, stubble, moustache, beard (men; young staff no full beard).
- **Hair**: military cut, buzz, side part, messy, curly, receding, bald, long, ponytail, bun. Hair is its own layer (back and front), independent of the face.
- **Accessory**: none, glasses, eye patch, scar.
- **Uniform variant** by field:
  - Military: standard, officer, expedition, casual, command.
  - Science: lab coat, shirt and tie, overalls, casual.
  - Engineering: coverall, high-visibility vest, work jacket, casual.
  - Office: suit, shirt and tie, sweater, blazer.
  - Medicine: scrubs (stethoscope), lab coat, field fatigues (red-cross patch).

Each field keeps an accent colour so a squad reads at a glance: Military red patch, Science blue, Engineering orange, Office brass, Medicine pale badge.

Aliens (Allied tier) are out of scope here; they get their own part sets later.

## Reference

- Prototype generator: `tools/portraits/pixel_portraits.py`, `tools/portraits/pixel_bodies.py` (Python, PIL, numpy). The Godot version must reproduce its look, not its exact pixels.
- Reference sheets: `docs/reference/portraits_sheet.png` (20 portraits at 3×, columns Military, Office, Science, Engineering, Medicine) and `docs/reference/bodies_sheet.png` (portrait and full body side by side).

## Known gaps in the prototype

- Shoulders read as a flat slab: round them.
- Hair tops read like caps: add a few strand clusters and an irregular silhouette.
- Faces are frontal; a slight three-quarter turn is wanted later.
- Full bodies are thin and stiff: broaden the build, add sex and build variation, and give them frames (idle 2, walk 4; front, back and side, side mirrored).
