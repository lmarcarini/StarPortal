"""Full-body 2D-HD sprites (64x128, front view) from the same person record as the portrait."""
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

from pixel_portraits import FIELDS, make_person, ramp, hexrgb

W, H = 64, 128
yy, xx = np.mgrid[0:H, 0:W]
CX = 32

# outfit colours per (field, variant): top, bottom, accent
TOPS = {
    "standard": ("#4b5135", "#4b5135", "#7a2e24"), "officer": ("#3b4232", "#3b4232", "#c9a35a"),
    "expedition": ("#5d5a3e", "#5d5a3e", "#3a3a2c"), "casual": ("#24282c", "#4b5135", "#24282c"),
    "command": ("#2b3446", "#2b3446", "#c9a35a"), "labcoat": ("#d9d6cc", "#3a3f48", "#2f5f86"),
    "shirt_tie": ("#8fa6b8", "#3a3f48", "#2f5f86"), "overalls": ("#56636b", "#56636b", "#2f5f86"),
    "coverall": ("#6d5a3c", "#6d5a3c", "#c27a1e"), "vest": ("#4a4f55", "#3a3d40", "#c27a1e"),
    "jacket": ("#3a3d40", "#3a3d40", "#c27a1e"), "suit": ("#2c3546", "#2c3546", "#8a6a2a"),
    "sweater": ("#5a4a5e", "#3a3f48", "#d9d4c8"), "blazer": ("#5c4a3a", "#3a3632", "#24262a"),
    "scrubs": ("#3f6e6a", "#3f6e6a", "#d8d2c4"), "fatigues": ("#4b5135", "#4b5135", "#d8d2c4"),
}


def poly(pts):
    im = Image.new("1", (W, H), 0)
    ImageDraw.Draw(im).polygon(pts, fill=1)
    return np.array(im, dtype=bool)


def ell(cx, cy, rx, ry):
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1


def rect(x0, y0, x1, y1):
    return (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)


def shift(m, dx, dy):
    out = np.zeros_like(m)
    ys = slice(max(dy, 0), H + min(dy, 0)); yd = slice(max(-dy, 0), H + min(-dy, 0))
    xs = slice(max(dx, 0), W + min(dx, 0)); xd = slice(max(-dx, 0), W + min(-dx, 0))
    out[yd, xd] = m[ys, xs]
    return out


class Sprite:
    def __init__(self):
        self.px = np.zeros((H, W, 4), dtype=np.uint8)

    def shaded(self, m, rp, depth=2):
        idx = np.full(m.shape, 2)
        idx[m & ~shift(m, depth, 0)] = 1
        idx[m & ~shift(m, -depth, -depth)] = 3
        inner = shift(m, 1, 0) & shift(m, -1, 0) & shift(m, 0, 1) & shift(m, 0, -1)
        idx[m & ~inner] = 0
        for i in range(4):
            self.px[m & (idx == i)] = (*rp[i], 255)

    def dot(self, x, y, c):
        self.px[y, x] = (*c, 255)


def body(sp, p):
    v = p["variant"]
    top, bottom, acc = TOPS[v]
    skin, hr = ramp(p["skin"]), ramp(p["hair_col"])
    sh = 1 if p["female"] else 0
    # legs and boots
    for s in (-1, 1):
        sp.shaded(rect(CX + s * 6 - 4, 72, CX + s * 6 + 4, 116) & ~rect(CX - 1, 72, CX + 1, 116), ramp(bottom))
        sp.shaded(rect(CX + s * 6 - 5, 114, CX + s * 6 + 5, 123), ramp("#24221f"))
    coat = v == "labcoat"
    # torso
    torso = poly([(CX - 13 + sh, 30), (CX + 13 - sh, 30), (CX + 12 - sh, 72 if not coat else 92),
                  (CX - 12 + sh, 72 if not coat else 92)])
    sp.shaded(torso, ramp(top, 0.6 if coat else 1))
    sp.shaded(rect(CX - 12 + sh, 68, CX + 12 - sh, 72), ramp("#2a2622"))  # belt
    sp.dot(CX, 70, ramp("#c9a35a")[3])
    # arms
    for s in (-1, 1):
        arm = poly([(CX + s * 13, 31), (CX + s * 18, 34), (CX + s * 19, 66), (CX + s * 14, 66), (CX + s * 13, 40)])
        sp.shaded(arm, ramp(top, 0.6 if coat else 1))
        sp.shaded(ell(CX + s * 16, 69, 3, 4), skin)
    # neck, head
    sp.shaded(rect(CX - 3, 24, CX + 3, 31), skin)
    sp.shaded(ell(CX, 16, 7, 9), skin)
    for s in (-1, 1):
        sp.dot(CX + s * 3, 16, (30, 26, 24))
    sp.dot(CX + 1, 19, skin[1]); sp.dot(CX - 1, 21, skin[0]); sp.dot(CX, 21, skin[0]); sp.dot(CX + 1, 21, skin[0])
    hair(sp, p, hr)
    details(sp, p, v, top, acc)


