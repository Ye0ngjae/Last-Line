#!/usr/bin/env python3
"""Add numbered callouts to the raw tutorial screenshots.

  python tools/annotate_docs.py <capture_dir (png + marks.json)> <out_dir, e.g. docs/images>

Marks are [label, x, y, width]: width 0 = a point on the scope/view (ring + badge), width > 0 = a control
(badge on its left edge). Numbers follow the mark order and match the legends in docs/tutorial_*.md.
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

FONTS = ["/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/Supplemental/Arial.ttf",
         "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]


def font(size):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def badge(d, x, y, n):
    r = 11
    d.ellipse((x - r, y - r, x + r, y + r), fill=(220, 40, 40), outline=(255, 255, 255), width=2)
    d.text((x, y), str(n), fill="white", font=font(15), anchor="mm")


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    marks = json.load(open(os.path.join(src, "marks.json")))
    for name, items in marks.items():
        path = os.path.join(src, name + ".png")
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGB")
        d = ImageDraw.Draw(img)
        for n, (label, x, y, w) in enumerate(items, 1):
            if w > 0:
                d.rectangle((x, y - 15, x + w, y + 15), outline=(220, 40, 40), width=2)
                badge(d, x - 2, y, n)
            else:
                d.ellipse((x - 20, y - 20, x + 20, y + 20), outline=(220, 40, 40), width=3)
                badge(d, x + 22, y - 22, n)
        img.save(os.path.join(dst, name + ".png"), optimize=True)
        print("annotated", name, len(items))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
