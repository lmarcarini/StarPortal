"""Renders the interface reference images at 1920x1080 with PIL.

Every rectangle used here is listed in LAYOUT and written to layout.json, so the
spec, the reference images and the overlay come from one source.
"""
import json
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = sys.argv[1]
OUT = sys.argv[2]
W, H = 1920, 1080

F_LABEL = ROOT + "/art/fonts/barlow_condensed/BarlowCondensed-SemiBold.ttf"
F_LABEL_M = ROOT + "/art/fonts/barlow_condensed/BarlowCondensed-Medium.ttf"
F_MONO = ROOT + "/art/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf"
F_MONO_B = ROOT + "/art/fonts/ibm_plex_mono/IBMPlexMono-Bold.ttf"
PLATE = ROOT + "/art/plates/gate_hall.png"

C = {
    "steel_hi": (74, 75, 66), "steel": (46, 47, 41), "steel_lo": (30, 31, 27),
    "edge": (13, 14, 13), "bevel": (98, 99, 86), "text": (233, 228, 208),
    "dim": (156, 154, 136), "amber": (232, 163, 61), "amber_hi": (255, 217, 143),
    "amber_lo": (150, 96, 22), "green": (127, 214, 138), "crt_bg": (10, 22, 14),
    "red": (229, 83, 61), "blue": (63, 169, 245), "paper": (233, 228, 208),
    "ink": (26, 26, 22), "hazard": (232, 178, 36),
}

# x, y, w, h in screen pixels at 1920x1080.
LAYOUT = {
    "top_bar": (0, 0, 1920, 76),
    "top_site": (8, 8, 392, 60),
    "top_clock": (408, 8, 304, 60),
    "top_resources": (720, 8, 760, 60),
    "top_call": (1488, 8, 212, 60),
    "top_speed": (1708, 8, 204, 60),
    "wire": (16, 92, 368, 600),
    "team_card": (16, 716, 368, 148),
    "right_panel": (1536, 92, 368, 772),
    "send_rail": (1004, 764, 520, 100),
    "mission_sheet": (1184, 400, 336, 352),
    "bottom_bar": (0, 880, 1920, 200),
    "station_keys": (16, 896, 624, 168),
    "dest_crt": (656, 896, 400, 168),
    "dial_block": (1072, 896, 432, 168),
    "seal_lamps": (1088, 900, 400, 36),
    "main_key": (1088, 948, 400, 104),
    "charge_gauge": (1520, 896, 240, 168),
    "shutter": (1776, 896, 128, 168),
    "station_console": (656, 896, 848, 168),
    "gate_monitor": (1520, 896, 384, 168),
    "station_area": (400, 92, 1120, 772),
}


def font(path, size):
    return ImageFont.truetype(path, size)


def text(d, xy, s, f, fill, anchor="la", spacing=0):
    if spacing:
        x, y = xy
        if anchor[0] == "m":
            total = sum(d.textlength(ch, font=f) + spacing for ch in s) - spacing
            x -= total / 2
            anchor = "l" + anchor[1]
        for ch in s:
            d.text((x, y), ch, font=f, fill=fill, anchor=anchor)
            x += d.textlength(ch, font=f) + spacing
        return
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def vgrad(size, top, bottom):
    w, h = size
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return im


def noise_overlay(im, amount=10, seed=1):
    rnd = random.Random(seed)
    n = Image.new("L", im.size)
    n.putdata([128 + rnd.randint(-amount, amount) for _ in range(im.size[0] * im.size[1])])
    n = n.filter(ImageFilter.GaussianBlur(0.6))
    base = im.convert("RGB")
    return ImageChops.add(ImageChops.subtract(base, Image.merge("RGB", [n] * 3).point(lambda v: max(0, 128 - v))),
                          Image.merge("RGB", [n] * 3).point(lambda v: max(0, v - 128)))


def steel_plate(canvas, rect, bolts=True, radius=6, dark=False, seed=1):
    x, y, w, h = rect
    top = C["steel"] if not dark else C["steel_lo"]
    bot = C["steel_lo"] if not dark else (20, 21, 18)
    plate = vgrad((w, h), top, bot)
    plate = noise_overlay(plate, 7, seed)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    shadow = Image.new("L", (w + 24, h + 24), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((12, 16, w + 11, h + 15), radius, fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(7))
    canvas.paste((0, 0, 0), (x - 12, y - 12), shadow)
    canvas.paste(plate, (x, y), mask)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x, y, x + w - 1, y + h - 1), radius, outline=C["edge"], width=2)
    d.line((x + radius, y + 2, x + w - radius, y + 2), fill=C["bevel"], width=1)
    if bolts and w > 40 and h > 30:
        for bx, by in ((x + 9, y + 9), (x + w - 10, y + 9), (x + 9, y + h - 10), (x + w - 10, y + h - 10)):
            d.ellipse((bx - 3, by - 3, bx + 3, by + 3), fill=(18, 18, 16))
            d.point((bx - 1, by - 1), fill=(110, 110, 98))


def recess(canvas, rect, fill=(16, 17, 15)):
    x, y, w, h = rect
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x, y, x + w - 1, y + h - 1), 4, fill=fill, outline=C["edge"], width=2)
    d.line((x + 4, y + h - 2, x + w - 4, y + h - 2), fill=(70, 70, 62))


