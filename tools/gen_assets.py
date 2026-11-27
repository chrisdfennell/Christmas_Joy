#!/usr/bin/env python
"""
Generate the Christmas Joy store images (adapted from PassedNote's gen_assets.py):

    assets/app_icon_24bit.png    128x128   the wreath and snow globe as an icon
    assets/app_icon_64color.png  128x128   the same, quantized to 64 colours
    assets/cover_image.png/.jpg  500x500   square promo: the real face on blush
    assets/hero_image.png        1440x720  wide banner: title, features, day + night faces

Everything uses the face's own look (Blush & Gold colours, Great Vibes and
Quicksand) and the real simulator captures, so the store art matches the watch:

    assets/screen_day.png     daytime capture   (savescreenshot.ps1 -Name screen_day)
    assets/screen_night.png   night capture     (savescreenshot.ps1 -Name screen_night)
    assets/screen_active.png  fallback for either one (plain savescreenshot.ps1)

Run after capturing fresh screenshots:

    python tools/gen_assets.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
FONTS = os.path.join(ROOT, "fonts-src")

# Blush & Gold, as in source/ChristmasJoyView.mc
BLUSH = (243, 203, 211)
BLUSH_LIGHT = (251, 236, 240)
PLUM = (44, 33, 66)
BERRY = (142, 53, 83)
ROSE = (181, 84, 110)
GOLD = (216, 174, 94)
GOLD_DEEP = (168, 122, 50)
CREAM = (255, 243, 227)
SAGE_DARK = (69, 96, 77)
SAGE = (95, 127, 104)
SAGE_LIGHT = (126, 156, 131)
SAGE_PALE = (163, 189, 166)
BOW = (217, 119, 143)
BOW_DARK = (174, 86, 111)
WHITE = (255, 255, 255)


def font(name, size, wght=None):
    f = ImageFont.truetype(os.path.join(FONTS, name), size)
    if wght:
        f.set_variation_by_axes([wght])
    return f


def script(size):
    return font("GreatVibes-Regular.ttf", size)


def sans(size, wght=700):
    return font("Quicksand.ttf", size, wght)


def fit(d, make, text, start, maxw):
    """Largest font from make(size) <= start whose text fits in maxw."""
    size = start
    while size > 10:
        f = make(size)
        if d.textlength(text, font=f) <= maxw:
            return f
        size -= 2
    return make(10)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size, top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def twinkle(d, x, y, s, color):
    k = s * 0.28
    d.polygon([(x, y - s), (x + k, y - k), (x + s, y), (x + k, y + k),
               (x, y + s), (x - k, y + k), (x - s, y), (x - k, y - k)], fill=color)


def snowfall(img, count, seed, rmin=1.5, rmax=4.0, keep_out=None):
    """Soft white snow dots, kept out of (x1, y1, x2, y2) boxes."""
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    w, h = img.size
    for _ in range(count):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        if keep_out and any(x1 < x < x2 and y1 < y < y2 for x1, y1, x2, y2 in keep_out):
            continue
        r = rnd.uniform(rmin, rmax)
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)


# ---------------------------------------------------------------- app icon

def wreath(d, cx, cy, r_in, r_out, seed, leaves, leaf_len, ornaments, orn_r):
    """The face's wreath: dark ring, scattered leaves, berries, ornaments."""
    rmid = (r_in + r_out) / 2
    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=SAGE_DARK)
    rnd = random.Random(seed)
    for _ in range(leaves):
        a = rnd.uniform(0, 2 * math.pi)
        rad = rnd.uniform(r_in, r_out)
        x, y = cx + math.cos(a) * rad, cy + math.sin(a) * rad
        dr = a + math.pi / 2 + rnd.uniform(-0.75, 0.75)
        l, w = leaf_len * rnd.uniform(0.8, 1.2), leaf_len * 0.36
        ux, uy = math.cos(dr), math.sin(dr)
        d.polygon([(x + ux * l / 2, y + uy * l / 2), (x - uy * w / 2, y + ux * w / 2),
                   (x - ux * l / 2, y - uy * l / 2), (x + uy * w / 2, y - ux * w / 2)],
                  fill=rnd.choice([SAGE, SAGE_LIGHT, SAGE_PALE]))
    cols = [GOLD, (229, 143, 165), CREAM, (201, 138, 155)]
    for i in range(ornaments):
        a = math.radians(112 + i * 316 / (ornaments - 1))
        x, y = cx + math.cos(a) * rmid, cy + math.sin(a) * rmid
        c = cols[i % 4]
        d.ellipse([x - orn_r, y - orn_r, x + orn_r, y + orn_r], fill=c)
        h = orn_r * 0.3
        d.ellipse([x - orn_r * 0.45 - h, y - orn_r * 0.45 - h, x - orn_r * 0.45 + h, y - orn_r * 0.45 + h],
                  fill=tuple(int(v + (255 - v) * 0.75) for v in c))


