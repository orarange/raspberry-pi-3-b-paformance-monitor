# 🍓 Raspberry Pi 3 B+ Performance Monitor - 開発環境セットアップ

## 開発環境のセットアップ手順

### 1. Go言語のインストール

#### Windows
1. [Go公式サイト](https://golang.org/dl/)から最新版をダウンロード
2. インストーラーを実行してインストール
3. コマンドプロンプトまたはPowerShellを再起動
4. `go version` で確認

#### Linux (Raspberry Pi)
```bash
# 最新のGoをダウンロード（ARMv7用）
wget https://golang.org/dl/go1.21.5.linux-armv6l.tar.gz

# 既存のGoを削除（もしあれば）
sudo rm -rf /usr/local/go

# 新しいGoを展開
sudo tar -C /usr/local -xzf go1.21.5.linux-armv6l.tar.gz

# パスを設定
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# 確認
go version
```

### 2. プロジェクトのビルドと実行

```bash
# プロジェクトディレクトリに移動
cd raspberry-pi-3-b-paformance-monitor

# 依存関係をダウンロード
go mod tidy

# 開発モードで実行（ホットリロード）
go run main.go

# または、バイナリをビルドして実行
go build -o raspberry-pi-monitor
./raspberry-pi-monitor
```

### 3. クロスコンパイル（他のプラットフォーム向け）

```bash
# Windows向け
GOOS=windows GOARCH=amd64 go build -o raspberry-pi-monitor.exe

# Linux ARM64向け（Raspberry Pi 4）
GOOS=linux GOARCH=arm64 go build -o raspberry-pi-monitor-arm64

# Linux ARMv7向け（Raspberry Pi 3 B+）
GOOS=linux GOARCH=arm GOARM=7 go build -o raspberry-pi-monitor-armv7

# macOS向け
GOOS=darwin GOARCH=amd64 go build -o raspberry-pi-monitor-macos
```

### 4. サービスとして実行（Linux/Raspberry Pi）

システムサービスとして自動起動させる場合：

```bash
# サービスファイルを作成
sudo nano /etc/systemd/system/raspberry-pi-monitor.service
```

サービスファイルの内容：
```ini
[Unit]
Description=Raspberry Pi Performance Monitor
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/raspberry-pi-monitor
ExecStart=/home/pi/raspberry-pi-monitor/raspberry-pi-monitor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

サービスの有効化と開始：
```bash
sudo systemctl daemon-reload
sudo systemctl enable raspberry-pi-monitor
sudo systemctl start raspberry-pi-monitor
sudo systemctl status raspberry-pi-monitor
```

### 5. 開発時のヒント

#### ライブリロード
開発時はファイル変更を監視して自動再起動するツールが便利です：

```bash
# Air (ライブリロードツール) をインストール
go install github.com/cosmtrek/air@latest

# プロジェクトディレクトリで実行
air
```

#### デバッグモード
```bash
# デバッグ情報付きでビルド
go build -v -x -o raspberry-pi-monitor

# レースコンディションの検出
go run -race main.go
```

#### パフォーマンス最適化
```bash
# 最適化ビルド
go build -ldflags="-s -w" -o raspberry-pi-monitor

# さらにサイズを縮小（UPXを使用）
upx --best raspberry-pi-monitor
```

### 6. 追加の開発ツール

#### VSCode拡張機能
- Go (Google製の公式拡張)
- Go Outliner
- Go Test Explorer

#### 便利なGoツール
```bash
# コードフォーマット
go fmt ./...

# コード品質チェック
go vet ./...

# モジュール脆弱性チェック
go list -json -deps ./... | nancy sleuth

# テストカバレッジ
go test -cover ./...
```

## トラブルシューティング

### よくある問題

1. **「go: command not found」**
   - Goがインストールされていないか、PATHが設定されていない
   - 解決: 上記のインストール手順を確認

2. **権限エラー**
   - ファイルの読み書き権限がない
   - 解決: `chmod +x raspberry-pi-monitor` で実行権限を付与

3. **Port already in use**
   - 8080ポートが既に使用されている
   - 解決: `PORT=8081 ./raspberry-pi-monitor` で別のポートを使用

4. **温度センサーが0°C**
   - Raspberry Pi以外のシステムで実行している
   - 正常動作：Raspberry Piで実行するか、他のセンサーデータが表示される

### パフォーマンス最適化

- メモリ使用量を監視: `ps aux | grep raspberry-pi-monitor`
- CPU使用率を確認: `top -p $(pgrep raspberry-pi-monitor)`
- ネットワーク監視: `netstat -tulpn | grep 8080`