def glow(canvas, center, radius, color, strength=0.6):
    g = Image.new("RGB", canvas.size, (0, 0, 0))
    gd = ImageDraw.Draw(g)
    cx, cy = center
    gd.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=tuple(int(c * strength) for c in color))
    g = g.filter(ImageFilter.GaussianBlur(radius * 0.6))
    canvas.paste(ImageChops.add(canvas.convert("RGB"), g), (0, 0))


def lamp(canvas, center, r, on, color=None):
    color = color or C["amber"]
    cx, cy = center
    if on:
        glow(canvas, center, r * 2.2, color, 0.55)
    d = ImageDraw.Draw(canvas)
    d.ellipse((cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3), fill=C["edge"])
    if on:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
        d.ellipse((cx - r * 0.45, cy - r * 0.55, cx + r * 0.15, cy - r * 0.05), fill=C["amber_hi"] if color == C["amber"] else (220, 255, 225))
    else:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(58, 46, 26) if color == C["amber"] else (30, 44, 34))
        d.ellipse((cx - r * 0.4, cy - r * 0.5, cx, cy - r * 0.1), fill=(84, 70, 44))


def key(canvas, rect, label, style="steel", icon=None, sub=None, font_size=22):
    x, y, w, h = rect
    d = ImageDraw.Draw(canvas)
    if style == "amber":
        face = vgrad((w, h), (240, 180, 85), (185, 122, 30))
        glow(canvas, (x + w // 2, y + h // 2), max(w, h) * 0.55, C["amber"], 0.35)
        txt = (26, 20, 8)
        edge = (90, 60, 12)
    elif style == "hazard":
        face = Image.new("RGB", (w, h), (30, 28, 22))
        fd = ImageDraw.Draw(face)
        for k in range(-h, w + h, 34):
            fd.polygon([(k, 0), (k + 17, 0), (k + 17 + h, h), (k + h, h)], fill=C["hazard"])
        inner = (14, 14, w - 15, h - 15)
        fd.rounded_rectangle(inner, 4, fill=(54, 50, 42), outline=(10, 10, 9), width=2)
        txt = C["text"]
        edge = (10, 10, 9)
    elif style == "lit":
        face = vgrad((w, h), (90, 70, 36), (52, 40, 20))
        txt = C["amber"]
        edge = C["amber"]
    elif style == "off":
        face = Image.new("RGB", (w, h), (36, 37, 32))
        txt = (110, 110, 98)
        edge = C["edge"]
    else:
        face = vgrad((w, h), (78, 79, 69), (44, 45, 40))
        txt = C["text"]
        edge = C["edge"]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), 6, fill=255)
    d.rounded_rectangle((x, y + 4, x + w - 1, y + h + 3), 6, fill=(8, 8, 7))
    canvas.paste(face, (x, y), mask)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x, y, x + w - 1, y + h - 1), 6, outline=edge, width=2 if style != "lit" else 3)
    if style in ("steel", "amber"):
        d.line((x + 6, y + 2, x + w - 6, y + 2), fill=(255, 225, 160) if style == "amber" else (120, 121, 106), width=2)
    cy = y + h // 2
    if icon:
        size = min(w, h) * 0.42
        iy = y + h * 0.40 if label else cy
        draw_icon(d, icon, (x + w / 2, iy), size, txt)
        if label:
            text(d, (x + w / 2, y + h - 14), label, font(F_LABEL, font_size), txt, "ms", 2)
    else:
        text(d, (x + w / 2, cy + 2), label, font(F_LABEL, font_size), txt, "mm", 3)
    if sub:
        text(d, (x + w - 8, y + 8), sub, font(F_MONO_B, 15), txt, "ra")


