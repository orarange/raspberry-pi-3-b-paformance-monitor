# Raspberry Pi Performance Monitor Makefile

# 変数定義
BINARY_NAME=raspberry-pi-monitor
MAIN_PACKAGE=.
BUILD_DIR=build
VERSION=$(shell git describe --tags --always --dirty)
BUILD_TIME=$(shell date -u +%Y%m%d.%H%M%S)
LDFLAGS=-ldflags="-s -w -X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME}"

# デフォルトターゲット
.DEFAULT_GOAL := build

# ヘルプメッセージ
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build        - Build for current platform"
	@echo "  build-all    - Build for all supported platforms"
	@echo "  run          - Run the application in development mode"
	@echo "  test         - Run tests"
	@echo "  clean        - Clean build artifacts"
	@echo "  docker       - Build Docker image"
	@echo "  docker-run   - Run Docker container"
	@echo "  install      - Install dependencies"
	@echo "  fmt          - Format code"
	@echo "  vet          - Run go vet"
	@echo "  lint         - Run golangci-lint"

# 依存関係のインストール
.PHONY: install
install:
	go mod download
	go mod tidy

# コードフォーマット
.PHONY: fmt
fmt:
	go fmt ./...

# Go vetによるコード検査
.PHONY: vet
vet:
	go vet ./...

# golangci-lintによるコード解析
.PHONY: lint
lint:
	golangci-lint run

# テスト実行
.PHONY: test
test:
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# ベンチマークテスト
.PHONY: bench
bench:
	go test -bench=. -benchmem ./...

# 現在のプラットフォーム向けビルド
.PHONY: build
build:
	@mkdir -p ${BUILD_DIR}
	go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME} ${MAIN_PACKAGE}

# 全プラットフォーム向けビルド
.PHONY: build-all
build-all: clean
	@echo "Building for all platforms..."
	@mkdir -p ${BUILD_DIR}
	
	# Linux AMD64
	GOOS=linux GOARCH=amd64 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-linux-amd64 ${MAIN_PACKAGE}
	
	# Linux ARM64 (Raspberry Pi 4)
	GOOS=linux GOARCH=arm64 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-linux-arm64 ${MAIN_PACKAGE}
	
	# Linux ARMv7 (Raspberry Pi 3 B+)
	GOOS=linux GOARCH=arm GOARM=7 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-linux-armv7 ${MAIN_PACKAGE}
	
	# Linux ARMv6 (Raspberry Pi Zero)
	GOOS=linux GOARCH=arm GOARM=6 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-linux-armv6 ${MAIN_PACKAGE}
	
	# Windows AMD64
	GOOS=windows GOARCH=amd64 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-windows-amd64.exe ${MAIN_PACKAGE}
	
	# macOS AMD64
	GOOS=darwin GOARCH=amd64 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-darwin-amd64 ${MAIN_PACKAGE}
	
	# macOS ARM64 (Apple Silicon)
	GOOS=darwin GOARCH=arm64 go build ${LDFLAGS} -o ${BUILD_DIR}/${BINARY_NAME}-darwin-arm64 ${MAIN_PACKAGE}
	
	@echo "Build completed. Binaries are in ${BUILD_DIR}/"
	@ls -la ${BUILD_DIR}/

# 開発モードで実行
.PHONY: run
run:
	go run ${MAIN_PACKAGE}

# ホットリロード（Airが必要）
.PHONY: dev
dev:
	air

# クリーンアップ
.PHONY: clean
clean:
	rm -rf ${BUILD_DIR}
	rm -f coverage.out coverage.html

# Dockerイメージのビルド
.PHONY: docker
docker:
	docker build -t ${BINARY_NAME}:latest .
	docker build -t ${BINARY_NAME}:${VERSION} .

# Dockerコンテナの実行
.PHONY: docker-run
docker-run:
	docker run -p 8080:8080 --name ${BINARY_NAME} ${BINARY_NAME}:latest

# Docker Composeで実行
.PHONY: docker-compose-up
docker-compose-up:
	docker-compose up -d

.PHONY: docker-compose-down
docker-compose-down:
	docker-compose down

# リリースの準備
.PHONY: release
release: test build-all
	@echo "Creating release archives..."
	@mkdir -p ${BUILD_DIR}/archives
	
	# Linux用アーカイブ
	tar -czf ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-linux-amd64.tar.gz -C ${BUILD_DIR} ${BINARY_NAME}-linux-amd64 -C ../web .
	tar -czf ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-linux-arm64.tar.gz -C ${BUILD_DIR} ${BINARY_NAME}-linux-arm64 -C ../web .
	tar -czf ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-linux-armv7.tar.gz -C ${BUILD_DIR} ${BINARY_NAME}-linux-armv7 -C ../web .
	tar -czf ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-linux-armv6.tar.gz -C ${BUILD_DIR} ${BINARY_NAME}-linux-armv6 -C ../web .
	
	# Windows用アーカイブ
	zip -j ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-windows-amd64.zip ${BUILD_DIR}/${BINARY_NAME}-windows-amd64.exe
	cd web && zip -r ../${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-windows-amd64.zip . && cd ..
	
	# macOS用アーカイブ
	tar -czf ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-darwin-amd64.tar.gz -C ${BUILD_DIR} ${BINARY_NAME}-darwin-amd64 -C ../web .
	tar -czf ${BUILD_DIR}/archives/${BINARY_NAME}-${VERSION}-darwin-arm64.tar.gz -C ${BUILD_DIR} ${BINARY_NAME}-darwin-arm64 -C ../web .
	
	@echo "Release archives created in ${BUILD_DIR}/archives/"
	@ls -la ${BUILD_DIR}/archives/

# インストール（システム全体）
.PHONY: install-system
install-system: build
	sudo cp ${BUILD_DIR}/${BINARY_NAME} /usr/local/bin/
	sudo mkdir -p /opt/raspberry-pi-monitor
	sudo cp -r web /opt/raspberry-pi-monitor/
	@echo "Installed to /usr/local/bin/${BINARY_NAME}"

# アンインストール
.PHONY: uninstall
uninstall:
	sudo rm -f /usr/local/bin/${BINARY_NAME}
	sudo rm -rf /opt/raspberry-pi-monitor
	@echo "Uninstalled ${BINARY_NAME}"

# 開発ツールのインストール
.PHONY: install-dev-tools
install-dev-tools:
	go install github.com/cosmtrek/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "Development tools installed"

# バージョン情報の表示
.PHONY: version
version:
	@echo "Version: ${VERSION}"
	@echo "Build Time: ${BUILD_TIME}"

# プロジェクト統計
.PHONY: stats
stats:
	@echo "Project Statistics:"
	@echo "=================="
	@echo "Go files:"
	@find . -name "*.go" -not -path "./vendor/*" | wc -l
	@echo "Lines of Go code:"
	@find . -name "*.go" -not -path "./vendor/*" -exec wc -l {} \; | awk '{sum += $$1} END {print sum}'
	@echo "JavaScript files:"
	@find web -name "*.js" | wc -l
	@echo "CSS files:"
	@find web -name "*.css" | wc -l
	@echo "HTML files:"
	@find web -name "*.html" | wc -l