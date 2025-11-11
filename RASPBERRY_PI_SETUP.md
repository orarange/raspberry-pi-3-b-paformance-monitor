# 🍓 Raspberry Pi でのセットアップガイド

このガイドでは、Raspberry Pi 3 B+ でパフォーマンスモニタを実行するための完全な手順を説明します。

## 📋 前提条件

- Raspberry Pi 3 B+ (Raspberry Pi OS インストール済み)
- インターネット接続
- SSH または直接アクセス可能

## 🚀 ステップ 1: Raspberry Pi の準備

### システムの更新
```bash
sudo apt update
sudo apt upgrade -y
```

### 必要なツールのインストール
```bash
sudo apt install -y wget curl git unzip
```

## 🔧 ステップ 2: Go言語のインストール

### 方法A: 公式バイナリの使用（推奨）
```bash
# 作業ディレクトリに移動
cd /tmp

# Raspberry Pi 3 B+ 用 Go をダウンロード
wget https://golang.org/dl/go1.21.5.linux-armv6l.tar.gz

# 既存のGoを削除（もしあれば）
sudo rm -rf /usr/local/go

# Goを展開
sudo tar -C /usr/local -xzf go1.21.5.linux-armv6l.tar.gz

# 環境変数を設定
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export GOBIN=$GOPATH/bin' >> ~/.bashrc

# 設定を反映
source ~/.bashrc

# インストール確認
go version
```

### 方法B: パッケージマネージャーの使用
```bash
# より簡単だが、バージョンが古い可能性あり
sudo apt install golang-go
go version
```

## 📦 ステップ 3: プロジェクトの取得

### 方法A: GitHubからクローン
```bash
cd ~
git clone https://github.com/your-username/raspberry-pi-3-b-paformance-monitor.git
cd raspberry-pi-3-b-paformance-monitor
```

### 方法B: ファイル転送
```bash
# SCPを使用してファイルを転送
# 別のマシンから実行:
scp -r /path/to/raspberry-pi-3-b-paformance-monitor pi@raspberry-pi-ip:~/

# Raspberry Pi側で:
cd ~/raspberry-pi-3-b-paformance-monitor
```

### 方法C: アーカイブファイルのダウンロード
```bash
cd ~
wget https://github.com/your-username/raspberry-pi-3-b-paformance-monitor/archive/main.zip
unzip main.zip
mv raspberry-pi-3-b-paformance-monitor-main raspberry-pi-3-b-paformance-monitor
cd raspberry-pi-3-b-paformance-monitor
```

## 🔨 ステップ 4: ビルドと実行

### 依存関係のインストール
```bash
go mod tidy
```

### ビルド
```bash
# 現在のプラットフォーム用にビルド
go build -o raspberry-pi-monitor

# または最適化ビルド
go build -ldflags="-s -w" -o raspberry-pi-monitor
```

### 実行
```bash
# フォアグラウンドで実行
./raspberry-pi-monitor

# バックグラウンドで実行
nohup ./raspberry-pi-monitor > monitor.log 2>&1 &
```

## 🌐 ステップ 5: アクセス確認

### ローカルアクセス
```bash
# Raspberry Pi上のブラウザで
chromium-browser http://localhost:8080
```

### リモートアクセス
```bash
# Raspberry PiのIPアドレスを確認
ip addr show

# 他のデバイスから以下のURLにアクセス
# http://RASPBERRY_PI_IP:8080
```

## ⚙️ ステップ 6: システムサービスとして設定（オプション）

### サービスファイルの作成
```bash
sudo nano /etc/systemd/system/raspberry-pi-monitor.service
```

### サービスファイルの内容
```ini
[Unit]
Description=Raspberry Pi Performance Monitor
After=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/raspberry-pi-3-b-paformance-monitor
ExecStart=/home/pi/raspberry-pi-3-b-paformance-monitor/raspberry-pi-monitor
Environment=PATH=/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### サービスの有効化と開始
```bash
# サービスをリロード
sudo systemctl daemon-reload

