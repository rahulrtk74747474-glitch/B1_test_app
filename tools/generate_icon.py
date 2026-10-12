#!/usr/bin/env python3
"""Generate the offline Police B1 Test Android launcher icon (no external assets)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

S = 1024
im = Image.new('RGB', (S, S), (11, 36, 74))
d = ImageDraw.Draw(im)
# Navy-blue field with a luminous circle behind a protective shield.
d.ellipse((118, 112, 906, 900), fill=(20, 77, 138), outline=(87, 153, 214), width=13)
# Shield, gold outline and inner midnight-blue face.
shield = [(512, 158), (774, 275), (755, 555), (696, 700), (512, 838),
          (328, 700), (269, 555), (250, 275)]
d.polygon(shield, fill=(239, 182, 69))
inner = [(512, 193), (739, 297), (721, 543), (667, 675), (512, 794),
         (357, 675), (303, 543), (285, 297)]
d.polygon(inner, fill=(14, 47, 94))
# Open book: a single unmistakable education symbol.
d.polygon([(333, 470), (488, 490), (488, 640), (335, 619)], fill=(255, 255, 248))
d.polygon([(536, 490), (691, 470), (689, 619), (536, 640)], fill=(255, 255, 248))
d.line([(512, 489), (512, 648)], fill=(239, 182, 69), width=18)
d.arc((343, 510, 485, 615), start=245, end=310, fill=(80, 125, 171), width=10)
d.arc((539, 510, 681, 615), start=225, end=290, fill=(80, 125, 171), width=10)
# Gold five-point star at the shield crown.
import math
cx, cy, R, r = 512, 353, 81, 35
star = []
for j in range(10):
    angle = -math.pi / 2 + j * math.pi / 5
    radius = R if j % 2 == 0 else r
    star.append((int(cx + radius * math.cos(angle)), int(cy + radius * math.sin(angle))))
d.polygon(star, fill=(255, 207, 105))
# Police B1 badge lettering.
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 78)
except OSError:
    font = ImageFont.load_default()
d.text((512, 744), 'B1', anchor='mm', font=font, fill=(255, 255, 255),
       stroke_width=3, stroke_fill=(14, 47, 94))
out = Path('assets/brand/police_b1_icon.png')
out.parent.mkdir(parents=True, exist_ok=True)
im.save(out, optimize=True)
print(out, out.stat().st_size)
