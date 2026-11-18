"""Base station reference (option B, lit plan table), drawn with the reference kit."""
import json
import sys

from PIL import Image, ImageDraw

sys.argv = ["x", "/home/claude/starportal", "/home/claude/work/ref/base"]
import refkit as K
from refkit import C, W, H, font, text, steel_plate, key, draw_icon, lamp, recess, vgrad, noise_overlay

OUT = sys.argv[2]

BASE = {
    "base_levels": (408, 300, 64, 240),
    "base_dig": (408, 552, 64, 88),
    "base_table": (484, 96, 1040, 768),
    "base_glass": (508, 120, 992, 720),
    "base_console_modes": (668, 908, 120, 144),
    "base_console_tray": (800, 908, 692, 144),
    "room_panel": (1536, 92, 368, 772),
}
CELL = 80
GRID = (12, 8)
GX, GY = 508 + (992 - CELL * 12) // 2, 120 + (720 - CELL * 8) // 2

ROOMS = [
    ("CONTROL", "base", 0, 0, 3, 2, "on", (1, 2), 5),
    ("GATE ROOM", "gate", 4, 0, 4, 3, "on", (2, 4), 10),
    ("DIESEL PLANT", "power", 9, 0, 3, 2, "on", (0, 0), -30),
    ("RESEARCH LAB", "lab", 0, 4, 3, 3, "on", (2, 4), 5),
    ("WORKSHOP", "base", 4, 5, 3, 2, "on", (2, 2), 5),
    ("QUARTERS", "base", 8, 4, 2, 3, "off", (0, 0), 0),
    ("SITE", "plus", 10, 4, 2, 2, "site", (0, 0), 0),
]
CORRIDORS = [(0, 3, 12, 1), (3, 0, 1, 3), (8, 0, 1, 4), (3, 4, 1, 3), (7, 4, 1, 3)]


def cell_rect(x, y, w, h, inset=4):
    return (GX + x * CELL + inset, GY + y * CELL + inset, GX + (x + w) * CELL - inset, GY + (y + h) * CELL - inset)


def table(im):
    x, y, w, h = BASE["base_table"]
    steel_plate(im, (x, y, w, h), seed=91)
    gx, gy, gw, gh = BASE["base_glass"]
    glass = vgrad((gw, gh), (16, 22, 22), (10, 14, 14))
    im.paste(glass, (gx, gy))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((gx, gy, gx + gw - 1, gy + gh - 1), 6, outline=K.C["edge"], width=4)
    for i in range(GRID[0] + 1):
        d.line((GX + i * CELL, GY, GX + i * CELL, GY + GRID[1] * CELL), fill=(26, 36, 36))
    for j in range(GRID[1] + 1):
        d.line((GX, GY + j * CELL, GX + GRID[0] * CELL, GY + j * CELL), fill=(26, 36, 36))