def draw_icon(d, name, c, s, col, width=3):
    x, y = c
    r = s / 2
    L = lambda *p: d.line(p, fill=col, width=width, joint="curve")
    E = lambda bx: d.ellipse(bx, outline=col, width=width)
    if name == "gate":
        E((x - r, y - r, x + r, y + r)); E((x - r * 0.62, y - r * 0.62, x + r * 0.62, y + r * 0.62))
        for a in range(0, 360, 45):
            t = math.radians(a)
            L((x + r * 0.62 * math.sin(t), y - r * 0.62 * math.cos(t)), (x + r * math.sin(t), y - r * math.cos(t)))
    elif name == "base":
        d.rectangle((x - r, y - r * 0.2, x + r, y + r), outline=col, width=width)
        L((x - r, y - r * 0.2), (x, y - r), (x + r, y - r * 0.2))
        d.rectangle((x - r * 0.3, y + r * 0.3, x + r * 0.3, y + r), outline=col, width=width)
    elif name == "lab":
        L((x - r * 0.35, y - r), (x + r * 0.35, y - r))
        L((x - r * 0.2, y - r), (x - r * 0.2, y - r * 0.2), (x - r, y + r), (x + r, y + r), (x + r * 0.2, y - r * 0.2), (x + r * 0.2, y - r))
        L((x - r * 0.6, y + r * 0.35), (x + r * 0.6, y + r * 0.35))
    elif name == "office":
        d.rectangle((x - r, y - r * 0.5, x + r, y + r), outline=col, width=width)
        L((x - r, y - r * 0.5), (x - r * 0.6, y - r), (x - r * 0.05, y - r), (x + r * 0.2, y - r * 0.5))
    elif name == "camera":
        d.rounded_rectangle((x - r, y - r * 0.55, x + r * 0.45, y + r * 0.55), 4, outline=col, width=width)
        L((x + r * 0.45, y - r * 0.2), (x + r, y - r * 0.5), (x + r, y + r * 0.5), (x + r * 0.45, y + r * 0.2))
        E((x - r * 0.55, y - r * 0.3, x + r * 0.05, y + r * 0.3))
    elif name == "canister":
        d.rounded_rectangle((x - r * 0.45, y - r, x + r * 0.45, y + r), 8, outline=col, width=width)
        L((x - r * 0.45, y - r * 0.35), (x + r * 0.45, y - r * 0.35)); L((x - r * 0.45, y + r * 0.35), (x + r * 0.45, y + r * 0.35))
    elif name == "moth":
        L((x, y - r * 0.6), (x, y + r * 0.8))
        d.polygon([(x, y - r * 0.2), (x - r, y - r * 0.7), (x - r * 0.75, y + r * 0.35), (x, y + r * 0.15)], outline=col)
        d.polygon([(x, y - r * 0.2), (x + r, y - r * 0.7), (x + r * 0.75, y + r * 0.35), (x, y + r * 0.15)], outline=col)
    elif name == "team":
        for dx in (-0.45, 0.45):
            E((x + r * dx - r * 0.28, y - r * 0.85, x + r * dx + r * 0.28, y - r * 0.3))
            d.arc((x + r * dx - r * 0.55, y - r * 0.1, x + r * dx + r * 0.55, y + r * 1.5), 180, 360, fill=col, width=width)
    elif name == "hail":
        d.arc((x - r, y - r, x + r, y + r), 200, 340, fill=col, width=width)
        d.arc((x - r * 0.6, y - r * 0.6, x + r * 0.6, y + r * 0.6), 200, 340, fill=col, width=width)
        E((x - r * 0.18, y - r * 0.05, x + r * 0.18, y + r * 0.3))
        L((x, y + r * 0.3), (x, y + r))
    elif name == "funds":
        text(d, (x, y), "$", font(F_LABEL, int(s * 1.1)), col, "mm")
    elif name == "power":
        d.polygon([(x + r * 0.15, y - r), (x - r * 0.55, y + r * 0.1), (x - r * 0.05, y + r * 0.1),
                   (x - r * 0.2, y + r), (x + r * 0.55, y - r * 0.15), (x + r * 0.05, y - r * 0.15)], fill=col)
    elif name == "charge":
        d.rectangle((x - r * 0.75, y - r * 0.55, x + r * 0.6, y + r * 0.55), outline=col, width=width)
        d.rectangle((x + r * 0.6, y - r * 0.2, x + r * 0.85, y + r * 0.2), fill=col)
        d.rectangle((x - r * 0.55, y - r * 0.35, x + r * 0.15, y + r * 0.35), fill=col)
    elif name == "confidence":
        d.polygon([(x - r * 0.8, y - r * 0.7), (x + r * 0.8, y - r * 0.7), (x + r * 0.8, y + r * 0.1),
                   (x, y + r), (x - r * 0.8, y + r * 0.1)], outline=col, width=width)
        L((x - r * 0.35, y - r * 0.05), (x - r * 0.05, y + r * 0.3), (x + r * 0.4, y - r * 0.35))
    elif name == "phone":
        d.arc((x - r, y - r * 0.4, x + r, y + r * 1.2), 200, 340, fill=col, width=width + 3)
        d.rounded_rectangle((x - r * 0.65, y - r * 0.05, x + r * 0.65, y + r), 5, outline=col, width=width)
    elif name == "clock":
        E((x - r, y - r, x + r, y + r)); L((x, y), (x, y - r * 0.6)); L((x, y), (x + r * 0.45, y + r * 0.2))
    elif name == "pause":
        d.rectangle((x - r * 0.55, y - r * 0.7, x - r * 0.15, y + r * 0.7), fill=col)
        d.rectangle((x + r * 0.15, y - r * 0.7, x + r * 0.55, y + r * 0.7), fill=col)
    elif name == "play":
        d.polygon([(x - r * 0.45, y - r * 0.7), (x + r * 0.6, y), (x - r * 0.45, y + r * 0.7)], fill=col)
    elif name == "fast":
        d.polygon([(x - r * 0.8, y - r * 0.6), (x, y), (x - r * 0.8, y + r * 0.6)], fill=col)
        d.polygon([(x, y - r * 0.6), (x + r * 0.8, y), (x, y + r * 0.6)], fill=col)
    elif name == "gear":
        for a in range(0, 360, 45):
            t = math.radians(a)
            L((x + r * 0.55 * math.cos(t), y + r * 0.55 * math.sin(t)), (x + r * math.cos(t), y + r * math.sin(t)))
        E((x - r * 0.62, y - r * 0.62, x + r * 0.62, y + r * 0.62)); E((x - r * 0.22, y - r * 0.22, x + r * 0.22, y + r * 0.22))
    elif name == "eye":
        d.arc((x - r, y - r * 0.9, x + r, y + r * 0.9), 200, 340, fill=col, width=width)
        d.arc((x - r, y - r * 0.9, x + r, y + r * 0.9), 20, 160, fill=col, width=width)
        d.ellipse((x - r * 0.25, y - r * 0.25, x + r * 0.25, y + r * 0.25), fill=col)
    elif name == "person":
        E((x - r * 0.35, y - r, x + r * 0.35, y - r * 0.3))
        d.arc((x - r * 0.75, y - r * 0.1, x + r * 0.75, y + r * 1.6), 180, 360, fill=col, width=width)
    elif name == "threat":
        d.polygon([(x, y - r), (x + r, y + r * 0.8), (x - r, y + r * 0.8)], outline=col, width=width)
        L((x, y - r * 0.3), (x, y + r * 0.25)); d.ellipse((x - 2, y + r * 0.45, x + 2, y + r * 0.6), fill=col)
    elif name == "flask_idle":
        draw_icon(d, "lab", c, s, col, width)
    elif name == "candidate":
        draw_icon(d, "person", c, s, col, width)
    elif name == "arrow":
        L((x - r * 0.7, y), (x + r * 0.7, y)); L((x + r * 0.2, y - r * 0.5), (x + r * 0.7, y), (x + r * 0.2, y + r * 0.5))
    elif name == "check":
        L((x - r * 0.7, y), (x - r * 0.15, y + r * 0.55), (x + r * 0.75, y - r * 0.55))
    elif name == "cross":
        L((x - r * 0.6, y - r * 0.6), (x + r * 0.6, y + r * 0.6)); L((x - r * 0.6, y + r * 0.6), (x + r * 0.6, y - r * 0.6))
    elif name == "plus":
        L((x - r * 0.7, y), (x + r * 0.7, y)); L((x, y - r * 0.7), (x, y + r * 0.7))
    elif name == "list":
        for k in (-0.5, 0, 0.5):
            L((x - r * 0.7, y + r * k), (x + r * 0.7, y + r * k))


