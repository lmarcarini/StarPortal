"""Lab station reference, drawn with the reference kit."""
import json
import math
import sys

from PIL import Image, ImageDraw

sys.argv = ["x", "/home/claude/starportal", "/home/claude/work/ref/lab"]
import refkit as K
from refkit import C, W, H, font, text, steel_plate, key, draw_icon, lamp, recess, vgrad, noise_overlay

OUT = sys.argv[2]
LAB = {
    "lab_tabs": (408, 96, 1112, 56),
    "lab_board": (408, 160, 1112, 704),
    "lab_panel": (1536, 92, 368, 772),
    "lab_benches": (668, 908, 824, 144),
}
TABS = [("ENGINEERING", "base", False), ("SCIENCE", "lab", True), ("XENOTECH", "gate", False), ("OFFICE", "office", False)]
# id, name, icon, col, row, state(done/avail/active/new), progress
NODES = [
    ("S01", "GATE CALIBRATION", "gate", 0, 1, "done", 1.0),
    ("S02", "HORIZON PHOTOGRAPHY", "camera", 0, 3, "done", 1.0),
    ("S03", "ATMOSPHERIC SAMPLING", "eye", 1, 3, "active", 0.62),
    ("S05", "WORMHOLE STABILISER", "charge", 1, 0, "avail", 0),
    ("S06", "ORIGIN TRACING", "threat", 1, 1, "avail", 0),
    ("S07", "XENOARCHAEOLOGY", "gate", 1, 5, "new", 0),
    ("S09", "XENOLINGUISTICS", "hail", 2, 4, "avail", 0),
    ("S04", "GLYPH FREQUENCY", "list", 2, 2, "queued", 0),
]
EDGES = [("S01", "S05"), ("S01", "S06"), ("S02", "S03")]
COL_X = [470, 790, 1110]
ROW_Y = [200, 300, 400, 500, 600, 700]


def node_pos(n):
    for nid, _, _, c, r, _, _ in NODES:
        if nid == n:
            return COL_X[c], ROW_Y[r]


def tabs(im):
    x, y, w, h = LAB["lab_tabs"]
    for i, (n, ic, on) in enumerate(TABS):
        kx = x + i * 222
        key(im, (kx, y + 4, 212, 48), "", "amber" if on else "steel")
        d = ImageDraw.Draw(im)
        col = (26, 20, 8) if on else C["text"]
        draw_icon(d, ic, (kx + 30, y + 28), 24, col)
        text(d, (kx + 52, y + 29), n, font(K.F_LABEL, 20), col, "lm", 2)
        if n == "XENOTECH":
            lamp(im, (kx + 194, y + 16), 6, True, C["amber"])


def board(im):
    x, y, w, h = LAB["lab_board"]
    steel_plate(im, (x, y, w, h), seed=93)
    gx, gy, gw, gh = x + 20, y + 20, w - 40, h - 40
    im.paste(vgrad((gw, gh), (22, 30, 26), (14, 18, 16)), (gx, gy))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((gx, gy, gx + gw - 1, gy + gh - 1), 6, outline=C["edge"], width=4)
    for a, b in EDGES:
        ax, ay = node_pos(a)
        bx, by = node_pos(b)
        mid = (ax + 260 + bx) / 2
        d.line((ax + 260, ay + 34, mid, ay + 34, mid, by + 34, bx, by + 34), fill=(110, 116, 100), width=3)
    for nid, name, ic, c, r, st, prog in NODES:
        nx, ny = COL_X[c], ROW_Y[r]
        rect = (nx, ny, nx + 260, ny + 68)
        fill = {"done": (36, 52, 42), "avail": (44, 45, 40), "active": (60, 50, 26), "queued": (44, 45, 40), "new": (44, 45, 40)}[st]
        edge = {"done": C["green"], "avail": (110, 112, 98), "active": C["amber"], "queued": C["amber"], "new": C["amber"]}[st]
        d.rounded_rectangle(rect, 6, fill=fill, outline=edge, width=3 if st in ("active", "new") else 2)
        cx, cy = nx + 34, ny + 34
        d.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=(16, 17, 15), outline=(70, 70, 62), width=2)
        if prog:
            d.arc((cx - 24, cy - 24, cx + 24, cy + 24), -90, -90 + 360 * prog, fill=C["green"] if st == "done" else C["amber"], width=5)
        draw_icon(d, ic, (cx, cy), 24, C["text"])
        text(d, (nx + 68, ny + 24), name, font(K.F_LABEL, 17), C["text"], "lm", 1)
        sub = {"done": "DONE", "avail": "1D · $300K", "active": "62% · 4H LEFT", "queued": "QUEUED 1", "new": "NEW"}[st]
        text(d, (nx + 68, ny + 48), sub, font(K.F_MONO, 13), C["green"] if st == "done" else (C["amber"] if st != "avail" else C["dim"]), "lm")
        if st == "new":
            lamp(im, (nx + 244, ny + 14), 6, True, C["amber"])
            d = ImageDraw.Draw(im)
    sel = node_pos("S06")
    d.rounded_rectangle((sel[0] - 4, sel[1] - 4, sel[0] + 264, sel[1] + 72), 8, outline=C["amber"], width=2)


