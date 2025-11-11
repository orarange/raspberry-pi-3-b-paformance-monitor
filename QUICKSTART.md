# 🚀 Raspberry Pi クイックスタート

このプログラムをRaspberry Piで使用するための最短手順です。

## 📦 ワンライナーインストール

```bash
curl -sSL https://raw.githubusercontent.com/your-username/raspberry-pi-3-b-paformance-monitor/main/setup.sh | bash
```

**これだけでセットアップ完了！** ブラウザで `http://RASPBERRY_PI_IP:8080` にアクセスしてください。

---

## 🔧 手動セットアップ（3ステップ）

### 1️⃣ Go のインストール
```bash
# Go 1.21.5 をダウンロード＆インストール
wget https://golang.org/dl/go1.21.5.linux-armv6l.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.5.linux-armv6l.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### 2️⃣ プロジェクトの取得＆ビルド
```bash
# GitHubからクローン
git clone https://github.com/your-username/raspberry-pi-3-b-paformance-monitor.git
cd raspberry-pi-3-b-paformance-monitor

# ビルド
go mod tidy
go build -o raspberry-pi-monitor
```

### 3️⃣ 実行
```bash
# 実行
./raspberry-pi-monitor

# ブラウザでアクセス: http://localhost:8080
```

---

## 🔄 システムサービス化（自動起動）

```bash
# サービスファイル作成
sudo nano /etc/systemd/system/raspberry-pi-monitor.service

# 以下を入力:
[Unit]
Description=Raspberry Pi Performance Monitor
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/raspberry-pi-3-b-paformance-monitor
ExecStart=/home/pi/raspberry-pi-3-b-paformance-monitor/raspberry-pi-monitor
Restart=always

[Install]
WantedBy=multi-user.target

# サービス有効化
sudo systemctl daemon-reload
sudo systemctl enable raspberry-pi-monitor
sudo systemctl start raspberry-pi-monitor
```

---

## 📱 アクセス方法

### ローカルアクセス
- URL: `http://localhost:8080`

### リモートアクセス
```bash
# Raspberry PiのIPアドレスを確認
hostname -I

# ブラウザで以下にアクセス:
# http://RASPBERRY_PI_IP:8080
```

---

## 🛠️ トラブルシューティング

### よくある問題

**Q: `go: command not found`**
```bash
# Goが正しくインストールされているか確認
/usr/local/go/bin/go version

# PATHを再設定
export PATH=$PATH:/usr/local/go/bin
```

**Q: ポート8080が使用中**
```bash
# 使用中のプロセスを確認
sudo lsof -i :8080

# 別のポートで実行
PORT=8081 ./raspberry-pi-monitor
```

**Q: 権限エラー**
```bash
# 実行権限を付与
chmod +x raspberry-pi-monitor
```

**Q: メモリ不足**
```bash
# スワップ容量を増やす
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

---

## 📊 確認コマンド

```bash
# アプリケーション状態
ps aux | grep raspberry-pi-monitor

# ポート確認
netstat -tulpn | grep 8080

# サービス状態
sudo systemctl status raspberry-pi-monitor

# ログ確認
sudo journalctl -u raspberry-pi-monitor -f

# API テスト
curl http://localhost:8080/api/stats
```

---

## 🎯 主な機能

- ✅ **CPU使用率**: リアルタイムグラフ表示
- ✅ **メモリ使用量**: 使用率と詳細情報
- ✅ **CPU温度**: Raspberry Pi専用センサー対応
- ✅ **ディスク使用量**: 容量と使用率
- ✅ **ネットワーク**: 送受信データ量
- ✅ **システム情報**: 稼働時間、ロードアベレージ

---

## 🔗 便利なエイリアス

`~/.bashrc` に追加すると便利：

```bash
# エイリアス追加
echo "alias rpi-monitor='cd ~/raspberry-pi-3-b-paformance-monitor && ./raspberry-pi-monitor'" >> ~/.bashrc
echo "alias rpi-monitor-status='sudo systemctl status raspberry-pi-monitor'" >> ~/.bashrc
echo "alias rpi-monitor-logs='sudo journalctl -u raspberry-pi-monitor -f'" >> ~/.bashrc
echo "alias rpi-monitor-restart='sudo systemctl restart raspberry-pi-monitor'" >> ~/.bashrc

# エイリアス有効化
source ~/.bashrc
```

使用例:
```bash
rpi-monitor          # アプリケーション実行
rpi-monitor-status   # サービス状態確認
rpi-monitor-logs     # ログ表示
rpi-monitor-restart  # サービス再起動
```

---

**🎉 これで Raspberry Pi でのパフォーマンス監視が開始できます！**

問題があれば、詳細なセットアップガイド（`RASPBERRY_PI_SETUP.md`）を参照してください。