def backdrop(opened):
    plate = Image.open(PLATE).convert("RGB")
    scale = max(W / plate.width, H / plate.height)
    plate = plate.resize((math.ceil(plate.width * scale), math.ceil(plate.height * scale)), Image.LANCZOS)
    ox = (plate.width - W) // 2
    oy = (plate.height - H) // 2
    im = plate.crop((ox, oy, ox + W, oy + H))
    cx, cy = 836 * scale - ox, 390 * scale - oy
    r_in, r_out = 146 * scale, 186 * scale
    if opened:
        hz = Image.new("RGB", (W, H), (0, 0, 0))
        rnd = random.Random(4)
        px = hz.load()
        for yy in range(int(cy - r_in), int(cy + r_in) + 1):
            for xx in range(int(cx - r_in), int(cx + r_in) + 1):
                dx, dy = xx - cx, yy - cy
                dist = math.hypot(dx, dy) / r_in
                if dist > 1:
                    continue
                ang = math.atan2(dy, dx)
                wave = 0.5 + 0.5 * math.sin(dist * 22 - ang * 3 + math.sin(ang * 5) * 1.4)
                core = max(0.0, 1 - dist) ** 1.6
                b = 0.35 + 0.35 * wave * (0.4 + dist * 0.6) + 0.55 * core
                px[xx, yy] = (int(min(255, 40 + 190 * b)), int(min(255, 110 + 150 * b)), int(min(255, 190 + 70 * b)))
        hz = hz.filter(ImageFilter.GaussianBlur(1.6))
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).ellipse((cx - r_in, cy - r_in, cx + r_in, cy + r_in), fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(1.5))
        light = Image.new("RGB", (W, H), (0, 0, 0))
        ld = ImageDraw.Draw(light)
        ld.ellipse((cx - r_out * 2.2, cy - r_out * 1.6, cx + r_out * 2.2, cy + r_out * 1.6), fill=(14, 52, 96))
        ld.ellipse((cx - r_out * 1.9, H * 0.68, cx + r_out * 1.9, H * 0.98), fill=(18, 60, 110))
        light = light.filter(ImageFilter.GaussianBlur(120))
        im = ImageChops.add(Image.eval(im, lambda v: int(v * 0.86)), light)
        im.paste(hz, (0, 0), mask)
        glow(im, (int(cx), int(cy)), r_in * 1.05, (60, 150, 240), 0.35)
    else:
        im = Image.eval(im, lambda v: int(v * 0.92))
    d = ImageDraw.Draw(im)
    rl = (r_in + r_out) / 2
    for i in range(8):
        a = math.radians(i * 45)
        lx, ly = cx + rl * math.sin(a), cy - rl * math.cos(a)
        lamp(im, (int(lx), int(ly)), 9, opened)
    return im, (cx, cy, r_in, r_out)