def plan(im, mode):
    d = ImageDraw.Draw(im)
    for cx, cy, cw, ch in CORRIDORS:
        d.rectangle(cell_rect(cx, cy, cw, ch, 8), fill=(38, 46, 44))
    for name, ic, x, y, w, h, st, staff, mw in ROOMS:
        r = cell_rect(x, y, w, h)
        if mode == "POWER":
            fill = (60, 52, 26) if st == "on" else (28, 30, 32)
            edge = C["amber"] if st == "on" else (90, 92, 86)
        else:
            fill = {"on": (38, 64, 54), "off": (28, 32, 34), "site": (52, 46, 26)}[st]
            edge = C["green"] if st == "on" else ((180, 140, 60) if st == "site" else (90, 92, 86))
        d.rectangle(r, fill=fill, outline=edge, width=2)
        if st == "on":
            K.glow(im, ((r[0] + r[2]) // 2, (r[1] + r[3]) // 2), 56, edge, 0.10)
            d = ImageDraw.Draw(im)
        if name == "GATE ROOM":
            cx, cy = (r[0] + r[2]) // 2, (r[1] + r[3]) // 2 + 8
            d.ellipse((cx - 56, cy - 56, cx + 56, cy + 56), outline=(150, 156, 150), width=10)
        draw_icon(d, ic, (r[0] + 24, r[1] + 24), 24, C["text"])
        text(d, (r[0] + 44, r[1] + 24), name, font(K.F_LABEL, 18), C["text"], "lm", 2)
        if mode == "POWER" and mw:
            text(d, (r[2] - 10, r[1] + 24), (f"+{-mw}" if mw < 0 else f"{mw}") + " MW", font(K.F_MONO_B, 15),
                 C["green"] if mw < 0 else C["amber"], "rm")
        elif st == "on" and mode != "POWER":
            lamp(im, (r[2] - 18, r[1] + 22), 6, True, C["green"])
            d = ImageDraw.Draw(im)
        if st == "site":
            d.rectangle((r[0] + 14, r[3] - 26, r[2] - 14, r[3] - 16), fill=(20, 20, 18), outline=C["edge"])
            d.rectangle((r[0] + 15, r[3] - 25, r[0] + 15 + int((r[2] - r[0] - 30) * 0.4), r[3] - 17), fill=C["amber"])
            text(d, (r[0] + 14, r[3] - 40), "QUARTERS · 9H", font(K.F_MONO, 13), C["dim"], "lm")
        if mode != "POWER":
            for k in range(staff[1]):
                px, py = r[0] + 24 + k * 30, r[3] - 22
                if k < staff[0]:
                    d.ellipse((px - 11, py - 11, px + 11, py + 11), fill=C["text"], outline=C["edge"], width=2)
                    text(d, (px, py), "S" if "LAB" in name else "E", font(K.F_LABEL, 14), C["ink"], "mm")
                else:
                    d.ellipse((px - 11, py - 11, px + 11, py + 11), outline=C["dim"], width=2)
        if name == "RESEARCH LAB":
            d.rectangle((r[0] - 3, r[1] - 3, r[2] + 3, r[3] + 3), outline=C["amber"], width=4)
    if mode == "BUILD":
        g = cell_rect(10, 6, 2, 2, 2)
        d.rectangle(g, outline=C["green"], width=3)
        for k in range(g[0], g[2], 14):
            d.line((k, g[1], k, g[1] + 6), fill=C["green"], width=2)
        text(d, ((g[0] + g[2]) // 2, (g[1] + g[3]) // 2), "QUARTERS", font(K.F_LABEL, 16), C["green"], "mm", 2)
    if mode == "STAFF":
        r = cell_rect(0, 4, 3, 3)
        px, py = r[0] + 84, r[3] - 22
        d.ellipse((px - 11, py - 11, px + 11, py + 11), outline=C["amber"], width=3)


def levels(im):
    x, y, w, h = BASE["base_levels"]
    for i, lv in enumerate(("L1", "L2", "L3", "L4")):
        st = "amber" if i == 0 else ("off" if i > 1 else "steel")
        key(im, (x + 4, y + i * 60, 56, 52), lv, st, font_size=22)
    dx, dy, dw, dh = BASE["base_dig"]
    key(im, (dx + 4, dy, 56, dh), "DIG", "steel", "down", font_size=16)
    d = ImageDraw.Draw(im)
    text(d, (dx + dw // 2, dy + dh + 14), "L3 · $2.5M", font(K.F_MONO, 13), C["dim"], "mm")


def console(im, mode):
    x, y, w, h = K.LAYOUT["station_console"]
    steel_plate(im, (x, y, w, h), seed=33)
    mx, my, mw, mh = BASE["base_console_modes"]
    for i, (lab) in enumerate(("BUILD", "POWER", "STAFF", "SECURITY")):
        key(im, (mx, my + i * 37, mw, 32), lab, "lit" if lab == mode else "steel", font_size=16)
    tx, ty, tw, th = BASE["base_console_tray"]
    recess(im, (tx, ty, tw, th))
    d = ImageDraw.Draw(im)
    if mode == "BUILD":
        items = [("QUARTERS", "$150k", "2×3", "base"), ("RESEARCH LAB", "$400k", "3×3", "lab"), ("VAULT", "$300k", "2×2", "base"),
                 ("SECURITY POST", "$200k", "2×2", "threat"), ("CAP. BANK", "$600k", "2×2", "charge"), ("CORRIDOR", "$10k", "1×1", "plus")]
        for i, (n, c, sz, ic) in enumerate(items):
            cx = tx + 8 + i * 114
            recess(im, (cx, ty + 8, 106, th - 16), fill=(40, 41, 36))
            dd = ImageDraw.Draw(im)
            draw_icon(dd, ic, (cx + 53, ty + 42), 32, C["amber"] if i == 0 else C["text"])
            text(dd, (cx + 53, ty + 76), n, font(K.F_LABEL, 15), C["text"], "mm", 1)
            text(dd, (cx + 53, ty + 98), c, font(K.F_MONO_B, 15), C["amber"], "mm")
            text(dd, (cx + 53, ty + 118), sz, font(K.F_MONO, 13), C["dim"], "mm")
            if i == 0:
                dd.rectangle((cx, ty + 8, cx + 105, ty + th - 9), outline=C["amber"], width=3)
    elif mode == "POWER":
        text(d, (tx + 16, ty + 22), "SUPPLY 30 MW · USED 25 · CHARGING 5", font(K.F_LABEL, 18), C["text"], "lm", 2)
        rooms = [("CONTROL", True), ("GATE", True), ("LAB", True), ("WORKSHOP", True), ("QUARTERS", False), ("BANK", True)]
        for i, (n, on) in enumerate(rooms):
            bx = tx + 16 + i * 112
            d.rounded_rectangle((bx, ty + 44, bx + 96, ty + 128), 6, fill=(22, 23, 20), outline=C["edge"], width=2)
            d.rounded_rectangle((bx + 36, ty + 52, bx + 60, ty + 104), 6, fill=(10, 10, 9))
            key(im, (bx + 30, ty + (54 if on else 78), 36, 24), "", "amber" if on else "steel")
            d = ImageDraw.Draw(im)
            text(d, (bx + 48, ty + 118), n, font(K.F_LABEL, 14), C["text"] if on else C["dim"], "mm", 1)
    elif mode == "STAFF":
        people = [("FERREIRA", "S", (150, 106, 72), "LAB"), ("OKOYE", "S", (94, 106, 122), "LAB"), ("BRANDT", "E", (110, 122, 94), "WORKSHOP"),
                  ("SATO", "E", (154, 118, 86), "WORKSHOP"), ("HALE", "A", (120, 100, 90), "CONTROL"), ("LINDQVIST", "S", (140, 120, 100), "—")]
        for i, (n, role, col, room) in enumerate(people):
            px = tx + 10 + i * 112
            sel = i == 5
            d.rectangle((px, ty + 10, px + 104, ty + th - 10), fill=(40, 41, 36), outline=C["amber"] if sel else C["edge"], width=3 if sel else 2)
            d.rectangle((px + 26, ty + 18, px + 78, ty + 70), fill=col, outline=C["edge"], width=2)
            d.ellipse((px + 40, ty + 24, px + 64, ty + 48), fill=(214, 190, 160))
            text(d, (px + 52, ty + 88), n, font(K.F_LABEL, 15), C["text"], "mm", 1)
            text(d, (px + 52, ty + 112), f"{role} · {room}", font(K.F_MONO, 13), C["amber"] if sel else C["dim"], "mm")


def room_panel(im):
    x, y, w, h = BASE["room_panel"]
    steel_plate(im, (x, y, w, h), seed=12)
    d = ImageDraw.Draw(im)
    draw_icon(d, "lab", (x + 28, y + 28), 24, C["amber"])
    text(d, (x + 50, y + 28), "RESEARCH LAB", font(K.F_LABEL, 24), C["text"], "lm", 3)
    yy = y + 64
    text(d, (x + 18, yy), "STUDY THE LOOM", font(K.F_LABEL, 20), C["text"], "la", 2)
    text(d, (x + w - 18, yy), "62%", font(K.F_MONO_B, 18), C["amber"], "ra")
    d.rectangle((x + 18, yy + 32, x + w - 18, yy + 42), fill=(20, 21, 18), outline=C["edge"])
    d.rectangle((x + 19, yy + 33, x + 19 + int((w - 38) * 0.62), yy + 41), fill=C["amber"])
    yy += 70
    text(d, (x + 18, yy + 18), "POWER", font(K.F_LABEL_M, 16), C["dim"], "lm", 2)
    key(im, (x + w - 150, yy, 132, 40), "ON · 5 MW", "lit", font_size=16)
    yy += 60
    text(d, (x + 18, yy), "STAFF 2/4 · SPEED 67%", font(K.F_LABEL_M, 16), C["dim"], "la", 2)
    yy += 28
    for i in range(4):
        fx = x + 18 + i * 84
        if i < 2:
            d.rectangle((fx, yy, fx + 74, yy + 74), fill=[(150, 106, 72), (94, 106, 122)][i], outline=C["edge"], width=2)
            d.ellipse((fx + 24, yy + 10, fx + 50, yy + 36), fill=(214, 190, 160))
            d.pieslice((fx + 12, yy + 40, fx + 62, yy + 90), 180, 360, fill=(220, 218, 206))
        else:
            d.rectangle((fx, yy, fx + 74, yy + 74), outline=C["dim"], width=2)
            draw_icon(d, "plus", (fx + 37, yy + 37), 26, C["dim"])
    yy += 96
    text(d, (x + 18, yy), "INSTALLED", font(K.F_LABEL_M, 16), C["dim"], "la", 2)
    yy += 28
    key(im, (x + 18, yy, 160, 48), "+ INSTALL", "steel", font_size=18)
    key(im, (x + w - 178, y + h - 64, 160, 48), "DEMOLISH", "steel", font_size=18)


def compose(mode):
    im = Image.new("RGB", (W, H), (10, 11, 10))
    im.paste(noise_overlay(vgrad((W, H), (50, 52, 45), (28, 29, 25)), 10, 3), (0, 0))
    table(im)
    plan(im, mode)
    levels(im)
    K.top_bar(im)
    K.wire(im, [
        ("lab", "LAB IDLE", "Research Lab · 2 scientists", C["amber"], ["arrow"]),
        ("candidate", "CANDIDATE", "Engineer · skill 3", C["green"], ["check", "cross"]),
        ("base", "ROOM FINISHED", "Workshop", C["green"], ["check"]),
    ])
    K.bottom_bar(im, "base", False)
    console(im, mode)
    room_panel(im)
    if mode == "STAFF":
        d = ImageDraw.Draw(im)
        r = cell_rect(0, 4, 3, 3)
        sx, sy, ex, ey = 1422, 914, r[0] + 84, r[3] - 22
        n = 24
        for k in range(0, n, 2):
            a, b = k / n, (k + 1) / n
            d.line((sx + (ex - sx) * a, sy + (ey - sy) * a, sx + (ex - sx) * b, sy + (ey - sy) * b), fill=C["amber"], width=3)
    im.save(f"{OUT}/ref_base_{mode.lower()}.png")


def overlay():
    im = Image.new("RGB", (W, H), (20, 22, 24))
    d = ImageDraw.Draw(im)
    regions = dict(K.LAYOUT)
    regions.update(BASE)
    for k in ["top_bar", "wire", "bottom_bar", "station_keys", "station_console", "gate_monitor"] + list(BASE):
        x, y, w, h = regions[k]
        d.rectangle((x, y, x + w - 1, y + h - 1), outline=(232, 163, 61), width=2)
        text(d, (x + 6, y + 4), f"{k}  {x},{y}  {w}×{h}", font(K.F_MONO, 13), (232, 228, 208))
    d.rectangle((GX, GY, GX + 12 * CELL, GY + 8 * CELL), outline=(127, 214, 138), width=1)
    text(d, (GX + 6, GY + 6), f"plan grid origin {GX},{GY} · cell {CELL} px", font(K.F_MONO, 13), (127, 214, 138))
    im.save(f"{OUT}/overlay_base.png")


for m in ("BUILD", "POWER", "STAFF"):
    compose(m)
overlay()
lay = json.load(open("/home/claude/starportal/docs/reference/layout.json"))
for k, v in BASE.items():
    lay[k] = {"x": v[0], "y": v[1], "w": v[2], "h": v[3]}
lay["base_plan_grid"] = {"x": GX, "y": GY, "w": CELL * 12, "h": CELL * 8, "cell": CELL}
json.dump(lay, open(f"{OUT}/layout.json", "w"), indent=1)
print("ok", GX, GY)