def bow(d, cx, cy, s):
    p = lambda pts: [(cx + u * s, cy + v * s) for u, v in pts]
    d.polygon(p([(-0.12, 0.08), (-0.55, 0.75), (-0.33, 0.66), (-0.22, 0.85), (0.02, 0.15)]), fill=BOW_DARK)
    d.polygon(p([(0.12, 0.08), (0.55, 0.75), (0.33, 0.66), (0.22, 0.85), (-0.02, 0.15)]), fill=BOW_DARK)
    d.polygon(p([(-0.1, 0), (-0.72, -0.42), (-0.95, -0.15), (-0.82, 0.22), (-0.1, 0.1)]), fill=BOW)
    d.polygon(p([(0.1, 0), (0.72, -0.42), (0.95, -0.15), (0.82, 0.22), (0.1, 0.1)]), fill=BOW)
    d.rounded_rectangle([cx - 0.16 * s, cy - 0.17 * s, cx + 0.16 * s, cy + 0.17 * s], radius=0.08 * s, fill=GOLD)


def gen_app_icon():
    # Drawn at 4x and scaled down for smooth edges.
    S, K = 128, 4
    big = S * K
    c = big / 2
    gr = big * 0.36

    img = Image.new("RGB", (big, big), BLUSH_LIGHT)
    wreath(ImageDraw.Draw(img), c, c, gr, big * 0.5, seed=7, leaves=260,
           leaf_len=big * 0.075, ornaments=8, orn_r=big * 0.045)

    # The snow globe: sky, snow, cottage and flakes, clipped to the circle.
    globe = Image.new("RGB", (big, big), BLUSH)
    d = ImageDraw.Draw(globe)
    d.ellipse([c - gr * 1.25, c + gr * 0.35, c + gr * 1.25, c + gr * 1.6], fill=WHITE)
    d.rectangle([c - gr * 0.3, c - gr * 0.02, c + gr * 0.3, c + gr * 0.42], fill=(246, 230, 224))
    d.polygon([(c - gr * 0.42, c), (c, c - gr * 0.4), (c + gr * 0.42, c)], fill=WHITE)
    d.rectangle([c - gr * 0.2, c + gr * 0.08, c - gr * 0.04, c + gr * 0.24], fill=(255, 212, 122))
    d.rectangle([c + gr * 0.06, c + gr * 0.14, c + gr * 0.2, c + gr * 0.42], fill=ROSE)
    snowfall(globe, 26, seed=3, rmin=big * 0.008, rmax=big * 0.016,
             keep_out=[(c - gr * 0.45, c - gr * 0.45, c + gr * 0.45, big)])
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse([c - gr, c - gr, c + gr, c + gr], fill=255)
    img.paste(globe, (0, 0), mask)

    bow(ImageDraw.Draw(img), c, big * 0.89, big * 0.13)
    img = img.resize((S, S), Image.LANCZOS)

    img.save(os.path.join(ASSETS, "app_icon_24bit.png"))
    img.convert("P", palette=Image.ADAPTIVE, colors=64).convert("RGB").save(
        os.path.join(ASSETS, "app_icon_64color.png"))
    print("app_icon_24bit.png / app_icon_64color.png  128x128")


# ---------------------------------------------------------------- watch renders

def load_screen(*names):
    for n in names:
        path = os.path.join(ASSETS, n + ".png")
        if os.path.exists(path):
            return Image.open(path).convert("RGBA")
    return None


def watch_disc(shot, target):
    """A capture as a clean disc with a thin dark bezel ring."""
    shot = shot.resize((target, target), Image.LANCZOS)
    mask = Image.new("L", (target, target), 0)
    ImageDraw.Draw(mask).ellipse([1, 1, target - 1, target - 1], fill=255)
    shot.putalpha(mask)
    ring = int(target * 0.045)
    out = Image.new("RGBA", (target + ring * 2, target + ring * 2), (0, 0, 0, 0))
    ImageDraw.Draw(out).ellipse([0, 0, target + ring * 2 - 1, target + ring * 2 - 1], fill=(38, 37, 42, 255))
    out.paste(shot, (ring, ring), shot)
    return out


