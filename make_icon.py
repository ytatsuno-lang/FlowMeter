#!/usr/bin/env python3
"""FlowMeter app icon generator: 「流量計測」の2x2レイアウトで1024x1024 PNGを作る。"""

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
OUTPUT = "FlowMeter/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
FONT_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
TEXT_TL, TEXT_TR = "流", "量"
TEXT_BL, TEXT_BR = "計", "測"

img = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
draw = ImageDraw.Draw(img)

# 青系のグラデーション背景（左上→右下）
top = (0x2E, 0x86, 0xFF)   # 明るめの青
bot = (0x00, 0x4C, 0xD9)   # 濃い青
for y in range(SIZE):
    t = y / (SIZE - 1)
    r = int(top[0] * (1 - t) + bot[0] * t)
    g = int(top[1] * (1 - t) + bot[1] * t)
    b = int(top[2] * (1 - t) + bot[2] * t)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

# 2x2 で文字を配置（iOSの角丸マスク約18%を考慮して内側寄せ）
font_size = 360
font = ImageFont.truetype(FONT_PATH, font_size)

quadrants = [
    (TEXT_TL, SIZE * 0.28, SIZE * 0.29),  # 左上
    (TEXT_TR, SIZE * 0.72, SIZE * 0.29),  # 右上
    (TEXT_BL, SIZE * 0.28, SIZE * 0.71),  # 左下
    (TEXT_BR, SIZE * 0.72, SIZE * 0.71),  # 右下
]

for ch, cx, cy in quadrants:
    bbox = draw.textbbox((0, 0), ch, font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    # bbox の左上が原点だが、文字によって上にも余白があるので調整
    x = cx - w / 2 - bbox[0]
    y = cy - h / 2 - bbox[1]
    draw.text((x, y), ch, font=font, fill=(255, 255, 255))

img.save(OUTPUT, "PNG", optimize=True)
print(f"saved: {OUTPUT} ({SIZE}x{SIZE})")
