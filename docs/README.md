# 流量測定 PWA

水道メーターの副針1周時間、または水槽の水位変化から流量（m³/h）を算出するPWA。
iOSネイティブ版と同じ機能をブラウザで動かす版です。

## 使い方

### 通常アクセス
[https://ytatsuno-lang.github.io/FlowMeter/](https://ytatsuno-lang.github.io/FlowMeter/) をブラウザで開く。

### iPhone でアプリ化（ホーム画面に追加）
1. **Safariで上記URLを開く**（Chromeでは不可）
2. 共有ボタン（□↑）→ **「ホーム画面に追加」**
3. アイコン名「流量測定」で追加
4. ホーム画面のアイコンから起動するとフルスクリーンで動作

### Android でアプリ化
1. **Chromeで上記URLを開く**
2. メニュー → **「ホーム画面に追加」** または「アプリをインストール」
3. アイコンから起動

## 機能

| 機能 | 内容 |
|---|---|
| メーター式 | 1周容量(10/100/1000L)切替 + 最大3回計測 + 平均 |
| 水槽式 | 矩形/円形対応、寸法×水位差×時間で流量計算 |
| 履歴 | 両方式を時系列で混在表示、メモ後編集可 |
| 位置情報 | 自動取得、住所・POI表示、鮮度表示（1時間で警告） |
| エクスポート/インポート | JSON形式でバックアップ・端末間移行 |
| オフライン | Service Workerで起動可（位置取得のみ要ネット） |

## 計算式

```
メーター: m³/h = 1周容量[L] × 3.6 / 経過秒
水槽矩形: m³/h = W × D × Δh × 3600 / 経過秒
水槽円形: m³/h = π(Φ/2)² × Δh × 3600 / 経過秒
```

## 注意事項

### iOS Safari の7日 eviction
iOS Safariは「7日間アクセスがないサイト」のデータを自動削除することがあります。
重要な記録は **定期的にエクスポート** してJSONファイルを別途保存してください。

### 位置情報
- 屋外でGPSが入る環境では数秒で取得
- 屋内・地下では取得失敗 → 既存の取得済み位置（最大1時間前まで）を使用
- ブラウザの位置情報許可が必要

### 逆ジオコーディング
OpenStreetMapのNominatim APIを使用（無料・APIキー不要）。
混雑時は住所が出ないことがあります（座標は取得済み）。

## 開発

### ローカル実行
```bash
cd docs
python3 -m http.server 8000
# http://localhost:8000 を開く
```

### ファイル構成
```
docs/
├── index.html        SPAシェル + タブUI
├── manifest.json     PWAメタデータ
├── sw.js             Service Worker
├── css/style.css
├── js/
│   ├── app.js        エントリ、タブ切替、SaveSheet
│   ├── meter.js      メーター式
│   ├── tank.js       水槽式
│   ├── history.js    履歴一覧 + 詳細
│   ├── storage.js    IndexedDB
│   ├── location.js   Geolocation + Nominatim
│   ├── formula.js    流量計算式
│   └── format.js     数値/日時フォーマット
└── icons/            192/512/1024 PNG
```

### データ形式（iOS版と互換）
```json
{
  "id": "uuid",
  "date": "ISO8601",
  "method": "meter" | "tank",
  "capacityL": 100,
  "lapTimes": [36.2, 35.8, 36.1],
  "tank": { "shape": "rectangular", "width": 1.0, "depth": 1.0, "diameter": 0, "levelDelta": 0.1, "elapsedSeconds": 36.0 },
  "note": "",
  "location": { "latitude": 35.6, "longitude": 139.7, "horizontalAccuracy": 10, "placeName": "...", "address": "...", "areasOfInterest": [], "capturedAt": 1234567890 }
}
```