def paste_with_shadow(bg, disc, ox, oy):
    sz = disc.size[0]
    pad = 50
    shadow = Image.new("RGBA", (sz + pad * 2, sz + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([pad, pad + 10, pad + sz, pad + sz + 10], fill=(80, 30, 45, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    bg.paste(shadow, (ox - pad, oy - pad), shadow)
    bg.paste(disc, (ox, oy), disc)


# ---------------------------------------------------------------- cover (square)

def gen_cover():
    S = 500
    bg = gradient((S, S), BLUSH_LIGHT, BLUSH).convert("RGBA")
    snowfall(bg, 70, seed=11, rmin=1.5, rmax=3.5)
    d = ImageDraw.Draw(bg)
    for x, y, s in [(46, 52, 11), (452, 64, 9), (40, 410, 8), (462, 392, 10)]:
        twinkle(d, x, y, s, GOLD)

    shot = load_screen("screen_day", "screen_active", "screen_night")
    if shot is None:
        print("WARNING: no screenshot in assets/ - run savescreenshot.ps1 first")
    else:
        disc = watch_disc(shot, int(S * 0.70))
        paste_with_shadow(bg, disc, (S - disc.size[0]) // 2, 22)

    d = ImageDraw.Draw(bg)
    d.text((S / 2, S * 0.905), "Christmas Joy", font=script(64), fill=BERRY, anchor="mm")

    out = bg.convert("RGB")
    out.save(os.path.join(ASSETS, "cover_image.png"))
    out.save(os.path.join(ASSETS, "cover_image.jpg"), quality=92)
    print("cover_image.png / cover_image.jpg  500x500")


# ---------------------------------------------------------------- hero (banner)

def gen_hero():
    W, H = 1440, 720
    bg = gradient((W, H), BLUSH_LIGHT, BLUSH).convert("RGBA")
    snowfall(bg, 170, seed=21, rmin=1.5, rmax=4.5, keep_out=[(90, 90, 650, 640)])
    d = ImageDraw.Draw(bg)

    day = load_screen("screen_day", "screen_active")
    night = load_screen("screen_night")

    # Faces on the right: the night one behind and lower, the day one in front.
    big = int(H * 0.74)
    small = int(H * 0.56)
    text_right = W - big - 260
    if night is not None and day is not None:
        nd = watch_disc(night, small)
        paste_with_shadow(bg, nd, W - nd.size[0] - 40, H - nd.size[1] - 40)
        dd = watch_disc(day, big)
        paste_with_shadow(bg, dd, W - dd.size[0] - 300, 40)
        text_right = W - dd.size[0] - 340
    elif day is not None or night is not None:
        dd = watch_disc(day if day is not None else night, big)
        paste_with_shadow(bg, dd, W - dd.size[0] - 90, (H - dd.size[1]) // 2)
        text_right = W - dd.size[0] - 140
    else:
        print("WARNING: no screenshot in assets/ - run savescreenshot.ps1 first")

    x = 110
    text_w = text_right - x
    d = ImageDraw.Draw(bg)
    title = fit(d, script, "Christmas Joy", 150, text_w)
    d.text((x, 150), "Christmas Joy", font=title, fill=BERRY, anchor="ls")
    sub = fit(d, lambda s: sans(s, 600), "a wreath and a snow globe for your Garmin", 34, text_w)
    d.text((x, 225), "a wreath and a snow globe for your Garmin", font=sub, fill=PLUM, anchor="ls")

    lines = [
        "A Christmas countdown, in script",
        "Ornaments that light up as you walk",
        "Snow that falls when it snows outside",
        "Night sky and glowing windows after sunset",
        "Seven spots for the data you choose",
        "Four themes, from Blush & Gold to Cozy Plaid",
    ]
    body = fit(d, lambda s: sans(s, 600), max(lines, key=len), 27, text_w - 40)
    y = 310
    for line in lines:
        twinkle(d, x + 10, y - 9, 9, GOLD_DEEP)
        d.text((x + 34, y), line, font=body, fill=PLUM, anchor="ls")
        y += 52
    d.text((x, y + 38), "for round AMOLED Garmin watches", font=sans(22, 500), fill=ROSE, anchor="ls")

    bg.convert("RGB").save(os.path.join(ASSETS, "hero_image.png"))
    print("hero_image.png  1440x720")


if __name__ == "__main__":
    os.makedirs(ASSETS, exist_ok=True)
    gen_app_icon()
    gen_cover()
    gen_hero()
    print("Done.")
