#!/usr/bin/env python3
"""Generate the mod icon (icon_RealisticMarketDemand.dds) and its PNG source.

The icon is drawn procedurally with Pillow — no AI-generated or externally
sourced imagery — so it satisfies ModHub's imagery rules and is fully
reproducible. Rendered at 4x and downscaled for clean edges, saved as 256x256
DXT5 DDS (what the GIANTS engine loads) plus a PNG source under media/.

Usage:  python tools/gen_icon.py
Requires: Pillow (`pip install Pillow`).

For the official ModHub icon frame you can run media/icon-source.png through
GIANTS FSIconGenerator; this procedural icon is fine for use as-is otherwise.
"""
import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024  # supersample size; downscaled to 256


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def build():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Rounded panel with a vertical green -> black gradient.
    top, bot = (18, 46, 32), (6, 14, 10)
    grad = Image.new("RGB", (1, S))
    for y in range(S):
        grad.putpixel((0, y), lerp(top, bot, y / S))
    grad = grad.resize((S, S))
    radius = int(S * 0.18)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        [int(S * 0.03)] * 2 + [int(S * 0.97)] * 2,
        radius=int(radius * 0.85), outline=(120, 200, 150, 90), width=int(S * 0.012))

    # Descending bars: demand crushing the price, left (high) to right (low).
    bar_colors = [(76, 200, 120), (120, 205, 90), (210, 190, 70), (225, 140, 60), (215, 80, 70)]
    n = 5
    margin, gap = int(S * 0.16), int(S * 0.035)
    bw = (S - 2 * margin - (n - 1) * gap) // n
    base = int(S * 0.80)
    heights = [0.62, 0.50, 0.39, 0.29, 0.20]
    tops = []
    for i in range(n):
        x0 = margin + i * (bw + gap)
        y0 = base - int(S * heights[i])
        draw.rounded_rectangle([x0, y0, x0 + bw, base], radius=int(bw * 0.16),
                               fill=bar_colors[i] + (255,))
        tops.append((x0 + bw // 2, y0))

    # Downward trend line + arrow head over the bar tops.
    line = [(t[0], t[1] - int(S * 0.02)) for t in tops]
    draw.line(line, fill=(240, 248, 244, 255), width=int(S * 0.018), joint="curve")
    ax, ay = line[-1]
    ah = int(S * 0.045)
    draw.polygon([(ax, ay + ah), (ax - ah, ay - ah * 0.2), (ax + ah, ay - ah * 0.2)],
                 fill=(240, 248, 244, 255))
    for px, py in line:
        r = int(S * 0.016)
        draw.ellipse([px - r, py - r, px + r, py + r], fill=(240, 248, 244, 255))

    # Euro glyph as the market/price cue.
    for fp in ("C:/Windows/Fonts/seguisb.ttf", "C:/Windows/Fonts/segoeui.ttf",
               "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(fp):
            draw.text((int(S * 0.14), int(S * 0.10)), "\u20ac",
                      font=ImageFont.truetype(fp, int(S * 0.20)), fill=(210, 255, 225, 235))
            break

    return img.resize((256, 256), Image.LANCZOS)


def main():
    icon = build()
    os.makedirs(os.path.join(REPO, "media"), exist_ok=True)
    png = os.path.join(REPO, "media", "icon-source.png")
    icon.save(png)
    print("PNG source ->", png)

    dds = os.path.join(REPO, "icon_RealisticMarketDemand.dds")
    for pf in ("DXT5", "DXT1"):
        try:
            icon.save(dds, format="DDS", pixel_format=pf)
            print(f"DDS ({pf}) -> {dds}")
            return
        except Exception as e:  # noqa: BLE001
            print(f"DDS {pf} failed: {e}")
    icon.save(dds, format="DDS")
    print("DDS (uncompressed) ->", dds)


if __name__ == "__main__":
    main()