def hair(sp, p, hr):
    st = p["hair"]
    if st == "bald":
        return
    cap = ell(CX, 13, 8, 7) & (yy < 13)
    if st in ("long", "ponytail", "curly") and p["female"]:
        cap |= rect(CX - 8, 10, CX + 8, 28 if st == "long" else 20) & ~rect(CX - 5, 12, CX + 5, 30)
    if st == "bun":
        cap |= ell(CX, 5, 4, 3)
    if st == "receding":
        cap &= ~ell(CX, 7, 4, 4)
    if st in ("messy", "curly"):
        cap |= ell(CX, 9, 9, 5)
    sp.shaded(cap, hr)


def details(sp, p, v, top, acc):
    ta = ramp(acc)
    if v in ("officer", "command", "suit", "blazer"):
        sp.shaded(poly([(CX - 4, 30), (CX, 42), (CX + 4, 30)]), ramp("#d9d4c8", 0.5), 1)
        for y in range(32, 46):
            sp.dot(CX, y, ta[1])
    if v in ("officer", "command"):
        for s in (-1, 1):
            sp.dot(CX + s * 10, 31, ta[3]); sp.dot(CX + s * 11, 31, ta[3])
    if v in ("standard", "expedition", "coverall", "fatigues", "jacket"):
        for y in range(32, 68):
            sp.dot(CX, y, ramp(top)[0])
        sp.shaded(rect(CX - 18, 38, CX - 15, 41), ta, 1)  # shoulder patch
    if v == "expedition":
        for s in (-1, 1):
            for y in range(31, 68):
                sp.dot(CX + s * 7, y, ramp("#3a3a2c")[0])
    if v == "vest":
        for s in (-1, 1):
            sp.shaded(rect(CX + s * 8 - 4, 32, CX + s * 8 + 4, 66), ta, 1)
    if v == "labcoat":
        sp.shaded(poly([(CX - 5, 30), (CX, 50), (CX + 5, 30)]), ramp("#2b3340"), 1)
        for y in range(50, 92):
            sp.dot(CX, y, (150, 148, 140))
    if p["accessory"] == "glasses":
        for x in range(CX - 5, CX + 6):
            sp.dot(x, 15, (30, 30, 34))


def render_body(seed, field=None):
    p = make_person(seed, field)
    sp = Sprite()
    body(sp, p)
    return Image.fromarray(sp.px, "RGBA"), p


def sheet(seed0=100, n=10, scale=3):
    from pixel_portraits import render
    pad = 10
    cw = 96 * scale // 2 + 64 * scale + pad * 2
    out = Image.new("RGB", (cw * 5 + pad, (H * scale + pad) * 2 + pad), hexrgb("#0e1420"))
    for i in range(n):
        f = FIELDS[i % 5]
        b, _ = render_body(seed0 + i, f)
        por, _ = render(seed0 + i, f)
        x = pad + (i % 5) * cw
        y = pad + (i // 5) * (H * scale + pad)
        out.paste(por.resize((96 * scale // 2, 96 * scale // 2), Image.NEAREST), (x, y))
        big = b.resize((W * scale, H * scale), Image.NEAREST)
        out.paste(big, (x + 96 * scale // 2 + pad, y), big)
    return out


if __name__ == "__main__":
    sheet(int(sys.argv[1]) if len(sys.argv) > 1 else 100).save(sys.argv[2] if len(sys.argv) > 2 else "bodies_sheet.png")
    print("ok")
