package monitor

import (
	"log"
	"runtime"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

// SystemStats システム統計情報を格納する構造体
type SystemStats struct {
	Timestamp    time.Time `json:"timestamp"`
	CPUPercent   float64   `json:"cpu_percent"`
	MemoryUsed   uint64    `json:"memory_used"`
	MemoryTotal  uint64    `json:"memory_total"`
	MemoryPercent float64  `json:"memory_percent"`
	DiskUsed     uint64    `json:"disk_used"`
	DiskTotal    uint64    `json:"disk_total"`
	DiskPercent  float64   `json:"disk_percent"`
	Temperature  float64   `json:"temperature"`
	NetworkRx    uint64    `json:"network_rx"`
	NetworkTx    uint64    `json:"network_tx"`
	Uptime       uint64    `json:"uptime"`
	LoadAvg      float64   `json:"load_avg"`
	GoRoutines   int       `json:"goroutines"`
}

// SystemMonitor システム監視を行う構造体
type SystemMonitor struct {
	prevNetRx uint64
	prevNetTx uint64
}

// NewSystemMonitor 新しいSystemMonitorインスタンスを作成
func NewSystemMonitor() *SystemMonitor {
	return &SystemMonitor{}
}

// GetStats 現在のシステム統計情報を取得
func (sm *SystemMonitor) GetStats() *SystemStats {
	stats := &SystemStats{
		Timestamp: time.Now(),
	}

	// CPU使用率を取得
	if cpuPercent, err := cpu.Percent(time.Second, false); err == nil && len(cpuPercent) > 0 {
		stats.CPUPercent = cpuPercent[0]
	}

	// メモリ使用量を取得
	if vmStat, err := mem.VirtualMemory(); err == nil {
		stats.MemoryUsed = vmStat.Used
		stats.MemoryTotal = vmStat.Total
		stats.MemoryPercent = vmStat.UsedPercent
	}

	// ディスク使用量を取得（ルートパーティション）
	if diskStat, err := disk.Usage("/"); err == nil {
		stats.DiskUsed = diskStat.Used
		stats.DiskTotal = diskStat.Total
		stats.DiskPercent = diskStat.UsedPercent
	}

	// 温度を取得（Linux/Raspberry Pi向け）
	stats.Temperature = sm.getTemperature()

	// ネットワーク使用量を取得
	if netStats, err := net.IOCounters(false); err == nil && len(netStats) > 0 {
		totalRx := netStats[0].BytesRecv
		totalTx := netStats[0].BytesSent
		
		stats.NetworkRx = totalRx
		stats.NetworkTx = totalTx
		
		sm.prevNetRx = totalRx
		sm.prevNetTx = totalTx
	}

	// システム稼働時間を取得
	if hostStat, err := host.Info(); err == nil {
		stats.Uptime = hostStat.Uptime
	}

	// ロードアベレージを取得
	if loadStat, err := load.Avg(); err == nil {
		stats.LoadAvg = loadStat.Load1
	}

	// Goルーチン数を取得
	stats.GoRoutines = runtime.NumGoroutine()

	return stats
}

// getTemperature Raspberry Piの温度を取得
func (sm *SystemMonitor) getTemperature() float64 {
	// host.SensorsTemperatures()を使用して温度を取得
	if temps, err := host.SensorsTemperatures(); err == nil {
		for _, temp := range temps {
			// Raspberry Piの場合、通常"cpu_thermal"という名前
			if temp.SensorKey == "cpu_thermal" || 
			   temp.SensorKey == "thermal_zone0" ||
			   temp.SensorKey == "coretemp" {
				return temp.Temperature
			}
		}
		// 最初の温度センサーの値を返す
		if len(temps) > 0 {
			return temps[0].Temperature
		}
	}

	// 温度が取得できない場合は0を返す
	return 0.0
}

// StartMonitoring 定期的なシステム監視を開始
func (sm *SystemMonitor) StartMonitoring(interval time.Duration, callback func(*SystemStats)) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	log.Printf("System monitoring started with interval: %v", interval)

	for {
		select {
		case <-ticker.C:
			stats := sm.GetStats()
			callback(stats)
		}
	}
}