def top_bar(im, call=True):
    d = ImageDraw.Draw(im)
    band = vgrad((W, 76), (24, 25, 22), (14, 15, 13))
    im.paste(band, (0, 0))
    d.line((0, 75, W, 75), fill=C["edge"], width=2)
    steel_plate(im, LAYOUT["top_site"], seed=2)
    x, y, w, h = LAYOUT["top_site"]
    draw_icon(d, "gate", (x + 36, y + 30), 34, C["amber"])
    text(d, (x + 66, y + 9), "SITE CAIRN", font(F_LABEL, 28), C["text"], "la", 3)
    text(d, (x + 67, y + 41), "RING PROGRAMME · LEVEL 27", font(F_LABEL_M, 15), C["dim"], "la", 2)
    steel_plate(im, LAYOUT["top_clock"], seed=3)
    x, y, w, h = LAYOUT["top_clock"]
    draw_icon(d, "clock", (x + 32, y + 30), 30, C["text"])
    text(d, (x + 60, y + 8), "02 JAN 1997", font(F_LABEL, 26), C["text"], "la", 2)
    text(d, (x + 60, y + 36), "07:01", font(F_MONO_B, 18), C["amber"])
    lamp(im, (x + w - 28, y + 30), 7, False, C["green"])
    steel_plate(im, LAYOUT["top_resources"], seed=4)
    x, y, w, h = LAYOUT["top_resources"]
    cells = [("funds", "$5,494k", "+100/d", C["green"]), ("power", "30/30", "MW", C["dim"]),
             ("charge", "400", "MWh", C["dim"]), ("confidence", "63", "-0.1", C["red"])]
    widths = [240, 180, 160, 180]
    for i, (ic, val, delta, dc) in enumerate(cells):
        cx0 = x + sum(widths[:i])
        if i:
            d.line((cx0, y + 10, cx0, y + h - 10), fill=C["edge"], width=2)
        draw_icon(d, ic, (cx0 + 30, y + 30), 26, C["amber"] if ic in ("power", "charge") else C["text"])
        text(d, (cx0 + 54, y + 30), val, font(F_MONO_B, 24), C["text"], "lm")
        vw = d.textlength(val, font=font(F_MONO_B, 24))
        text(d, (cx0 + 60 + vw, y + 32), delta, font(F_MONO, 16), dc, "lm")
    steel_plate(im, LAYOUT["top_call"], seed=5)
    x, y, w, h = LAYOUT["top_call"]
    lamp(im, (x + 26, y + 30), 9, call)
    draw_icon(d, "phone", (x + 58, y + 28), 26, C["amber"] if call else C["dim"])
    text(d, (x + 82, y + 30), "COMMITTEE" if call else "NO CALL", font(F_LABEL, 22), C["amber"] if call else C["dim"], "lm", 2)
    steel_plate(im, LAYOUT["top_speed"], seed=6)
    x, y, w, h = LAYOUT["top_speed"]
    key(im, (x + 8, y + 8, 44, 44), "", "steel", "pause")
    key(im, (x + 56, y + 8, 44, 44), "", "steel", "play")
    key(im, (x + 104, y + 8, 44, 44), "", "amber", "fast")
    key(im, (x + 152, y + 8, 44, 44), "", "steel", "gear")


def wire(im, cards):
    x, y, w, h = LAYOUT["wire"]
    yy = y
    d = ImageDraw.Draw(im)
    for ic, title, sub, stripe, actions in cards:
        rect = (x, yy, w, 96)
        steel_plate(im, rect, bolts=False, radius=4, dark=True, seed=yy)
        d = ImageDraw.Draw(im)
        d.rectangle((x + 2, yy + 2, x + 7, yy + 93), fill=stripe)
        draw_icon(d, ic, (x + 40, yy + 48), 34, stripe)
        text(d, (x + 70, yy + 22), title, font(F_LABEL, 22), C["text"], "la", 2)
        text(d, (x + 70, yy + 52), sub, font(F_LABEL_M, 17), C["dim"], "la", 1)
        ax = x + w - 12
        for a in reversed(actions):
            ax -= 52
            key(im, (ax, yy + 22, 52 - 6, 52), "", "amber" if a in ("check", "arrow") else "steel", a)
        yy += 106
    key(im, (x, yy, 120, 44), "+12", "steel", None, font_size=20)


def team_card(im):
    x, y, w, h = LAYOUT["team_card"]
    d = ImageDraw.Draw(im)
    paper = vgrad((w, h), (236, 231, 212), (214, 208, 186))
    paper = noise_overlay(paper, 6, 9)
    d.rectangle((x + 4, y + 6, x + w + 3, y + h + 5), fill=(0, 0, 0))
    im.paste(paper, (x, y))
    d = ImageDraw.Draw(im)
    d.rectangle((x, y, x + w - 1, y + h - 1), outline=(120, 112, 90), width=1)
    d.rectangle((x, y, x + 7, y + h - 1), fill=C["amber"])
    text(d, (x + 22, y + 14), "T-1 · SURVEY · SILL", font(F_LABEL, 24), C["ink"], "la", 2)
    for i, col in enumerate([(150, 106, 72), (110, 122, 94), (154, 118, 86), (94, 106, 122)]):
        fx = x + 22 + i * 62
        d.rectangle((fx, y + 52, fx + 52, y + 104), fill=col, outline=C["ink"], width=2)
        d.ellipse((fx + 16, y + 60, fx + 36, y + 80), fill=(214, 190, 160))
        d.pieslice((fx + 8, y + 82, fx + 44, y + 118), 180, 360, fill=(54, 60, 50))
    cxr, cyr, rr = x + w - 54, y + 78, 34
    d.ellipse((cxr - rr, cyr - rr, cxr + rr, cyr + rr), outline=(160, 150, 125), width=6)
    d.arc((cxr - rr, cyr - rr, cxr + rr, cyr + rr), -90, 130, fill=C["amber_lo"], width=6)
    text(d, (cxr, cyr), "1D 6H", font(F_MONO_B, 14), C["ink"], "mm")
    text(d, (x + 22, y + h - 14), "DUE 04 JAN", font(F_LABEL_M, 16), (90, 84, 66), "ls", 1)


def world_pic(size, hue, seed):
    w, h = size
    rnd = random.Random(seed)
    sky = vgrad((w, h), tuple(int(c * 0.9) for c in hue), tuple(min(255, int(c * 1.35)) for c in hue))
    d = ImageDraw.Draw(sky)
    base = h * 0.62
    pts = [(0, h)]
    for k in range(0, w + 20, 20):
        pts.append((k, base - rnd.randint(0, int(h * 0.28))))
    pts.append((w, h))
    d.polygon(pts, fill=tuple(int(c * 0.45) for c in hue))
    d.rectangle((0, h * 0.8, w, h), fill=tuple(int(c * 0.3) for c in hue))
    d.ellipse((w * 0.72, h * 0.12, w * 0.72 + h * 0.16, h * 0.28), fill=(240, 236, 220))
    return noise_overlay(sky, 8, seed)


