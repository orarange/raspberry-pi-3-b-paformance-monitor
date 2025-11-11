package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"raspberry-pi-monitor/monitor"
)

const (
	// デフォルトポート
	DefaultPort = ":8080"
	// システム監視間隔（1秒）
	MonitorInterval = time.Second
)

func main() {
	log.Println("Starting Raspberry Pi Performance Monitor...")

	// WebSocketハブを作成して開始
	hub := monitor.NewWebSocketHub()
	go hub.Run()

	// システムモニターを作成
	systemMonitor := monitor.NewSystemMonitor()

	// システム監視を開始（別のゴルーチンで）
	go systemMonitor.StartMonitoring(MonitorInterval, func(stats *monitor.SystemStats) {
		hub.BroadcastStats(stats)
		
		// ログに基本情報を出力（デバッグ用）
		log.Printf("CPU: %.1f%%, Memory: %.1f%%, Temp: %.1f°C, Clients: %d",
			stats.CPUPercent,
			stats.MemoryPercent,
			stats.Temperature,
			hub.GetConnectedClients(),
		)
	})

	// HTTPハンドラーを設定
	setupRoutes(hub)

	// サーバーの起動
	port := getPort()
	log.Printf("Server starting on http://localhost%s", port)
	log.Printf("Dashboard available at: http://localhost%s", port)

	// Graceful shutdownの設定
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	// サーバーを別のゴルーチンで起動
	go func() {
		if err := http.ListenAndServe(port, nil); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// シャットダウンシグナルを待機
	<-c
	log.Println("Shutting down server...")
}

// setupRoutes HTTPルートを設定
func setupRoutes(hub *monitor.WebSocketHub) {
	// 静的ファイルの配信
	http.HandleFunc("/", serveHome)
	http.HandleFunc("/app.js", serveFile("web/app.js", "application/javascript"))
	http.HandleFunc("/style.css", serveFile("web/style.css", "text/css"))

	// WebSocketエンドポイント
	http.HandleFunc("/ws", hub.HandleWebSocket)

	// APIエンドポイント（RESTful API用、オプション）
	http.HandleFunc("/api/stats", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		systemMonitor := monitor.NewSystemMonitor()
		stats := systemMonitor.GetStats()

		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		
		// JSONレスポンスを返す
		fmt.Fprintf(w, `{
			"timestamp": "%s",
			"cpu_percent": %.2f,
			"memory_used": %d,
			"memory_total": %d,
			"memory_percent": %.2f,
			"disk_used": %d,
			"disk_total": %d,
			"disk_percent": %.2f,
			"temperature": %.2f,
			"network_rx": %d,
			"network_tx": %d,
			"uptime": %d,
			"load_avg": %.2f,
			"goroutines": %d
		}`,
			stats.Timestamp.Format(time.RFC3339),
			stats.CPUPercent,
			stats.MemoryUsed,
			stats.MemoryTotal,
			stats.MemoryPercent,
			stats.DiskUsed,
			stats.DiskTotal,
			stats.DiskPercent,
			stats.Temperature,
			stats.NetworkRx,
			stats.NetworkTx,
			stats.Uptime,
			stats.LoadAvg,
			stats.GoRoutines,
		)
	})

	// ヘルスチェックエンドポイント
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status": "healthy", "timestamp": "%s"}`, time.Now().Format(time.RFC3339))
	})
}

// serveHome メインページを配信
func serveHome(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	http.ServeFile(w, r, "web/index.html")
}

// serveFile 静的ファイルを配信するハンドラーを生成
func serveFile(filename, contentType string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// ファイルの存在確認
		if _, err := os.Stat(filename); os.IsNotExist(err) {
			http.Error(w, "File not found", http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "no-cache")
		http.ServeFile(w, r, filename)
	}
}

// getPort 環境変数またはデフォルトポートを取得
func getPort() string {
	port := os.Getenv("PORT")
	if port == "" {
		return DefaultPort
	}
	if port[0] != ':' {
		port = ":" + port
	}
	return port
}

// getCurrentDir 現在のディレクトリを取得
func getCurrentDir() string {
	if dir, err := filepath.Abs("."); err == nil {
		return dir
	}
	return "."
}