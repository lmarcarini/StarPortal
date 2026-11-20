"""Procedural pixel-art staff portraits, 96x96, shown upscaled with nearest neighbour.

Each part is a boolean mask shaded with a 5-step ramp (outline, shadow, mid, light,
highlight). Light comes from the upper left. Seeded RNG: same seed, same face.
"""
import colorsys
import random
import sys

import numpy as np
from PIL import Image

S = 96
FIELDS = ["military", "office", "science", "engineering", "medicine"]


# ---------- colour ----------
def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(base, sat=1.0):
    """Five shades: hue shifts cool in shadow, warm in light."""
    r, g, b = [c / 255 for c in hexrgb(base)]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    out = []
    for dl, dh, ds in ((-0.30, 0.04, 0.10), (-0.13, 0.02, 0.05), (0, 0, 0),
                       (0.08, -0.01, -0.06), (0.14, -0.02, -0.15)):
        hh = (h + dh) % 1.0
        ll = min(max(l + dl, 0.03), 0.95)
        if dl < -0.25:
            ll = min(ll, 0.26)
        ss = min(max((s + ds) * sat, 0), 1)
        out.append(tuple(int(c * 255) for c in colorsys.hls_to_rgb(hh, ll, ss)))
    return out


SKINS = ["#f1c9a5", "#e0ac84", "#c68a62", "#a86b45", "#7d4a2e", "#5a3420"]
HAIRS = ["#2a1d16", "#3b2618", "#5a3a22", "#7a5432", "#a0702e", "#c9a35a",
         "#8a3c1c", "#b0552a", "#1b1b1f"]
GREYS = ["#8d8a86", "#b7b3ad", "#d8d5cf"]
EYES = ["#3b5a7a", "#4d6b3a", "#5a3b22", "#2b2018", "#6b7d8a"]
OUTFIT = {
    "military": ("#4b5135", "#7a2e24"), "office": ("#2c3546", "#8a6a2a"),
    "science": ("#d9d6cc", "#2f5f86"), "engineering": ("#6d5a3c", "#c27a1e"),
    "medicine": ("#3f6e6a", "#d8d2c4"),
}


# ---------- masks ----------
yy, xx = np.mgrid[0:S, 0:S]


def ellipse(cx, cy, rx, ry):
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0


def poly(pts):
    from PIL import ImageDraw
    im = Image.new("1", (S, S), 0)
    ImageDraw.Draw(im).polygon(pts, fill=1)
    return np.array(im, dtype=bool)


def rect(x0, y0, x1, y1):
    return (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)


def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    ys = slice(max(dy, 0), h + min(dy, 0)); yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0)); xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[yd, xd] = m[ys, xs]
    return out


# ---------- canvas ----------
class Canvas:
    def __init__(self, rng):
        self.px = np.zeros((S, S, 3), dtype=np.uint8)
        self.rng = rng
        self.background()

    def background(self):
        top, bot = np.array(hexrgb("#1f2a3c")), np.array(hexrgb("#0e1420"))
        t = np.clip(yy / S * 1.1, 0, 1)
        vig = np.clip(np.hypot(xx - 48, yy - 40) / 70, 0, 1) * 0.35
        k = np.clip(t * 0.7 + vig, 0, 1)[..., None]
        self.px[:] = (top * (1 - k) + bot * k).astype(np.uint8)

    def fill(self, mask, colour):
        self.px[mask] = colour

    def shaded(self, mask, rp, depth=3, rim=True, side=0.2):
        """Shade a mask: highlight top-left, shadow bottom-right, outline edge."""
        if not mask.any():
            return
        idx = np.full(mask.shape, 2)
        cols = np.where(mask.any(0))[0]
        x0, x1 = cols.min(), cols.max()
        idx[xx > x0 + (x1 - x0) * (1 - side)] = 1
        idx[mask & ~shift(mask, depth, depth)] = 1
        idx[mask & ~shift(mask, -depth, -depth)] = 3
        idx[mask & ~shift(mask, -1, -1) & shift(mask, 1, 0) & shift(mask, 0, 1) & (idx == 3)] = 4
        if rim:
            inner = shift(mask, 1, 0) & shift(mask, -1, 0) & shift(mask, 0, 1) & shift(mask, 0, -1)
            idx[mask & ~inner] = 0
        for i in range(5):
            self.px[mask & (idx == i)] = rp[i]

    def dot(self, x, y, c):
        if 0 <= x < S and 0 <= y < S:
            self.px[y, x] = c

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.dot(x, y, c)

    def image(self):
        return Image.fromarray(self.px)


