# マルチステージビルドを使用してサイズを最小化
FROM golang:1.21-alpine AS builder

# 必要なパッケージをインストール
RUN apk add --no-cache git

# 作業ディレクトリを設定
WORKDIR /app

# Go modulesファイルをコピー
COPY go.mod go.sum ./

# 依存関係をダウンロード
RUN go mod download

# ソースコードをコピー
COPY . .

# バイナリをビルド（静的リンク）
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o raspberry-pi-monitor .

# 本番環境用の軽量イメージ
FROM alpine:latest

# セキュリティアップデートとCA証明書
RUN apk --no-cache add ca-certificates tzdata

# 非rootユーザーを作成
RUN adduser -D -s /bin/sh appuser

WORKDIR /home/appuser/

# バイナリとWebファイルをコピー
COPY --from=builder /app/raspberry-pi-monitor .
COPY --from=builder /app/web ./web

# 所有権を変更
RUN chown -R appuser:appuser /home/appuser/

# 非rootユーザーに切り替え
USER appuser

# ポートを公開
EXPOSE 8080

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# アプリケーションを実行
CMD ["./raspberry-pi-monitor"]