def panel(im):
    x, y, w, h = LAB["lab_panel"]
    steel_plate(im, (x, y, w, h), seed=14)
    d = ImageDraw.Draw(im)
    draw_icon(d, "threat", (x + 28, y + 28), 24, C["amber"])
    text(d, (x + 50, y + 28), "ORIGIN TRACING", font(K.F_LABEL, 24), C["text"], "lm", 2)
    text(d, (x + 18, y + 60), "SCIENCE · TIER 3", font(K.F_LABEL_M, 15), C["dim"], "la", 2)
    recess(im, (x + 14, y + 92, w - 28, 150))
    d = ImageDraw.Draw(im)
    text(d, (x + 28, y + 106), "GIVES", font(K.F_LABEL_M, 15), C["dim"], "la", 2)
    for i, (ic, line) in enumerate((("gate", "Incoming origin shown"), ("threat", "Warning shows the objective"))):
        draw_icon(d, ic, (x + 42, y + 150 + i * 44), 22, C["amber"])
        text(d, (x + 66, y + 150 + i * 44), line, font(K.F_LABEL, 19), C["text"], "lm", 1)
    yy = y + 262
    for i, (ic, val) in enumerate((("clock", "3 D"), ("funds", "$1.2M"), ("team", "2 SCI."))):
        cx = x + 18 + i * 112
        recess(im, (cx, yy, 104, 70))
        dd = ImageDraw.Draw(im)
        draw_icon(dd, ic, (cx + 52, yy + 24), 22, C["text"])
        text(dd, (cx + 52, yy + 54), val, font(K.F_MONO_B, 16), C["text"], "mm")
    yy += 92
    text(d, (x + 18, yy), "NEEDS", font(K.F_LABEL_M, 15), C["dim"], "la", 2)
    key(im, (x + 18, yy + 24, 150, 40), "CALIBRATION", "lit", font_size=15)
    key(im, (x + 18, y + h - 140, w - 36, 60), "START", "amber", font_size=28)
    key(im, (x + 18, y + h - 72, w - 36, 52), "ADD TO QUEUE", "steel", font_size=20)


def benches(im):
    x, y, w, h = K.LAYOUT["station_console"]
    steel_plate(im, (x, y, w, h), seed=35)
    bx, by, bw, bh = LAB["lab_benches"]
    bench = [("RESEARCH LAB", "lab", "ATMOS. SAMPLING", 0.62, ["list"], "2/4 SCI."),
             ("RESEARCH LAB 2", "lab", "", 0, [], "1/4 SCI."),
             ("WORKSHOP", "base", "SECURITY POST", 0.30, ["plus", "charge"], "2/2 ENG.")]
    for i, (n, ic, cur, prog, q, staff) in enumerate(bench):
        cx = x + 12 + i * 278
        recess(im, (cx, y + 12, 268, h - 24), fill=(34, 35, 31))
        d = ImageDraw.Draw(im)
        draw_icon(d, ic, (cx + 22, y + 34), 20, C["amber"])
        text(d, (cx + 40, y + 34), n, font(K.F_LABEL, 17), C["text"], "lm", 2)
        text(d, (cx + 256, y + 34), staff, font(K.F_MONO, 13), C["dim"], "rm")
        if cur:
            text(d, (cx + 16, y + 70), cur, font(K.F_LABEL, 18), C["text"], "lm", 1)
            d.rectangle((cx + 16, y + 88, cx + 252, y + 98), fill=(20, 21, 18), outline=C["edge"])
            d.rectangle((cx + 17, y + 89, cx + 17 + int(234 * prog), y + 97), fill=C["amber"])
            for k, qi in enumerate(q):
                qx = cx + 16 + k * 44
                d.rounded_rectangle((qx, y + 112, qx + 36, y + 148), 4, fill=(22, 23, 20), outline=C["edge"], width=2)
                draw_icon(d, qi, (qx + 18, y + 130), 18, C["dim"])
        else:
            text(d, (cx + 134, y + 90), "IDLE · PICK A PROJECT", font(K.F_LABEL, 17), C["amber"], "mm", 2)
            lamp(im, (cx + 134, y + 126), 7, True, C["amber"])


def compose():
    im = Image.new("RGB", (W, H), (10, 11, 10))
    im.paste(noise_overlay(vgrad((W, H), (50, 52, 45), (28, 29, 25)), 10, 3), (0, 0))
    tabs(im)
    board(im)
    K.top_bar(im)
    K.wire(im, [
        ("lab", "NEW RESEARCH", "Xenotech · 1", C["amber"], ["arrow"]),
        ("lab", "LAB IDLE", "Research Lab 2", C["amber"], ["arrow"]),
        ("candidate", "CANDIDATE", "Engineer · skill 3", C["green"], ["check", "cross"]),
    ])
    K.bottom_bar(im, "lab", False)
    benches(im)
    panel(im)
    im.save(f"{OUT}/ref_lab.png")
    ov = Image.new("RGB", (W, H), (20, 22, 24))
    d = ImageDraw.Draw(ov)
    regs = dict(K.LAYOUT)
    regs.update(LAB)
    for k in ["top_bar", "wire", "bottom_bar", "station_keys", "station_console", "gate_monitor"] + list(LAB):
        x, y, w, h = regs[k]
        d.rectangle((x, y, x + w - 1, y + h - 1), outline=(232, 163, 61), width=2)
        text(d, (x + 6, y + 4), f"{k}  {x},{y}  {w}×{h}", font(K.F_MONO, 13), (232, 228, 208))
    ov.save(f"{OUT}/overlay_lab.png")
    lay = json.load(open("/home/claude/starportal/docs/reference/layout.json"))
    for k, v in LAB.items():
        lay[k] = {"x": v[0], "y": v[1], "w": v[2], "h": v[3]}
    json.dump(lay, open(f"{OUT}/layout.json", "w"), indent=1)


compose()
print("ok")