# サービスを有効化（自動起動）
sudo systemctl enable raspberry-pi-monitor

# サービスを開始
sudo systemctl start raspberry-pi-monitor

# ステータス確認
sudo systemctl status raspberry-pi-monitor

# ログ確認
sudo journalctl -u raspberry-pi-monitor -f
```

## 🛡️ ステップ 7: ファイアウォール設定（必要に応じて）

```bash
# ufwが有効な場合、ポート8080を許可
sudo ufw allow 8080/tcp

# ufwの状態確認
sudo ufw status
```

## 📊 ステップ 8: 動作確認

### コマンドラインでの確認
```bash
# プロセス確認
ps aux | grep raspberry-pi-monitor

# ポート確認
netstat -tulpn | grep 8080

# APIエンドポイント確認
curl http://localhost:8080/api/stats

# ヘルスチェック
curl http://localhost:8080/health
```

### ブラウザでの確認
1. ブラウザで `http://RASPBERRY_PI_IP:8080` を開く
2. ダッシュボードが表示されることを確認
3. リアルタイムでデータが更新されることを確認

## 🔧 ステップ 9: トラブルシューティング

### よくある問題と解決方法

#### 1. ポートが使用中
```bash
# ポートを使用しているプロセスを確認
sudo lsof -i :8080

# プロセスを終了
sudo kill -9 <PID>

# または別のポートを使用
PORT=8081 ./raspberry-pi-monitor
```

#### 2. 権限エラー
```bash
# 実行権限を付与
chmod +x raspberry-pi-monitor

# ディレクトリの所有権を確認
ls -la ~/raspberry-pi-3-b-paformance-monitor/
```

#### 3. メモリ不足
```bash
# スワップファイルを増やす
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=1024 に変更
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# メモリ使用量確認
free -h
```

#### 4. 温度センサーが動作しない
```bash
# 温度センサーの確認
cat /sys/class/thermal/thermal_zone0/temp

# センサーファイルの存在確認
ls -la /sys/class/thermal/
```

## 🔄 ステップ 10: 更新とメンテナンス

### アプリケーションの更新
```bash
cd ~/raspberry-pi-3-b-paformance-monitor

# 最新版を取得
git pull origin main

# 再ビルド
go build -ldflags="-s -w" -o raspberry-pi-monitor

# サービスを再起動
sudo systemctl restart raspberry-pi-monitor
```

### ログの管理
```bash
# ログローテーション設定
sudo nano /etc/logrotate.d/raspberry-pi-monitor

# 内容例:
/home/pi/raspberry-pi-3-b-paformance-monitor/monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

## 📈 ステップ 11: パフォーマンス最適化

### システム最適化
```bash
# GPU メモリを最小に設定（ヘッドレスの場合）
sudo nano /boot/config.txt
# gpu_mem=16 を追加

# 不要なサービスを停止
sudo systemctl disable bluetooth
sudo systemctl disable cups

# CPUガバナーを設定
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### アプリケーション最適化
```bash
# 軽量ビルド
go build -ldflags="-s -w" -tags netgo -a -installsuffix netgo -o raspberry-pi-monitor
```

## 🔗 便利なコマンド集

```bash
# サービス管理
sudo systemctl start raspberry-pi-monitor     # 開始
sudo systemctl stop raspberry-pi-monitor      # 停止
sudo systemctl restart raspberry-pi-monitor   # 再起動
sudo systemctl status raspberry-pi-monitor    # 状態確認

# ログ確認
sudo journalctl -u raspberry-pi-monitor -n 50 # 最新50行
sudo journalctl -u raspberry-pi-monitor -f    # リアルタイム

# リソース監視
htop                    # プロセス監視
df -h                   # ディスク使用量
free -h                 # メモリ使用量
vcgencmd measure_temp   # CPU温度
```

これで Raspberry Pi でのパフォーマンスモニタのセットアップが完了です！