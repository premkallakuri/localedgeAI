#!/usr/bin/env python3
"""
Generate the LocalEdge AI app icon at every size macOS .icns and iOS
AppIcon.appiconset need. Run from anywhere; outputs land under ./build/icons/.

Usage:
    python3 scripts/generate_icon.py

Then:
    ./build_app.sh          # macOS picks up icons/AppIcon.icns
    ./build_ios_app.sh      # iOS picks up icons/ios/<all sizes>.png
"""
from __future__ import annotations
import math
import os
import subprocess
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    raise SystemExit("Need Pillow. Install with: pip3 install --user Pillow")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "icons"
ICONSET = OUT / "AppIcon.iconset"
IOS_DIR = OUT / "ios"

# Android Gallery's signature blue gradient (#85B1F8 → #3174F1), Apple squircle radius.
GRAD_TOP = (133, 177, 248)   # #85B1F8
GRAD_BOT = (49, 116, 241)    # #3174F1
HIGHLIGHT_TOP = (255, 255, 255, 90)


def squircle_mask(size: int) -> Image.Image:
    """Apple-style continuous-curve squircle alpha mask (n=5)."""
    n = 5.0
    r = size / 2.0 - 1
    cx = cy = size / 2.0
    mask = Image.new("L", (size, size), 0)
    px = mask.load()
    rn = r ** n
    for y in range(size):
        for x in range(size):
            d = abs(x - cx) ** n + abs(y - cy) ** n
            if d <= rn:
                px[x, y] = 255
    return mask


def linear_gradient(size: int, top: tuple[int, int, int], bot: tuple[int, int, int]) -> Image.Image:
    """RGB vertical gradient."""
    grad = Image.new("RGB", (1, size), 0)
    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        grad.putpixel((0, y), (r, g, b))
    return grad.resize((size, size))


def chip_glyph(size: int) -> Image.Image:
    """
    Center-stamp white chip outline + spark:
    - Outer rounded square (the 'chip')
    - 8 pin-stubs on each side
    - A 4-point spark glyph in the middle
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx = cy = size / 2
    chip_size = size * 0.46
    chip_rad = chip_size * 0.18
    half = chip_size / 2

    # Chip body
    bbox = (cx - half, cy - half, cx + half, cy + half)
    d.rounded_rectangle(bbox, radius=chip_rad, outline=(255, 255, 255, 230),
                        width=max(2, int(size * 0.014)))

    # Pin stubs (3 per side, evenly spaced)
    pin_len = size * 0.04
    pin_w = max(2, int(size * 0.018))
    offsets = [-0.55, 0.0, 0.55]
    for o in offsets:
        # Top
        x = cx + o * chip_size * 0.55
        d.line([(x, cy - half - pin_len), (x, cy - half)], fill=(255, 255, 255, 230), width=pin_w)
        # Bottom
        d.line([(x, cy + half), (x, cy + half + pin_len)], fill=(255, 255, 255, 230), width=pin_w)
        # Left
        y = cy + o * chip_size * 0.55
        d.line([(cx - half - pin_len, y), (cx - half, y)], fill=(255, 255, 255, 230), width=pin_w)
        # Right
        d.line([(cx + half, y), (cx + half + pin_len, y)], fill=(255, 255, 255, 230), width=pin_w)

    # 4-point spark (the "AI" twinkle)
    spark = size * 0.13
    for length, w in [(spark, max(2, int(size * 0.022))),
                      (spark * 0.55, max(2, int(size * 0.014)))]:
        # vertical
        d.line([(cx, cy - length), (cx, cy + length)], fill=(255, 255, 255, 250), width=w)
        # horizontal
        d.line([(cx - length, cy), (cx + length, cy)], fill=(255, 255, 255, 250), width=w)

    return img


def render_icon(size: int) -> Image.Image:
    """Compose squircle + gradient fill + glyph + subtle inner glow."""
    # 4x supersample for clean edges, then downscale
    s = size * 4
    mask = squircle_mask(s)
    grad = linear_gradient(s, GRAD_TOP, GRAD_BOT)
    base = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    base.paste(grad, (0, 0), mask)

    # Subtle top highlight (gives it depth)
    top_glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(top_glow)
    gd.ellipse((s * -0.25, s * -0.55, s * 1.25, s * 0.45),
               fill=(255, 255, 255, 60))
    top_glow = top_glow.filter(ImageFilter.GaussianBlur(s * 0.06))
    # Constrain to squircle
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow.paste(top_glow, (0, 0), mask)
    base.alpha_composite(glow)

    # Glyph
    glyph = chip_glyph(s)
    base.alpha_composite(glyph)

    return base.resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ICONSET.mkdir(parents=True, exist_ok=True)
    IOS_DIR.mkdir(parents=True, exist_ok=True)

    # macOS iconset
    mac_sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in mac_sizes:
        img = render_icon(s)
        name = f"icon_{s}x{s}.png"
        img.save(ICONSET / name)
        # @2x variants Apple expects
        if s in (16, 32, 128, 256, 512):
            img2 = render_icon(s * 2)
            img2.save(ICONSET / f"icon_{s}x{s}@2x.png")
    print(f"  ✓ wrote {ICONSET}")

    # iOS PNGs (we use a single largest PNG via CFBundleIcons primary file)
    # Apple iOS 17+ accepts a single 1024x1024 PNG flattened.
    ios_sizes = {
        "AppIcon-20.png": 20,
        "AppIcon-29.png": 29,
        "AppIcon-40.png": 40,
        "AppIcon-58.png": 58,
        "AppIcon-60.png": 60,
        "AppIcon-76.png": 76,
        "AppIcon-80.png": 80,
        "AppIcon-87.png": 87,
        "AppIcon-120.png": 120,
        "AppIcon-152.png": 152,
        "AppIcon-167.png": 167,
        "AppIcon-180.png": 180,
        "AppIcon-1024.png": 1024,
    }
    for name, size in ios_sizes.items():
        render_icon(size).save(IOS_DIR / name)
    print(f"  ✓ wrote {IOS_DIR}")

    # Convert to .icns
    icns_path = OUT / "AppIcon.icns"
    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET), "-o", str(icns_path)],
        check=True,
    )
    print(f"  ✓ wrote {icns_path} ({icns_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
