# 流量測定 (FlowMeter)

水道メーター副針1周時間、または水槽水位変化から流量（m³/h）を算出するアプリ。
**iOSネイティブ版** と **PWA版** の2系統で提供。

## 2つの版

| 版 | 場所 | 起動方法 | 特徴 |
|---|---|---|---|
| **iOSネイティブ** | `FlowMeter/`, `FlowMeter.xcodeproj/` | Xcodeでビルド・実機/シミュレータ起動 | 純正UI、オフライン強い、Apple Developer登録要 |
| **PWA** | `docs/` | [https://ytatsuno-lang.github.io/FlowMeter/](https://ytatsuno-lang.github.io/FlowMeter/) をSafari/Chromeで開く | iOS/Android/PC、URLだけで配布、Apple Developer不要 |

## 共通機能

- メーター式（1周容量切替、最大3回計測、平均算出）
- 水槽式（矩形/円形、寸法×水位差×時間で流量計算）
- 履歴（時系列、メモ後編集）
- 位置情報自動取得（住所・POI、鮮度表示、地下対応）

## 計算式

```
メーター: m³/h = 1周容量[L] × 3.6 / 経過秒
水槽矩形: m³/h = W × D × Δh × 3600 / 経過秒
水槽円形: m³/h = π(Φ/2)² × Δh × 3600 / 経過秒
```

例: メーター 100L / 36秒 → 10.0 m³/h

## iOSネイティブ版

詳細: [FlowMeter ディレクトリ](FlowMeter/)

Xcodeで `FlowMeter.xcodeproj` を開いてビルド。
Bundle ID: `jp.tatsuno.FlowMeter`、表示名「流量測定」。

## PWA版

詳細: [docs/README.md](docs/README.md)

`docs/` 配下を GitHub Pages で配信。
リポジトリの Settings → Pages → Branch: main / Folder: /docs で有効化。

### ローカル開発
```bash
cd docs
python3 -m http.server 8000
# http://localhost:8000
```

## アイコン

- iOSネイティブ: `FlowMeter/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- PWA: `docs/icons/icon-{192,512,1024}.png`

両方とも同じデザイン（青いグラデ + 「流量測定」漢字2x2）。

### アイコン再生成
```bash
# iOSアイコン (1024x1024)
python3 make_icon.py

# PWAアイコン (192/512/1024) - iOS版から生成
python3 make_pwa_icons.py
```

## データ互換性

両版とも以下の同じJSONスキーマを使用。将来的にエクスポート/インポート相互運用予定。

```json
{
  "id": "uuid",
  "date": "ISO8601",
  "method": "meter" | "tank",
  "capacityL": 100,
  "lapTimes": [...],
  "tank": { "shape": "rectangular|circular", "width", "depth", "diameter", "levelDelta", "elapsedSeconds" },
  "note": "",
  "location": { "latitude", "longitude", "horizontalAccuracy", "placeName", "address", "areasOfInterest", "capturedAt" }
}
```

- iOSネイティブ: `Documents/flow_measurements.json` に保存
- PWA: IndexedDB (`measurements` キー)、エクスポート機能でJSON取得可
