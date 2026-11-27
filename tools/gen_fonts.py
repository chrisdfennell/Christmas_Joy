#!/usr/bin/env python
"""
Bake the Christmas Joy bitmap fonts (.fnt + .png) for every panel size.

Connect IQ cannot rasterize a .ttf at build time and bitmap fonts do not scale,
so each round panel size gets its own set, picked by monkey.jungle. Sizes are
given on the 454x454 base and scaled by width / 454.

The three faces (all SIL Open Font License, in fonts-src/ with their OFL.txt):
  - Dancing Script Bold -> the time
  - Great Vibes         -> the top line (countdown, saying of the day)
  - Quicksand Bold      -> the date line and the data values

Glyphs are white with coverage in alpha, so dc.setColor() tints them.

Besides the fonts, this prints each font's "ink middle" ratio: the vertical
middle of the reference glyphs as a fraction of the line height. The view uses
these (MID_* in ChristmasJoyView.mc) to centre text on a y, the same way the web
preview centres text with measureText().

Run:  python tools/gen_fonts.py
"""
import os
from PIL import Image, ImageFont, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "fonts-src")
PAD = 2
BASE_RES = 454

DIGITS = "0123456789"
UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
LOWER = "abcdefghijklmnopqrstuvwxyz"
TEXT_CHARS = UPPER + LOWER + DIGITS + " ,.:%!?'&+-/°"

FONTS = [
    {"name": "cj_time",    "ttf": "DancingScript.ttf",      "wght": 700, "size": 90,  "chars": DIGITS + ":",       "ref": DIGITS},
    {"name": "cj_time_lg", "ttf": "DancingScript.ttf",      "wght": 700, "size": 124, "chars": DIGITS + ":",       "ref": DIGITS},
    {"name": "cj_line",    "ttf": "GreatVibes-Regular.ttf", "wght": None, "size": 36, "chars": TEXT_CHARS,         "ref": "Merry Christmas"},
    {"name": "cj_date",    "ttf": "Quicksand.ttf",          "wght": 700, "size": 16,  "chars": UPPER + DIGITS + " ·", "ref": "THURSDAY NOV 26", "track": 2.4},
    {"name": "cj_data",    "ttf": "Quicksand.ttf",          "wght": 700, "size": 22,  "chars": TEXT_CHARS,         "ref": DIGITS},
    {"name": "cj_small",   "ttf": "Quicksand.ttf",          "wght": 700, "size": 19,  "chars": TEXT_CHARS,         "ref": DIGITS},
]

# Every distinct panel size in manifest.xml (AMOLED, round).
TARGETS = [
    (454, "resources/fonts"),
    (416, "resources-round-416x416/fonts"),
    (390, "resources-round-390x390/fonts"),
    (360, "resources-round-360x360/fonts"),
]

FONTS_XML = (
    '<resources>\n'
    '    <!-- Bitmap fonts baked by tools/gen_fonts.py for this panel size. -->\n'
    '    <fonts>\n'
    '        <font id="TimeFont"   filename="cj_time.fnt"    antialias="true" />\n'
    '        <font id="TimeFontLg" filename="cj_time_lg.fnt" antialias="true" />\n'
    '        <font id="LineFont"   filename="cj_line.fnt"    antialias="true" />\n'
    '        <font id="DateFont"   filename="cj_date.fnt"    antialias="true" />\n'
    '        <font id="DataFont"   filename="cj_data.fnt"    antialias="true" />\n'
    '        <font id="SmallFont"  filename="cj_small.fnt"   antialias="true" />\n'
    '    </fonts>\n'
    '</resources>\n'
)


def next_pow2(n):
    p = 1
    while p < n:
        p <<= 1
    return p


def load(spec, size):
    font = ImageFont.truetype(os.path.join(SRC, spec["ttf"]), size)
    if spec["wght"]:
        font.set_variation_by_axes([spec["wght"]])
    return font