# ---------- the person ----------

# ---------- the person ----------
HEADS = {"round": (19, 21), "oval": (17, 23), "square": (19, 22), "long": (16, 25)}
VARIANTS = {
    "military": ["standard", "officer", "expedition", "casual", "command"],
    "science": ["labcoat", "shirt_tie", "overalls", "casual"],
    "engineering": ["coverall", "vest", "jacket", "casual"],
    "office": ["suit", "shirt_tie", "sweater", "blazer"],
    "medicine": ["scrubs", "labcoat", "fatigues"],
}


def make_person(seed, field=None):
    r = random.Random(seed)
    female = r.random() < 0.45
    age = r.choice(["young", "adult", "adult", "older"])
    head = r.choice(list(HEADS))
    w, h = HEADS[head]
    p = {
        "field": field or r.choice(FIELDS), "female": female, "age": age,
        "skin": r.choice(SKINS), "hair_col": r.choice(HAIRS), "eye_col": r.choice(EYES),
        "head": head, "face_w": w - (1 if female else 0) + r.randint(-1, 1), "face_h": h,
        "jaw": r.choice(["narrow", "broad", "angular"]),
        "eyes": r.choice(["small", "round", "narrow"]),
        "brows": r.choice(["straight", "angled", "thick"]),
        "nose": r.choice(["short", "long", "wide"]),
        "mouth": r.choice(["thin", "wide", "neutral"]),
        "accessory": r.choices(["none", "glasses", "patch", "scar"], [12, 3, 1, 2])[0],
    }
    if female:
        p["hair"] = r.choice(["ponytail", "long", "curly", "bun", "side", "messy", "military"])
        p["beard"] = "none"
    else:
        p["hair"] = r.choice(["military", "military", "buzz", "side", "messy", "curly",
                              "receding", "bald"])
        p["beard"] = r.choices(["none", "stubble", "moustache", "beard"], [6, 2, 1, 2])[0]
    if age == "older" and r.random() < 0.65:
        p["hair_col"] = r.choice(GREYS)
        if not female and r.random() < 0.4:
            p["hair"] = "receding"
    if age == "young" and p["beard"] == "beard":
        p["beard"] = "stubble"
    p["variant"] = r.choice(VARIANTS[p["field"]])
    if p["variant"] in ("labcoat", "shirt_tie") and r.random() < 0.4:
        p["accessory"] = "glasses"
    return p


CX, CY = 48, 38


def head_mask(p):
    w, h = p["face_w"], p["face_h"]
    top = ellipse(CX, CY - 2, w, h - 2)
    jw = {"narrow": w - 7, "broad": w - 2, "angular": w - 4}[p["jaw"]]
    chin_w = {"narrow": 3, "broad": 6, "angular": 5}[p["jaw"]]
    drop = 9 if p["jaw"] == "angular" else 6
    if p["head"] == "round":
        drop += 2
    chin = poly([(CX - w, CY), (CX + w, CY), (CX + jw, CY + h - drop),
                 (CX + chin_w, CY + h), (CX - chin_w, CY + h), (CX - jw, CY + h - drop)])
    return top | chin


