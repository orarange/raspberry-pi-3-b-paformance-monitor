# 🍓 Raspberry Pi 3 B+ Performance Monitor

軽量でリアルタイムなRaspberry Pi 3 B+パフォーマンスモニタリングシステム

## 特徴

- **軽量設計**: Goで実装されたバックエンドにより、最小限のリソース使用量（5-15MB）
- **リアルタイム監視**: WebSocketを使用したリアルタイムデータ更新
- **美しいUI**: レスポンシブデザインによる直感的なWebダッシュボード
- **包括的監視**: CPU、メモリ、温度、ディスク、ネットワークの監視
- **クロスプラットフォーム**: Raspberry Pi以外でも動作可能

## 監視項目

- ✅ CPU使用率（リアルタイムグラフ付き）
- ✅ メモリ使用量
- ✅ CPU温度（Raspberry Pi特化）
- ✅ ディスク使用量
- ✅ ネットワーク転送量
- ✅ システム稼働時間
- ✅ ロードアベレージ
- ✅ Goルーチン数

## クイックスタート

### 前提条件

- Go 1.21以上
- Raspberry Pi 3 B+ (または他のLinuxシステム)

### インストールと実行

1. **依存関係のインストール**
   ```bash
   go mod tidy
   ```

2. **アプリケーションのビルド**
   ```bash
   go build -o raspberry-pi-monitor
   ```

3. **実行**
   ```bash
   ./raspberry-pi-monitor
   ```

4. **ダッシュボードにアクセス**
   ブラウザで `http://localhost:8080` を開く

### Raspberry Pi向けクロスコンパイル

Windows/Macから Raspberry Pi向けにビルドする場合：

```bash
# ARM64 (Raspberry Pi 4)
GOOS=linux GOARCH=arm64 go build -o raspberry-pi-monitor-arm64

# ARMv7 (Raspberry Pi 3 B+)
GOOS=linux GOARCH=arm GOARM=7 go build -o raspberry-pi-monitor-armv7
```

## プロジェクト構造

```
raspberry-pi-monitor/
├── main.go                 # メインサーバー
├── monitor/
│   ├── system.go          # システム情報収集
│   └── websocket.go       # WebSocket処理
├── web/
│   ├── index.html         # メインダッシュボード
│   ├── app.js             # フロントエンドロジック
│   └── style.css          # スタイルシート
├── go.mod                 # Go モジュール定義
└── README.md              # このファイル
```

## APIエンドポイント

- `GET /` - メインダッシュボード
- `GET /ws` - WebSocketエンドポイント（リアルタイムデータ）
- `GET /api/stats` - システム統計のJSON API
- `GET /health` - ヘルスチェック

## 設定

### 環境変数

- `PORT` - サーバーポート（デフォルト: 8080）

### カスタマイズ

監視間隔やその他の設定は `main.go` の定数で変更可能：

```go
const (
    DefaultPort = ":8080"
    MonitorInterval = time.Second  // 1秒間隔
)
```

## パフォーマンス

### リソース使用量

- **メモリ**: 5-15MB
- **CPU**: 1-3%（アイドル時）
- **ネットワーク**: 最小限（WebSocket通信のみ）

### 更新頻度

- システム統計: 1秒間隔
- WebSocket通信: リアルタイム
- チャート更新: 60データポイント保持

## ライセンス

MIT License

## コントリビューション

プルリクエストやイシュー報告を歓迎します！

---

## 開発者向け情報

### 使用技術

- **バックエンド**: Go, gorilla/websocket, shirou/gopsutil
- **フロントエンド**: バニラJavaScript, Canvas API, WebSocket
- **スタイル**: CSS3, レスポンシブデザイン

### 拡張可能性

新しい監視項目を追加する場合：

1. `monitor/system.go`の`SystemStats`構造体を拡張
2. `GetStats()`メソッドで新しいメトリクスを収集
3. `web/app.js`でフロントエンド表示を追加
4. `web/index.html`と`web/style.css`でUIを更新