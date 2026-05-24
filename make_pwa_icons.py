#!/usr/bin/env python3
"""PWA用アイコン3サイズを既存のAppIcon-1024.pngから生成。"""

import shutil
from pathlib import Path
from PIL import Image

SRC = Path("FlowMeter/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
DST_DIR = Path("docs/icons")
DST_DIR.mkdir(parents=True, exist_ok=True)

# 1024 はそのままコピー
shutil.copy(SRC, DST_DIR / "icon-1024.png")
print(f"copied: {DST_DIR / 'icon-1024.png'}")

# 192 / 512 はリサイズ（高品質）
img = Image.open(SRC)
for size in (192, 512):
    out = DST_DIR / f"icon-{size}.png"
    img.resize((size, size), Image.LANCZOS).save(out, "PNG", optimize=True)
    print(f"saved: {out} ({size}x{size})")