def draw_head(cv, p):
    skin = ramp(p["skin"])
    w = p["face_w"]
    for s in (-1, 1):
        cv.shaded(ellipse(CX + s * (w + 1), CY + 2, 3, 5), skin, depth=1)
    hm = head_mask(p)
    cv.shaded(hm, skin, depth=3, side=0.18)
    if p["jaw"] == "angular":  # cheekbone plane
        for y in range(CY + 6, CY + 11):
            cv.dot(CX + w - 5 - (y - CY - 6) // 2, y, skin[1])
    return hm


def draw_eyes(cv, p, ey):
    skin, eye, hc = ramp(p["skin"]), ramp(p["eye_col"]), ramp(p["hair_col"])
    kind = p["eyes"]
    gap = 7 if p["face_w"] >= 18 else 6
    for s in (-1, 1):
        ex = CX + s * gap
        half = 3 if kind == "round" else 2
        cv.hline(ex - half - 1, ex + half, ey - 1, skin[0])                 # lid line
        cv.hline(ex - half, ex + half, ey, (214, 206, 196))
        cv.dot(ex, ey, eye[0]); cv.dot(ex + s, ey, eye[2])
        if kind == "round":
            cv.hline(ex - half, ex + half, ey + 1, (196, 188, 178))
            cv.dot(ex, ey + 1, eye[1]); cv.dot(ex - half - 1, ey + 1, skin[1])
        if kind == "narrow":
            cv.hline(ex - half, ex + half, ey, skin[1]); cv.dot(ex, ey, eye[0]); cv.dot(ex + s, ey, eye[0])
        cv.hline(ex - half, ex + half, ey + (2 if kind == "round" else 1), skin[1])
        draw_brow(cv, p["brows"], ex, ey - 4, s, hc)


def draw_brow(cv, kind, ex, by, s, hc):
    for i in range(-3, 4):
        dy = 0
        if kind == "angled":
            dy = (i * s) // 2 if i * s > 0 else 0   # outer ends lifted... inner end lowered
            dy = -dy + (1 if i * s < -1 else 0)
        cv.dot(ex + i, by + dy, hc[0])
        if kind == "thick":
            cv.dot(ex + i, by - 1, hc[1])
        elif kind != "angled" and abs(i) < 3:
            cv.dot(ex + i, by - 1, hc[2])


def draw_nose(cv, p, ey):
    skin = ramp(p["skin"])
    n = p["nose"]
    length = {"short": 6, "long": 9, "wide": 7}[n]
    for y in range(ey + 2, ey + 2 + length):
        cv.dot(CX + 2, y, skin[1])
    cv.dot(CX - 1, ey + length - 1, skin[3])
    by = ey + 2 + length
    half = 3 if n == "wide" else 2
    cv.hline(CX - half, CX + half, by, skin[1])
    cv.dot(CX - half + 1, by, skin[0]); cv.dot(CX + half - 1, by, skin[0])
    if n == "wide":
        cv.dot(CX - half - 1, by - 1, skin[1]); cv.dot(CX + half + 1, by - 1, skin[1])
    return by


def draw_mouth(cv, p, my):
    skin = ramp(p["skin"])
    lip = ramp("#a8524a") if p["female"] else skin
    half = {"thin": 3, "wide": 5, "neutral": 4}[p["mouth"]]
    cv.hline(CX - half, CX + half, my, skin[0])
    if p["mouth"] != "thin":
        cv.hline(CX - half + 1, CX + half - 1, my + 1, lip[2] if p["female"] else skin[1])
    else:
        cv.hline(CX - 2, CX + 2, my + 1, skin[1])
    if p["female"]:
        cv.hline(CX - half + 1, CX + half - 1, my - 1, lip[1])
    cv.hline(CX - 2, CX + 2, my + 3, skin[1])                 # under-lip shadow


def draw_face(cv, p, hm):
    skin = ramp(p["skin"])
    ey = CY + 1
    draw_eyes(cv, p, ey)
    nb = draw_nose(cv, p, ey)
    my = nb + 4
    draw_mouth(cv, p, my)
    if p["age"] != "young":
        for s in (-1, 1):  # nasolabial folds
            for k in range(3):
                cv.dot(CX + s * (5 + k // 2), nb + k, skin[1])
    if p["age"] == "older":
        cv.hline(CX - 5, CX + 5, ey - 9, skin[1]); cv.hline(CX - 3, CX + 3, ey - 11, skin[1])
        for s in (-1, 1):
            cv.dot(CX + s * 11, ey + 1, skin[1]); cv.dot(CX + s * 11, ey + 2, skin[1])
    draw_beard(cv, p, hm, my)


def draw_beard(cv, p, hm, my):
    hr = ramp(p["hair_col"])
    if p["beard"] == "stubble":
        rr = random.Random(hash(p["skin"]) & 0xffff)
        jaw = hm & (yy > my - 5) & (np.abs(xx - CX) < p["face_w"] - 2)
        for y, x in zip(*np.nonzero(jaw)):
            if rr.random() < 0.28:
                cv.px[y, x] = (cv.px[y, x] * 0.8).astype(np.uint8)
    if p["beard"] in ("moustache", "beard"):
        cv.shaded(rect(CX - 5, my - 3, CX + 5, my - 1), hr, depth=1)
    if p["beard"] == "beard":
        m = hm & (yy > my - 2) & ~rect(CX - 3, my, CX + 3, my + 2)
        cv.shaded(m, hr, depth=2)
        cv.hline(CX - 3, CX + 3, my + 1, ramp(p["skin"])[1])


# ---------- hair ----------
def draw_hair_back(cv, p):
    hr = ramp(p["hair_col"])
    w, h = p["face_w"], p["face_h"]
    if p["hair"] == "long":
        cv.shaded(poly([(CX - w - 4, CY - 8), (CX + w + 4, CY - 8), (CX + w + 6, CY + h + 14),
                        (CX - w - 6, CY + h + 14)]), hr)
    elif p["hair"] == "ponytail":
        cv.shaded(ellipse(CX + w + 3, CY + 6, 5, 13), hr)
    elif p["hair"] == "curly" and p["female"]:
        cv.shaded(ellipse(CX, CY + 4, w + 8, h + 4) & (yy < CY + 16), hr)


def hair_cap(p, hm):
    w, h = p["face_w"], p["face_h"]
    style = p["hair"]
    line = {"receding": 14, "military": 11, "buzz": 11}.get(style, 10)
    hairline = yy < CY - line + (np.abs(xx - CX) * 0.45).astype(int)
    temples = (np.abs(xx - CX) > w - 3) & (yy < CY - 1)
    puff = {"military": 1, "buzz": 0, "messy": 3, "curly": 3}.get(style, 2)
    cap = ellipse(CX, CY - 3, w + puff, h + puff - 1) & (hairline | temples)
    if style == "receding":
        cap &= ~(ellipse(CX, CY - h + 2, 9, 7))
        cap &= ellipse(CX, CY - 3, w + 1, h)
    if style == "side":
        cap |= poly([(CX - w, CY - 10), (CX + 6, CY - 14), (CX - w + 1, CY - 3)]) & ellipse(CX, CY, w + 2, h + 2)
    if style == "messy":
        for i in range(7):
            a = np.pi * (1.1 + i * 0.13)
            tip = (int(CX + np.cos(a) * (w + 5)), int(CY - 4 + np.sin(a) * (h + 4)))
            base_l = (int(CX + np.cos(a - 0.12) * w), int(CY - 4 + np.sin(a - 0.12) * h))
            base_r = (int(CX + np.cos(a + 0.12) * w), int(CY - 4 + np.sin(a + 0.12) * h))
            cap |= poly([base_l, tip, base_r])
        cap |= poly([(CX - 8, CY - 12), (CX + 2, CY - 12), (CX - 4, CY - 6)])
    if style == "curly":
        for i in range(12):
            a = np.pi * (0.9 + i * 0.11)
            cap |= ellipse(CX + np.cos(a) * (w + 1), CY - 6 + np.sin(a) * (h - 1), 4, 4) & (yy < CY - 2)
    if style == "long":
        cap |= poly([(CX - w - 2, CY - 8), (CX + 2, CY - 14), (CX - w, CY + 2)])
        cap |= (ellipse(CX, CY, w + 4, h + 4) & ~ellipse(CX, CY + 3, w - 1, h) & (yy < CY + 12))
    return cap


def draw_hair_front(cv, p, hm):
    hr = ramp(p["hair_col"])
    style = p["hair"]
    if style == "bald":
        return
    cap = hair_cap(p, hm)
    if style == "buzz":  # short solid stubble cap, slightly lighter than skin shadow
        cv.shaded(cap & hm, [hr[0], hr[1], hr[1], hr[2], hr[2]], depth=2, rim=False)
        return
    cv.shaded(cap, hr, depth=3)
    if style == "bun":
        cv.shaded(ellipse(CX, CY - p["face_h"] - 3, 7, 5), hr)
    # a few strand lines, selective, no dither
    w = p["face_w"]
    for i in range(4):
        x = CX - w + 6 + i * (2 * w // 5)
        cv.dot(x, CY - p["face_h"] + 4, hr[3]); cv.dot(x + 1, CY - p["face_h"] + 5, hr[3])
        cv.dot(x + 2, CY - p["face_h"] + 7, hr[1])

# ---------- outfits ----------
def torso_mask(p):
    wide = 0 if p["female"] else 3
    body = poly([(0, 96), (3, 80), (14 - wide, 68), (82 + wide, 68), (93, 80), (96, 96)])
    shoulders = ellipse(22 - wide, 80, 18, 13) | ellipse(74 + wide, 80, 18, 13)
    return (body | shoulders) & (yy >= 64)


def folds(cv, rp):
    for s in (-1, 1):  # arm creases
        x = CX + s * 27
        for k in range(10):
            cv.dot(x, 84 + k, rp[1])


def vneck(cv, p, depth=14):
    cv.shaded(poly([(CX - 9, 64), (CX, 64 + depth), (CX + 9, 64)]), ramp(p["skin"]), depth=2)


def shirt_v(cv, col, depth=22, w=10):
    cv.shaded(poly([(CX - w, 64), (CX, 64 + depth), (CX + w, 64)]), ramp(col, 0.6), depth=2)


def tie(cv, col, top=68):
    cv.shaded(poly([(CX - 2, top), (CX + 2, top), (CX + 3, 96), (CX - 3, 96)]), ramp(col), depth=1)
    cv.hline(CX - 2, CX + 2, top + 2, ramp(col)[0])


def lapels(cv, col, top=64):
    for s in (-1, 1):
        cv.shaded(poly([(CX + s * 10, top), (CX + s * 3, top + 14), (CX + s * 9, 96),
                        (CX + s * 16, 96), (CX + s * 15, top + 2)]), ramp(col), depth=2)


def stand_collar(cv, col):
    cv.shaded(poly([(CX - 12, 60), (CX + 12, 60), (CX + 14, 69), (CX - 14, 69)]), ramp(col), depth=2)


def zipper(cv, col, top=70):
    for y in range(top, 96):
        cv.dot(CX, y, ramp(col)[0])


def pockets(cv, col, y=82):
    for s in (-1, 1):
        px = CX + s * 21
        cv.shaded(rect(px - 6, y, px + 6, y + 9), ramp(col), depth=1)
        cv.hline(px - 6, px + 6, y + 2, ramp(col)[1])


def epaulettes(cv, col, pip=None):
    for s in (-1, 1):
        ex = CX + s * 31
        cv.shaded(rect(ex - 7, 68, ex + 7, 71), ramp(col), depth=1)
        if pip:
            for k in (-3, 0, 3):
                cv.dot(ex + k, 69, ramp(pip)[3])


def patch(cv, col, x=8, y=82):
    cv.shaded(rect(x, y, x + 7, y + 7), ramp(col), depth=1)


def straps(cv, col):
    for s in (-1, 1):
        x = CX + s * 17
        cv.shaded(poly([(x - 3, 66), (x + 3, 66), (x + 3, 96), (x - 3, 96)]), ramp(col), depth=1)


def neck(cv, p):
    skin = ramp(p["skin"])
    m = rect(CX - 8, CY + 14, CX + 8, 70)
    cv.shaded(m, skin, depth=4, side=0.45)
    cv.fill(rect(CX - 8, CY + 14, CX + 8, CY + 19), skin[1])


def draw_body(cv, p):
    neck(cv, p)
    OUTFITS[p["field"]](cv, p, torso_mask(p))


def mil(cv, p, t):
    v = p["variant"]
    base = {"standard": "#4b5135", "officer": "#3b4232", "expedition": "#5d5a3e",
            "casual": "#24282c", "command": "#2b3446"}[v]
    cv.shaded(t, ramp(base), depth=4); folds(cv, ramp(base))
    if v == "casual":
        cv.shaded(ellipse(CX, 64, 11, 6) & (yy >= 62), ramp(p["skin"]), depth=1)
        cv.hline(CX - 11, CX + 11, 66, ramp(base)[3])
        return
    if v in ("officer", "command"):
        shirt_v(cv, "#c9c3b0"); tie(cv, "#262a22"); lapels(cv, base)
        epaulettes(cv, base, "#c9a35a")
        if v == "command":
            for i in range(3):
                cv.shaded(rect(CX + 18 + i * 4, 80, CX + 20 + i * 4, 82),
                          ramp(["#7a2e24", "#2f5f86", "#c9a35a"][i]), depth=0, rim=False)
        return
    stand_collar(cv, base); zipper(cv, base); pockets(cv, base); epaulettes(cv, base)
    patch(cv, "#7a2e24")
    if v == "expedition":
        straps(cv, "#3a3a2c")
        cv.shaded(rect(CX + 14, 74, CX + 19, 84), ramp("#2a2a2a"), depth=1)  # radio


def sci(cv, p, t):
    v = p["variant"]
    if v == "labcoat":
        cv.shaded(t, ramp("#d9d6cc", 0.5), depth=4); folds(cv, ramp("#d9d6cc", 0.5))
        shirt_v(cv, "#2b3340", depth=30, w=11); lapels(cv, "#d9d6cc")
        cv.shaded(poly([(CX - 7, 64), (CX, 72), (CX + 7, 64)]), ramp("#2f5f86"), depth=1)
        cv.shaded(rect(CX + 18, 84, CX + 26, 92), ramp("#d9d6cc", 0.5), depth=1)
        cv.dot(CX + 20, 84, (40, 60, 120)); cv.dot(CX + 20, 85, (40, 60, 120))  # pen
    elif v == "shirt_tie":
        cv.shaded(t, ramp("#8fa6b8", 0.7), depth=4); folds(cv, ramp("#8fa6b8"))
        stand_collar(cv, "#a9bccb"); tie(cv, "#2f5f86", 69)
    elif v == "overalls":
        cv.shaded(t, ramp("#56636b"), depth=4); folds(cv, ramp("#56636b"))
        vneck(cv, p, 8); straps(cv, "#3e4950"); patch(cv, "#2f5f86", 74, 84)
    else:
        cv.shaded(t, ramp("#6b5a4a"), depth=4); folds(cv, ramp("#6b5a4a"))
        cv.shaded(rect(CX - 9, 60, CX + 9, 68), ramp("#4a3e34"), depth=1)  # turtleneck


def eng(cv, p, t):
    v = p["variant"]
    base = {"coverall": "#6d5a3c", "vest": "#4a4f55", "jacket": "#3a3d40", "casual": "#4a4f55"}[v]
    cv.shaded(t, ramp(base), depth=4); folds(cv, ramp(base))
    if v == "coverall":
        stand_collar(cv, base); zipper(cv, base); pockets(cv, base); patch(cv, "#c27a1e")
    elif v == "vest":
        vneck(cv, p, 8)
        for s in (-1, 1):
            cv.shaded(poly([(CX + s * 9, 66), (CX + s * 24, 66), (CX + s * 26, 96), (CX + s * 6, 96)]),
                      ramp("#c27a1e"), depth=2)
            cv.hline(CX + min(s * 7, s * 25), CX + max(s * 7, s * 25), 86, ramp("#d8d2c4")[3])
    elif v == "jacket":
        stand_collar(cv, base); zipper(cv, base, 69)
        for s in (-1, 1):
            cv.hline(CX + min(s * 2, s * 40), CX + max(s * 2, s * 40), 78, ramp("#c27a1e")[2])
    else:
        cv.shaded(ellipse(CX, 64, 11, 6) & (yy >= 62), ramp(p["skin"]), depth=1)
        cv.shaded(rect(CX - 26, 80, CX - 16, 86), ramp("#c27a1e"), depth=1)


def off(cv, p, t):
    v = p["variant"]
    base = {"suit": "#2c3546", "shirt_tie": "#d6d2c6", "sweater": "#5a4a5e", "blazer": "#5c4a3a"}[v]
    cv.shaded(t, ramp(base, 0.6 if v == "shirt_tie" else 1), depth=4); folds(cv, ramp(base))
    if v == "suit":
        shirt_v(cv, "#d9d4c8"); tie(cv, "#8a6a2a"); lapels(cv, base)
    elif v == "shirt_tie":
        stand_collar(cv, "#e2ded4"); tie(cv, "#7a2e24", 69)
    elif v == "sweater":
        shirt_v(cv, "#d9d4c8", 16, 9)
        cv.shaded(poly([(CX - 5, 64), (CX, 70), (CX + 5, 64)]), ramp("#d9d4c8", 0.5), depth=1)
    else:
        shirt_v(cv, "#24262a", 26, 11); lapels(cv, base)
        cv.shaded(rect(CX - 8, 60, CX + 8, 67), ramp("#24262a"), depth=1)


def med(cv, p, t):
    v = p["variant"]
    if v == "fatigues":
        cv.shaded(t, ramp("#4b5135"), depth=4); folds(cv, ramp("#4b5135"))
        stand_collar(cv, "#4b5135"); zipper(cv, "#4b5135"); pockets(cv, "#4b5135")
        patch(cv, "#d8d2c4"); cv.hline(9, 14, 85, (150, 40, 36)); cv.hline(9, 14, 86, (150, 40, 36))
        for y in (83, 84, 87, 88):
            cv.dot(11, y, (150, 40, 36)); cv.dot(12, y, (150, 40, 36))
        return
    coat = v == "labcoat"
    cv.shaded(t, ramp("#d9d6cc" if coat else "#3f6e6a", 0.5 if coat else 1), depth=4)
    folds(cv, ramp("#3f6e6a"))
    if coat:
        shirt_v(cv, "#3f6e6a", 30, 11); lapels(cv, "#d9d6cc")
    vneck(cv, p, 12)
    cv.shaded(rect(CX + 16, 82, CX + 27, 87), ramp("#d8d2c4"), depth=1)  # badge
    if not coat:  # stethoscope
        for k in range(14):
            cv.dot(CX - 12 + k // 4, 66 + k, (40, 44, 48)); cv.dot(CX + 12 - k // 4, 66 + k, (40, 44, 48))


OUTFITS = {"military": mil, "science": sci, "engineering": eng, "office": off, "medicine": med}

def draw_accessory(cv, p):
    a = p["accessory"]
    ey = CY + 1
    if a == "glasses":
        frame = (30, 30, 34)
        for s in (-1, 1):
            ex = CX + s * 7
            cv.hline(ex - 4, ex + 4, ey - 3, frame); cv.hline(ex - 4, ex + 4, ey + 3, frame)
            for y in range(ey - 3, ey + 4):
                cv.dot(ex - 4, y, frame); cv.dot(ex + 4, y, frame)
            cv.dot(ex - 2, ey - 2, (190, 200, 210))
        cv.hline(CX - 3, CX + 3, ey - 2, frame)
    elif a == "patch":
        cv.shaded(ellipse(CX - 7, ey, 4, 4), ramp("#24242a"), depth=1)
        for i in range(-16, 17):
            cv.dot(CX + i, ey - 6 - abs(i) // 6 + (i // 3), (24, 24, 28))
    elif a == "scar":
        sk = ramp(p["skin"])
        for i in range(7):
            cv.dot(CX + 9 + i // 2, ey + 3 + i, sk[4]); cv.dot(CX + 10 + i // 2, ey + 3 + i, sk[1])



def render(seed, field=None):
    p = make_person(seed, field)
    cv = Canvas(random.Random(seed))
    draw_hair_back(cv, p)
    draw_body(cv, p)
    hm = draw_head(cv, p)
    draw_face(cv, p, hm)
    draw_hair_front(cv, p, hm)
    draw_accessory(cv, p)
    return cv.image(), p

def sheet(n=20, scale=3, cols=5, seed0=100):
    pad = 12
    W = cols * (S * scale + pad) + pad
    rows = (n + cols - 1) // cols
    out = Image.new("RGB", (W, rows * (S * scale + pad) + pad), hexrgb("#0a0e16"))
    for i in range(n):
        im, _ = render(seed0 + i, FIELDS[i % 5])
        im = im.resize((S * scale, S * scale), Image.NEAREST)
        out.paste(im, (pad + (i % cols) * (S * scale + pad), pad + (i // cols) * (S * scale + pad)))
    return out


if __name__ == "__main__":
    seed0 = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    sheet(seed0=seed0).save(sys.argv[2] if len(sys.argv) > 2 else "portraits_sheet.png")
    print("ok")
