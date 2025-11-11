package monitor

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebSocketHub WebSocket接続を管理するハブ
type WebSocketHub struct {
	// 登録されたクライアント
	clients map[*Client]bool

	// インバウンドメッセージのチャンネル
	broadcast chan []byte

	// クライアント登録のリクエスト
	register chan *Client

	// クライアント登録解除のリクエスト
	unregister chan *Client

	// ミューテックス
	mutex sync.RWMutex
}

// Client WebSocketクライアントを表現する構造体
type Client struct {
	hub  *WebSocketHub
	conn *websocket.Conn
	send chan []byte
}

// WebSocketアップグレーダー
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// 本番環境では適切なオリジンチェックを実装
		return true
	},
}

// NewWebSocketHub 新しいWebSocketハブを作成
func NewWebSocketHub() *WebSocketHub {
	return &WebSocketHub{
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
	}
}

// Run WebSocketハブを開始
func (h *WebSocketHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mutex.Lock()
			h.clients[client] = true
			h.mutex.Unlock()
			log.Printf("Client connected. Total clients: %d", len(h.clients))

		case client := <-h.unregister:
			h.mutex.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mutex.Unlock()
			log.Printf("Client disconnected. Total clients: %d", len(h.clients))

		case message := <-h.broadcast:
			h.mutex.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					delete(h.clients, client)
					close(client.send)
				}
			}
			h.mutex.RUnlock()
		}
	}
}

// BroadcastStats システム統計をすべてのクライアントにブロードキャスト
func (h *WebSocketHub) BroadcastStats(stats *SystemStats) {
	data, err := json.Marshal(stats)
	if err != nil {
		log.Printf("Error marshaling stats: %v", err)
		return
	}
	
	select {
	case h.broadcast <- data:
	default:
		log.Println("Broadcast channel is full, dropping message")
	}
}

// HandleWebSocket WebSocket接続を処理
func (h *WebSocketHub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	client := &Client{
		hub:  h,
		conn: conn,
		send: make(chan []byte, 256),
	}

	client.hub.register <- client

	// 別のゴルーチンでクライアントの送受信を処理
	go client.writePump()
	go client.readPump()
}

// readPump クライアントからのメッセージを読み取り
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	// タイムアウトを設定
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		// メッセージタイプを読み取り（実際のメッセージ処理は必要に応じて実装）
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}
	}
}

// writePump クライアントにメッセージを送信
func (c *Client) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// キューにある追加のメッセージを送信
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// GetConnectedClients 接続されているクライアント数を取得
func (h *WebSocketHub) GetConnectedClients() int {
	h.mutex.RLock()
	defer h.mutex.RUnlock()
	return len(h.clients)
}