def right_panel(im, opened):
    x, y, w, h = LAYOUT["right_panel"]
    steel_plate(im, (x, y, w, h), seed=11)
    d = ImageDraw.Draw(im)
    draw_icon(d, "gate", (x + 28, y + 28), 24, C["amber"])
    text(d, (x + 50, y + 28), "DESTINATIONS", font(F_LABEL, 24), C["text"], "lm", 3)
    recess(im, (x + 14, y + 56, w - 28, 290))
    pic = world_pic((w - 40, 180), (160, 120, 96), 3)
    im.paste(pic, (x + 20, y + 62))
    d = ImageDraw.Draw(im)
    d.rectangle((x + 20, y + 62, x + w - 21, y + 241), outline=C["amber"] if not opened else C["blue"], width=3)
    text(d, (x + 24, y + 256), "SILL", font(F_LABEL, 34), C["text"], "la", 3)
    text(d, (x + 26, y + 296), "LOCKED 3× · LAST 2D AGO", font(F_LABEL_M, 16), C["dim"], "la", 1)
    for i, (ic, col) in enumerate((("eye", C["green"]), ("person", C["green"]), ("threat", C["amber"]))):
        draw_icon(d, ic, (x + w - 108 + i * 34, y + 274), 22, col)
    cards = [("SILL", (160, 120, 96), True), ("LINTEL", (120, 104, 140), False),
             ("STILLWATER", (90, 120, 150), False), ("MOORING", (150, 110, 70), False)]
    cw, ch = (w - 40) // 2, 132
    for i, (n, hue, sel) in enumerate(cards):
        cx0 = x + 14 + (i % 2) * (cw + 12)
        cy0 = y + 362 + (i // 2) * (ch + 12)
        recess(im, (cx0, cy0, cw, ch))
        im.paste(world_pic((cw - 12, ch - 42), hue, 10 + i), (cx0 + 6, cy0 + 6))
        d = ImageDraw.Draw(im)
        if sel:
            d.rectangle((cx0, cy0, cx0 + cw - 1, cy0 + ch - 1), outline=C["amber"], width=3)
        text(d, (cx0 + 10, cy0 + ch - 20), n, font(F_LABEL, 20), C["text"], "lm", 2)
        for k in range(3 if i == 0 else 1 + i % 3):
            d.ellipse((cx0 + cw - 16 - k * 12, cy0 + ch - 24, cx0 + cw - 8 - k * 12, cy0 + ch - 16), fill=C["dim"])
    key(im, (x + 14, y + h - 80, w - 28, 64), "+  NEW ADDRESS", "steel", font_size=24)


def bottom_bar(im, station, opened):
    x, y, w, h = LAYOUT["bottom_bar"]
    band = vgrad((w, h), (40, 41, 36), (18, 19, 16))
    band = noise_overlay(band, 6, 21)
    im.paste(band, (x, y))
    d = ImageDraw.Draw(im)
    d.rectangle((0, y, W, y + 6), fill=(64, 65, 57))
    d.line((0, y, W, y), fill=C["edge"], width=3)
    for k in range(0, W, 34):
        d.polygon([(k, y + 6), (k + 17, y + 6), (k + 23, y + 12), (k + 6, y + 12)], fill=(48, 44, 30))
    sx, sy, sw, sh = LAYOUT["station_keys"]
    for i, (ic, label) in enumerate((("gate", "GATE"), ("base", "BASE"), ("lab", "LAB"), ("office", "OFFICE"))):
        kx = sx + i * 158
        on = label.lower() == station
        key(im, (kx, sy, 148, sh), label, "amber" if on else "steel", ic, font_size=26)
        if label == "OFFICE":
            lamp(im, (kx + 128, sy + 18), 6, True, C["red"])
    if station == "gate":
        crt(im, LAYOUT["dest_crt"], opened)
        dial_block(im, opened)
        gauge(im, LAYOUT["charge_gauge"], 0.78 if not opened else 0.42, opened)
        shutter(im, LAYOUT["shutter"])
    else:
        console = LAYOUT["station_console"]
        steel_plate(im, console, seed=31)
        dd = ImageDraw.Draw(im)
        text(dd, (console[0] + console[2] // 2, console[1] + console[3] // 2),
             "STATION CONSOLE (per station: Base = build tray)", font(F_LABEL_M, 20), C["dim"], "mm", 2)
        gate_monitor(im, LAYOUT["gate_monitor"])


def crt(im, rect, opened):
    x, y, w, h = rect
    steel_plate(im, rect, seed=41)
    inner = (x + 12, y + 12, w - 24, h - 24)
    ix, iy, iw, ih = inner
    scr = Image.new("RGB", (iw, ih), C["crt_bg"])
    sd = ImageDraw.Draw(scr)
    pic = world_pic((150, ih - 24), (70, 140, 90), 3).convert("L")
    scr.paste(Image.merge("RGB", [pic.point(lambda v: v * 0.35), pic.point(lambda v: v * 0.9), pic.point(lambda v: v * 0.45)]), (12, 12))
    sd.rectangle((12, 12, 161, ih - 13), outline=C["green"], width=2)
    text(sd, (178, 18), "SILL", font(F_LABEL, 38), C["green"], "la", 4)
    for i, ic in enumerate(("eye", "person", "threat")):
        draw_icon(sd, ic, (190 + i * 40, 86), 24, C["green"] if ic != "threat" else C["amber"])
    for k in range(7):
        sd.rectangle((178 + k * 26, ih - 34, 200 + k * 26, ih - 12), outline=C["green"], width=2)
        draw_icon(sd, "plus" if k % 2 else "cross", (189 + k * 26, ih - 23), 10, C["green"], 2)
    for yy in range(0, ih, 3):
        sd.line((0, yy, iw, yy), fill=(0, 0, 0), width=1)
    scr = Image.blend(scr, scr.filter(ImageFilter.GaussianBlur(2)), 0.35)
    im.paste(scr, (ix, iy))
    glow(im, (ix + iw // 2, iy + ih // 2), iw * 0.35, C["green"], 0.10)
    ImageDraw.Draw(im).rounded_rectangle((ix, iy, ix + iw - 1, iy + ih - 1), 10, outline=C["edge"], width=4)


def dial_block(im, opened):
    steel_plate(im, LAYOUT["dial_block"], seed=51)
    x, y, w, h = LAYOUT["seal_lamps"]
    for i in range(8):
        lamp(im, (x + 25 + i * 50, y + 18), 10, opened or i < 0, C["amber"])
    if opened:
        key(im, LAYOUT["main_key"], "CLOSE", "hazard", font_size=46)
    else:
        key(im, LAYOUT["main_key"], "DIAL", "amber", font_size=50)


def gauge(im, rect, value, opened):
    x, y, w, h = rect
    steel_plate(im, rect, seed=61)
    d = ImageDraw.Draw(im)
    fx, fy, fw, fh = x + 14, y + 12, w - 28, h - 50
    face = vgrad((fw, fh), (236, 230, 208), (206, 198, 172))
    im.paste(face, (fx, fy))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((fx, fy, fx + fw - 1, fy + fh - 1), 8, outline=C["edge"], width=3)
    cx, cy, r = fx + fw / 2, fy + fh - 14, fh - 30
    for k in range(11):
        a = math.radians(200 + k * 14)
        d.line((cx + (r - 10) * math.cos(a), cy + (r - 10) * math.sin(a), cx + r * math.cos(a), cy + r * math.sin(a)),
               fill=C["ink"], width=2)
    d.arc((cx - r, cy - r, cx + r, cy + r), 200, 228, fill=C["red"], width=8)
    a = math.radians(200 + value * 140)
    d.line((cx, cy, cx + (r - 6) * math.cos(a), cy + (r - 6) * math.sin(a)), fill=C["ink"], width=4)
    d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=C["ink"])
    text(d, (cx, cy - 34), "MWh", font(F_LABEL, 20), C["ink"], "mm", 2)
    text(d, (x + 18, y + h - 20), "400" if not opened else "262", font(F_MONO_B, 20), C["text"], "lm")
    text(d, (x + w - 18, y + h - 20), "−20/H" if opened else "", font(F_LABEL_M, 18), C["red"] if opened else C["dim"], "rm", 1)


def shutter(im, rect):
    x, y, w, h = rect
    steel_plate(im, rect, seed=71)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((x + w / 2 - 12, y + 20, x + w / 2 + 12, y + h - 48), 12, fill=(10, 10, 9))
    key(im, (int(x + w / 2 - 34), y + 26, 68, 40), "", "steel")
    text(d, (x + w / 2, y + h - 22), "SHUTTER", font(F_LABEL, 20), C["dim"], "mm", 2)


def gate_monitor(im, rect):
    x, y, w, h = rect
    steel_plate(im, rect, seed=81)
    ix, iy, iw, ih = x + 12, y + 12, w - 24, h - 24
    scr = Image.new("RGB", (iw, ih), (6, 10, 14))
    sd = ImageDraw.Draw(scr)
    cx, cy, r = iw * 0.62, ih / 2, ih * 0.36
    sd.ellipse((cx - r - 10, cy - r - 10, cx + r + 10, cy + r + 10), outline=(90, 96, 92), width=10)
    sd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(60, 150, 230))
    sd.ellipse((cx - r * 0.5, cy - r * 0.5, cx + r * 0.3, cy + r * 0.3), fill=(170, 220, 255))
    text(sd, (14, 16), "GATE", font(F_LABEL, 22), C["green"], "la", 3)
    text(sd, (14, 46), "OPEN · SILL", font(F_LABEL_M, 18), C["blue"], "la", 2)
    text(sd, (14, ih - 18), "0:42", font(F_MONO_B, 20), C["text"], "lm")
    for yy in range(0, ih, 3):
        sd.line((0, yy, iw, yy), fill=(0, 0, 0))
    im.paste(scr, (ix, iy))
    ImageDraw.Draw(im).rounded_rectangle((ix, iy, ix + iw - 1, iy + ih - 1), 10, outline=C["edge"], width=4)


def send_rail(im):
    x, y, w, h = LAYOUT["send_rail"]
    items = [("camera", "CAMERA", "off", "✓"), ("canister", "CANISTER", "steel", None), ("moth", "MOTH", "steel", "2"),
             ("team", "TEAM", "lit", None), ("hail", "HAIL", "steel", None)]
    for i, (ic, label, st, badge) in enumerate(items):
        kx = x + i * 106
        key(im, (kx, y, 96, h), label, st, ic, font_size=18)
        if badge:
            d = ImageDraw.Draw(im)
            d.ellipse((kx + 72, y - 10, kx + 100, y + 18), fill=C["paper"], outline=C["edge"], width=2)
            text(d, (kx + 86, y + 4), badge if badge != "✓" else "✓", font(F_MONO_B, 15), C["ink"], "mm")


def mission_sheet(im):
    x, y, w, h = LAYOUT["mission_sheet"]
    d = ImageDraw.Draw(im)
    paper = noise_overlay(vgrad((w, h), (236, 231, 212), (218, 212, 190)), 6, 12)
    d.rectangle((x + 6, y + 8, x + w + 5, y + h + 7), fill=(0, 0, 0))
    im.paste(paper, (x, y))
    d = ImageDraw.Draw(im)
    d.rectangle((x, y, x + w - 1, y + h - 1), outline=(120, 112, 90), width=1)
    text(d, (x + 16, y + 14), "MISSION · SILL", font(F_LABEL, 26), C["ink"], "la", 3)
    for i, (ic, lab, sel) in enumerate((("eye", "SURVEY", True), ("canister", "RECOVER", False), ("hail", "CONTACT", False))):
        kx = x + 16 + i * 104
        d.rounded_rectangle((kx, y + 54, kx + 96, y + 132), 6, fill=(250, 246, 232) if not sel else (250, 226, 170),
                            outline=C["amber_lo"] if sel else (150, 140, 116), width=3 if sel else 2)
        draw_icon(d, ic, (kx + 48, y + 82), 28, C["ink"])
        text(d, (kx + 48, y + 120), lab, font(F_LABEL, 16), C["ink"], "mm", 1)
    for i, col in enumerate([(150, 106, 72), (110, 122, 94), (154, 118, 86), (94, 106, 122)]):
        fx = x + 16 + i * 78
        d.rectangle((fx, y + 148, fx + 68, y + 216), fill=col, outline=C["ink"], width=2)
        d.ellipse((fx + 22, y + 156, fx + 46, y + 180), fill=(214, 190, 160))
        d.pieslice((fx + 12, y + 182, fx + 56, y + 226), 180, 360, fill=(54, 60, 50))
    text(d, (x + 16, y + 262), "2", font(F_MONO_B, 44), C["ink"], "lm")
    text(d, (x + 52, y + 266), "DAYS", font(F_LABEL, 18), (90, 84, 66), "lm", 2)
    key(im, (x + w - 176, y + h - 84, 160, 68), "GO", "hazard", font_size=36)


def overlay(name, station, opened):
    im = Image.new("RGB", (W, H), (20, 22, 24))
    d = ImageDraw.Draw(im)
    keys = ["top_bar", "top_site", "top_clock", "top_resources", "top_call", "top_speed", "wire", "team_card",
            "bottom_bar", "station_keys"]
    keys += (["right_panel", "dest_crt", "dial_block", "seal_lamps", "main_key", "charge_gauge", "shutter"]
             if station == "gate" else ["station_area", "station_console", "gate_monitor"])
    if opened:
        keys += ["send_rail", "mission_sheet"]
    for k in keys:
        x, y, w, h = LAYOUT[k]
        d.rectangle((x, y, x + w - 1, y + h - 1), outline=(232, 163, 61), width=2)
        text(d, (x + 6, y + 4), f"{k}  {x},{y}  {w}×{h}", font(F_MONO, 13), (232, 228, 208))
    im.save(f"{OUT}/{name}")


def compose(name, station, opened, with_sheet=False):
    if station == "gate":
        im, _ = backdrop(opened)
    else:
        im = Image.new("RGB", (W, H), (22, 24, 23))
        d = ImageDraw.Draw(im)
        x, y, w, h = LAYOUT["station_area"]
        for gx in range(x, x + w, 32):
            d.line((gx, y, gx, y + h), fill=(30, 33, 32))
        for gy in range(y, y + h, 32):
            d.line((x, gy, x + w, gy), fill=(30, 33, 32))
        text(d, (x + w // 2, y + h // 2), "STATION CONTENT (3D scene or plan)", font(F_LABEL_M, 28), (80, 84, 80), "mm", 3)
    top_bar(im)
    wire(im, [
        ("lab", "LAB IDLE", "Research Lab · 2 scientists", C["amber"], ["arrow"]),
        ("candidate", "CANDIDATE", "Engineer · skill 3", C["green"], ["check", "cross"]),
        ("phone", "CALL WAITING", "The Committee", C["amber"], ["check", "cross"]),
    ])
    if station == "gate":
        team_card(im)
        right_panel(im, opened)
        if opened:
            send_rail(im)
            if with_sheet:
                mission_sheet(im)
    bottom_bar(im, station, opened)
    vign = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vign).ellipse((-300, -200, W + 300, H + 200), fill=255)
    vign = vign.filter(ImageFilter.GaussianBlur(160))
    im = Image.composite(im, Image.eval(im, lambda v: int(v * 0.75)), vign)
    im.save(f"{OUT}/{name}")


compose("ref_gate_idle.png", "gate", False)
compose("ref_gate_open.png", "gate", True, with_sheet=True)
compose("ref_other_station.png", "base", False)
overlay("overlay_gate_idle.png", "gate", False)
overlay("overlay_gate_open.png", "gate", True)
overlay("overlay_other_station.png", "base", False)
with open(f"{OUT}/layout.json", "w") as fh:
    json.dump({k: {"x": v[0], "y": v[1], "w": v[2], "h": v[3]} for k, v in LAYOUT.items()}, fh, indent=1)
print("ok")
