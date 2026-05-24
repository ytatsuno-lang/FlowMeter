#!/usr/bin/env python3
"""PWA用アイコン (192/512/1024) を生成。iOS版と色を変えて区別。

色: ミント (#8FDCCA系)、文字「流量測定」白色2x2
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
DST_DIR = Path("docs/icons")
DST_DIR.mkdir(parents=True, exist_ok=True)
FONT_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

# ミント/ティールの上下グラデーション
TOP = (170, 235, 215)   # 明るめミント
BOT = (115, 200, 180)   # 濃いめミント
TEXT_COLOR = (255, 255, 255)
TEXT_TL, TEXT_TR = "流", "量"
TEXT_BL, TEXT_BR = "測", "定"

def make_1024():
    img = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        r = int(TOP[0] * (1 - t) + BOT[0] * t)
        g = int(TOP[1] * (1 - t) + BOT[1] * t)
        b = int(TOP[2] * (1 - t) + BOT[2] * t)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

    font_size = 360
    font = ImageFont.truetype(FONT_PATH, font_size)
    quadrants = [
        (TEXT_TL, SIZE * 0.28, SIZE * 0.29),
        (TEXT_TR, SIZE * 0.72, SIZE * 0.29),
        (TEXT_BL, SIZE * 0.28, SIZE * 0.71),
        (TEXT_BR, SIZE * 0.72, SIZE * 0.71),
    ]
    for ch, cx, cy in quadrants:
        bbox = draw.textbbox((0, 0), ch, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        x = cx - w / 2 - bbox[0]
        y = cy - h / 2 - bbox[1]
        draw.text((x, y), ch, font=font, fill=TEXT_COLOR)
    return img

icon = make_1024()
icon.save(DST_DIR / "icon-1024.png", "PNG", optimize=True)
print(f"saved: {DST_DIR / 'icon-1024.png'} ({SIZE}x{SIZE})")

for size in (192, 512):
    out = DST_DIR / f"icon-{size}.png"
    icon.resize((size, size), Image.LANCZOS).save(out, "PNG", optimize=True)
    print(f"saved: {out} ({size}x{size})")
