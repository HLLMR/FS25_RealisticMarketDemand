#!/usr/bin/env python3
"""Generate the mod icon (icon_RealisticMarketDemand.dds) and its PNG source.

The icon is drawn procedurally with Pillow — no AI-generated or externally
sourced imagery — so it satisfies ModHub's imagery rules and is fully
reproducible. Output matches the GIANTS ModHub ModIcon spec: 512x512, BC1 (DXT1),
no mipmaps, opaque (full-square background). Rendered at 4x and downscaled.

Usage:  python tools/gen_icon.py
Requires: Pillow (`pip install Pillow`).
"""
import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2048          # supersample size; downscaled to OUT
OUT = 512         # ModHub ModIcon size


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def build():
    # Opaque full-square vertical gradient background (green -> near-black).
    top, bot = (18, 46, 32), (6, 14, 10)
    img = Image.new("RGB", (S, S))
    for y in range(S):
        ImageDraw.Draw(img).line([(0, y), (S, y)], fill=lerp(top, bot, y / S))
    img = img.convert("RGBA")
    draw = ImageDraw.Draw(img)

    # Subtle rounded inner border (visual only; background stays opaque).
    draw.rounded_rectangle(
        [int(S * 0.05)] * 2 + [int(S * 0.95)] * 2,
        radius=int(S * 0.10), outline=(120, 200, 150, 110), width=int(S * 0.010))

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

    return img.convert("RGB").resize((OUT, OUT), Image.LANCZOS)


def main():
    icon = build()
    os.makedirs(os.path.join(REPO, "media"), exist_ok=True)
    png = os.path.join(REPO, "media", "icon-source.png")
    icon.save(png)
    print("PNG source ->", png)

    dds = os.path.join(REPO, "icon_RealisticMarketDemand.dds")
    # ModHub ModIcon = BC1 (DXT1), no mipmaps.
    for pf in ("DXT1", "DXT5"):
        try:
            icon.save(dds, format="DDS", pixel_format=pf)
            print(f"DDS ({pf}, {OUT}x{OUT}) -> {dds}")
            return
        except Exception as e:  # noqa: BLE001
            print(f"DDS {pf} failed: {e}")
    icon.save(dds, format="DDS")
    print("DDS (uncompressed) ->", dds)


if __name__ == "__main__":
    main()