def gen(spec, size, scale, outdir):
    font = load(spec, size)
    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    track = int(round(spec.get("track", 0) * scale))

    glyphs = []
    for ch in spec["chars"]:
        l, t, r, b = font.getbbox(ch)
        glyphs.append({"ch": ch, "l": l, "t": t, "w": max(r - l, 0), "h": max(b - t, 0),
                       "adv": int(round(font.getlength(ch))) + track})

    # Script faces draw some ink above the nominal ascent (negative bbox top),
    # which Connect IQ would clip. Give the line box that much headroom.
    pad_top = max(0, -min((g["t"] for g in glyphs), default=0))
    for g in glyphs:
        g["yoff"] = g["t"] + pad_top
    ascent += pad_top
    line_height += pad_top
    line_height = max(line_height, max((g["yoff"] + g["h"] for g in glyphs), default=0))

    # Pack rows into the squarest power-of-two atlas (a tall 128px strip
    # wastes texture rows on the big time fonts).
    max_w = max((g["w"] for g in glyphs), default=1)
    best = None
    w_try = next_pow2(max(64, max_w + PAD * 2))
    while w_try <= 2048:
        x, y, row_h, pos = PAD, PAD, 0, []
        for g in glyphs:
            if x + g["w"] + PAD > w_try:
                x = PAD
                y += row_h + PAD
                row_h = 0
            pos.append((x, y))
            x += g["w"] + PAD
            row_h = max(row_h, g["h"])
        h_try = next_pow2(y + row_h + PAD)
        key = (w_try * h_try, max(w_try, h_try))
        if best is None or key < best[0]:
            best = (key, w_try, h_try, pos)
        w_try <<= 1
    _, atlas_w, atlas_h, pos = best
    for g, (gx, gy) in zip(glyphs, pos):
        g["x"], g["y"] = gx, gy

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (255, 255, 255, 0))
    for g in glyphs:
        if g["w"] == 0 or g["h"] == 0:
            continue
        cell = Image.new("L", (g["w"], g["h"]), 0)
        ImageDraw.Draw(cell).text((-g["l"], -g["t"]), g["ch"], font=font, fill=255)
        white = Image.new("RGBA", (g["w"], g["h"]), (255, 255, 255, 0))
        white.putalpha(cell)
        atlas.alpha_composite(white, (g["x"], g["y"]))

    png_name = spec["name"] + ".png"
    atlas.save(os.path.join(outdir, png_name))

    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        'smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % (spec["name"], size),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
        "alphaChnl=1 redChnl=4 greenChnl=4 blueChnl=4" % (line_height, ascent, atlas_w, atlas_h),
        'page id=0 file="%s"' % png_name,
        "chars count=%d" % len(glyphs),
    ]
    for g in glyphs:
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d "
            "xadvance=%d page=0 chnl=15"
            % (ord(g["ch"]), g["x"], g["y"], g["w"], g["h"], g["l"], g["yoff"], g["adv"]))
    lines.append("kernings count=0")
    with open(os.path.join(outdir, spec["name"] + ".fnt"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    ref = [g for g in glyphs if g["ch"] in spec["ref"] and g["h"] > 0]
    top = min(g["yoff"] for g in ref)
    bot = max(g["yoff"] + g["h"] for g in ref)
    return atlas_w, atlas_h, line_height, (top + bot) / 2.0 / line_height


if __name__ == "__main__":
    for res, reldir in TARGETS:
        outdir = os.path.join(ROOT, reldir)
        os.makedirs(outdir, exist_ok=True)
        scale = res / float(BASE_RES)
        print("== %dx%d -> %s ==" % (res, res, reldir))
        for spec in FONTS:
            size = max(8, int(round(spec["size"] * scale)))
            aw, ah, lh, mid = gen(spec, size, scale, outdir)
            print("   %-10s size=%3d atlas=%4dx%-4d lineHeight=%3d mid=%.3f" % (spec["name"], size, aw, ah, lh, mid))
        with open(os.path.join(outdir, "fonts.xml"), "w", newline="\n") as f:
            f.write(FONTS_XML)
    print("Done.")
