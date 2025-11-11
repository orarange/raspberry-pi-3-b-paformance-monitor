#!/bin/bash

# Raspberry Pi Performance Monitor - 自動セットアップスクリプト
# Usage: curl -sSL https://raw.githubusercontent.com/your-username/raspberry-pi-3-b-paformance-monitor/main/setup.sh | bash

set -e

# 色付きメッセージ関数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# バナー表示
echo -e "${BLUE}"
cat << 'EOF'
  ____                        _                           ____  _ 
 |  _ \ __ _ ___ _ __   ___  __| |    _ __ _ __ ___   _ __ |  _ \(_)
 | |_) / _` / __| '_ \ / _ \/ _` |   | '__| '_ ` _ \ | '_ \| |_) | |
 |  _ < (_| \__ \ |_) |  __/ (_| |   | |  | | | | | | |_) |  __/| |
 |_| \_\__,_|___/ .__/ \___|\__,_|   |_|  |_| |_| |_| .__/|_|   |_|
                |_|                                 |_|            
   ____            __                                         
  |  _ \ ___ _ __ / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___ 
  | |_) / _ \ '__| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
  |  __/  __/ |  |  _| (_) | |  | | | | | | (_| | | | |  __  \
  |_|   \___|_|  |_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\_\
                                                               
   __  __             _ _             
  |  \/  | ___  _ __ (_) |_ ___  _ __ 
  | |\/| |/ _ \| '_ \| | __/ _ \| '__|
  | |  | | (_) | | | | | || (_) | |   
  |_|  |_|\___/|_| |_|_|\__\___/|_|   
                                      
EOF
echo -e "${NC}"

log_info "Raspberry Pi Performance Monitor セットアップスクリプトを開始します"

# 管理者権限チェック
if [[ $EUID -eq 0 ]]; then
   log_error "このスクリプトはrootユーザーでは実行しないでください"
   exit 1
fi

# Raspberry Piかどうかチェック
if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
    log_warning "これはRaspberry Piではないようですが、続行しますか？ (y/N)"
    read -r response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 設定変数
GO_VERSION="1.21.5"
PROJECT_NAME="raspberry-pi-3-b-paformance-monitor"
INSTALL_DIR="$HOME/$PROJECT_NAME"
SERVICE_NAME="raspberry-pi-monitor"

# Step 1: システム更新
log_info "システムを更新しています..."
sudo apt update && sudo apt upgrade -y

# Step 2: 必要なパッケージのインストール
log_info "必要なパッケージをインストールしています..."
sudo apt install -y wget curl git unzip build-essential

# Step 3: Goのインストール
log_info "Go ${GO_VERSION} をインストールしています..."

# 既存のGoを確認
if command -v go &> /dev/null; then
    CURRENT_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    log_info "現在のGoバージョン: $CURRENT_VERSION"
    
    if [[ "$CURRENT_VERSION" == "$GO_VERSION" ]]; then
        log_success "Go $GO_VERSION は既にインストール済みです"
    else
        log_info "Go を更新しています..."
        sudo rm -rf /usr/local/go
    fi
else
    log_info "Go をインストールしています..."
fi

# アーキテクチャを判定
ARCH=$(uname -m)
case $ARCH in
    "armv6l"|"armv7l")
        GO_ARCH="armv6l"
        ;;
    "aarch64")
        GO_ARCH="arm64"
        ;;
    "x86_64")
        GO_ARCH="amd64"
        ;;
    *)
        log_error "サポートされていないアーキテクチャ: $ARCH"
        exit 1
        ;;
esac

# Goバイナリをダウンロード
if [[ ! -d "/usr/local/go" ]]; then
    cd /tmp
    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    
    log_info "$GO_TAR をダウンロードしています..."
    wget -q "https://golang.org/dl/$GO_TAR"
    
    log_info "Go を /usr/local にインストールしています..."
    sudo tar -C /usr/local -xzf "$GO_TAR"
    rm "$GO_TAR"
fi

# Go環境変数の設定
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    log_info "Go環境変数を設定しています..."
    {
        echo ""
        echo "# Go環境変数"
        echo "export PATH=\$PATH:/usr/local/go/bin"
        echo "export GOPATH=\$HOME/go"
        echo "export GOBIN=\$GOPATH/bin"
    } >> ~/.bashrc
fi

# 現在のセッションで環境変数を有効化
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin

# Go作業ディレクトリの作成
mkdir -p "$GOPATH"/{bin,pkg,src}

# Goインストール確認
if /usr/local/go/bin/go version &> /dev/null; then
    log_success "Go $(usr/local/go/bin/go version | awk '{print $3}') のインストールが完了しました"
else
    log_error "Goのインストールに失敗しました"
    exit 1
fi

# Step 4: プロジェクトの取得
log_info "プロジェクトを取得しています..."

# 既存のディレクトリを削除
if [[ -d "$INSTALL_DIR" ]]; then
    log_warning "既存のインストールディレクトリを削除しています..."
    rm -rf "$INSTALL_DIR"
fi

# GitHubからクローン（またはダウンロード）
if command -v git &> /dev/null; then
    log_info "Gitでプロジェクトをクローンしています..."
    git clone "https://github.com/your-username/$PROJECT_NAME.git" "$INSTALL_DIR" || {
        log_warning "Gitクローンに失敗しました。zipファイルをダウンロードします..."
        mkdir -p "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        wget -q "https://github.com/your-username/$PROJECT_NAME/archive/main.zip"
        unzip -q main.zip
        mv "${PROJECT_NAME}-main/"* .
        rm -rf "${PROJECT_NAME}-main" main.zip
    }
else
    log_info "zipファイルでプロジェクトをダウンロードしています..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    wget -q "https://github.com/your-username/$PROJECT_NAME/archive/main.zip"
    unzip -q main.zip
    mv "${PROJECT_NAME}-main/"* .
    rm -rf "${PROJECT_NAME}-main" main.zip
fi

cd "$INSTALL_DIR"

# Step 5: ビルド
log_info "プロジェクトをビルドしています..."

# 依存関係のダウンロード
/usr/local/go/bin/go mod tidy

# ビルド
/usr/local/go/bin/go build -ldflags="-s -w" -o raspberry-pi-monitor

# 実行権限を付与
chmod +x raspberry-pi-monitor

log_success "ビルドが完了しました"

# Step 6: テスト実行
log_info "テスト実行を行っています..."
timeout 5s ./raspberry-pi-monitor &
MONITOR_PID=$!
sleep 3

if kill -0 $MONITOR_PID 2>/dev/null; then
    log_success "アプリケーションの起動に成功しました"
    kill $MONITOR_PID 2>/dev/null || true
else
    log_error "アプリケーションの起動に失敗しました"
    exit 1
fi

# Step 7: システムサービスの設定
log_info "システムサービスを設定しますか？ (Y/n)"
read -r response
if [[ $response =~ ^[Nn]$ ]]; then
    log_info "サービス設定をスキップしました"
else
    log_info "システムサービスを設定しています..."
    
    # サービスファイルを作成
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=Raspberry Pi Performance Monitor
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/raspberry-pi-monitor
Environment=PATH=/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # サービスを有効化
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    
    # ステータス確認
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        log_success "サービスが正常に開始されました"
    else
        log_error "サービスの開始に失敗しました"
        sudo systemctl status $SERVICE_NAME
    fi
fi

# Step 8: ファイアウォール設定
if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
    log_info "ファイアウォールでポート8080を開放しますか？ (Y/n)"
    read -r response
    if [[ ! $response =~ ^[Nn]$ ]]; then
        sudo ufw allow 8080/tcp
        log_success "ポート8080を開放しました"
    fi
fi

# Step 9: 完了メッセージ
log_success "セットアップが完了しました！"

# システム情報を表示
echo -e "\n${BLUE}=== システム情報 ===${NC}"
echo "Go バージョン: $(/usr/local/go/bin/go version)"
echo "インストール先: $INSTALL_DIR"

# IPアドレスを取得
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Raspberry Pi IPアドレス: $IP_ADDRESS"

echo -e "\n${GREEN}=== アクセス方法 ===${NC}"
echo "ローカル: http://localhost:8080"
echo "リモート: http://$IP_ADDRESS:8080"

echo -e "\n${BLUE}=== 便利なコマンド ===${NC}"
echo "手動実行: cd $INSTALL_DIR && ./raspberry-pi-monitor"
echo "サービス状態: sudo systemctl status $SERVICE_NAME"
echo "ログ確認: sudo journalctl -u $SERVICE_NAME -f"
echo "サービス再起動: sudo systemctl restart $SERVICE_NAME"

echo -e "\n${GREEN}セットアップが完了しました！ブラウザでアクセスしてください。${NC}"

# ブラウザを開く提案
if command -v chromium-browser &> /dev/null; then
    log_info "ブラウザを開きますか？ (y/N)"
    read -r response
    if [[ $response =~ ^[Yy]$ ]]; then
        chromium-browser "http://localhost:8080" &
    fi
fi