// WebSocket接続とリアルタイムデータ処理
class PerformanceMonitor {
    constructor() {
        this.ws = null;
        this.charts = {};
        this.dataHistory = {
            cpu: [],
            temperature: [],
            network: { rx: [], tx: [] }
        };
        this.maxDataPoints = 60; // 60秒分のデータを保持

        this.initializeCharts();
        this.connectWebSocket();
        this.setupEventListeners();
    }

    // WebSocket接続
    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        this.updateConnectionStatus('connecting', '接続中...');
        
        this.ws = new WebSocket(wsUrl);
        
        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.updateConnectionStatus('connected', '接続済み');
        };
        
        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.updateDashboard(data);
                this.updateCharts(data);
            } catch (error) {
                console.error('Error parsing WebSocket data:', error);
            }
        };
        
        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            this.updateConnectionStatus('disconnected', '切断されました');
            // 3秒後に再接続を試行
            setTimeout(() => this.connectWebSocket(), 3000);
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.updateConnectionStatus('error', 'エラー');
        };
    }

    // 接続ステータスの更新
    updateConnectionStatus(status, text) {
        const indicator = document.getElementById('statusIndicator');
        const statusText = document.getElementById('statusText');
        
        indicator.className = `status-indicator ${status}`;
        statusText.textContent = text;
    }

    // ダッシュボードの更新
    updateDashboard(data) {
        // CPU使用率
        this.updateCircularProgress('cpu', data.cpu_percent);
        
        // メモリ使用量
        this.updateCircularProgress('memory', data.memory_percent);
        document.getElementById('memoryUsed').textContent = Math.round(data.memory_used / 1024 / 1024);
        document.getElementById('memoryTotal').textContent = Math.round(data.memory_total / 1024 / 1024);
        
        // 温度
        this.updateTemperature(data.temperature);
        
        // ディスク使用量
        this.updateCircularProgress('disk', data.disk_percent);
        document.getElementById('diskUsed').textContent = Math.round(data.disk_used / 1024 / 1024 / 1024);
        document.getElementById('diskTotal').textContent = Math.round(data.disk_total / 1024 / 1024 / 1024);
        
        // ネットワーク
        document.getElementById('networkRx').textContent = this.formatBytes(data.network_rx);
        document.getElementById('networkTx').textContent = this.formatBytes(data.network_tx);
        
        // システム情報
        document.getElementById('uptime').textContent = this.formatUptime(data.uptime);
        document.getElementById('goroutines').textContent = data.goroutines;
        document.getElementById('loadAvg').textContent = data.load_avg.toFixed(2);
        document.getElementById('lastUpdate').textContent = new Date(data.timestamp).toLocaleTimeString();
    }

    // 円形プログレスの更新
    updateCircularProgress(type, percentage) {
        const circle = document.getElementById(`${type}Circle`);
        const value = document.getElementById(`${type}Value`);
        
        const circumference = 2 * Math.PI * 50; // r=50
        const offset = circumference - (percentage / 100) * circumference;
        
        circle.style.strokeDashoffset = offset;
        value.textContent = Math.round(percentage);
        
        // 色の変更（使用率に応じて）
        let color;
        if (percentage < 60) color = '#51cf66';
        else if (percentage < 80) color = '#ffd43b';
        else color = '#ff6b6b';
        
        circle.style.stroke = color;
    }

    // 温度表示の更新
    updateTemperature(temperature) {
        document.getElementById('temperatureValue').textContent = Math.round(temperature);
        
        const fill = document.getElementById('temperatureFill');
        const percentage = Math.min(temperature / 100 * 100, 100); // 100°Cを最大とする
        fill.style.width = `${percentage}%`;
    }

    // チャートの初期化
    initializeCharts() {
        this.charts.cpu = this.createChart('cpuChart', '#667eea');
        this.charts.temperature = this.createChart('temperatureChart', '#ff6b6b');
        this.charts.network = this.createNetworkChart('networkChart');
    }

    // シンプルなチャートを作成
    createChart(canvasId, color) {
        const canvas = document.getElementById(canvasId);
        const ctx = canvas.getContext('2d');
        
        return {
            canvas,
            ctx,
            color,
            data: []
        };
    }

    // ネットワークチャートを作成
    createNetworkChart(canvasId) {
        const canvas = document.getElementById(canvasId);
        const ctx = canvas.getContext('2d');
        
        return {
            canvas,
            ctx,
            rxData: [],
            txData: []
        };
    }

    // チャートの更新
    updateCharts(data) {
        // CPUチャートの更新
        this.updateLineChart(this.charts.cpu, data.cpu_percent);
        
        // 温度チャートの更新
        this.updateLineChart(this.charts.temperature, data.temperature);
        
        // ネットワークチャートの更新
        this.updateNetworkChart(data);
    }

    // ライングラフの更新
    updateLineChart(chart, value) {
        chart.data.push(value);
        if (chart.data.length > this.maxDataPoints) {
            chart.data.shift();
        }
        
        this.drawLineChart(chart);
    }

    // ライングラフの描画
    drawLineChart(chart) {
        const { ctx, canvas, data, color } = chart;
        const width = canvas.width;
        const height = canvas.height;
        
        ctx.clearRect(0, 0, width, height);
        
        if (data.length < 2) return;
        
        const max = Math.max(...data, 100);
        const min = Math.min(...data, 0);
        const range = max - min || 1;
        
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        data.forEach((value, index) => {
            const x = (index / (this.maxDataPoints - 1)) * width;
            const y = height - ((value - min) / range) * height;
            
            if (index === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        });
        
        ctx.stroke();
        
        // グラデーション背景
        ctx.globalAlpha = 0.2;
        ctx.fillStyle = color;
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fill();
        ctx.globalAlpha = 1;
    }

    // ネットワークチャートの更新
    updateNetworkChart(data) {
        const chart = this.charts.network;
        
        // 前回のデータと比較して転送レートを計算
        if (this.lastNetworkData) {
            const rxRate = (data.network_rx - this.lastNetworkData.network_rx) / 1024 / 1024; // MB/s
            const txRate = (data.network_tx - this.lastNetworkData.network_tx) / 1024 / 1024; // MB/s
            
            chart.rxData.push(Math.max(0, rxRate));
            chart.txData.push(Math.max(0, txRate));
            
            if (chart.rxData.length > this.maxDataPoints) {
                chart.rxData.shift();
                chart.txData.shift();
            }
        }
        
        this.lastNetworkData = data;
        this.drawNetworkChart(chart);
    }

    // ネットワークチャートの描画
    drawNetworkChart(chart) {
        const { ctx, canvas, rxData, txData } = chart;
        const width = canvas.width;
        const height = canvas.height;
        
        ctx.clearRect(0, 0, width, height);
        
        if (rxData.length < 2) return;
        
        const maxRate = Math.max(...rxData, ...txData, 1);
        
        // RX線の描画
        ctx.strokeStyle = '#51cf66';
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        rxData.forEach((value, index) => {
            const x = (index / (this.maxDataPoints - 1)) * width;
            const y = height - (value / maxRate) * height;
            
            if (index === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        });
        
        ctx.stroke();
        
        // TX線の描画
        ctx.strokeStyle = '#ff6b6b';
        ctx.beginPath();
        
        txData.forEach((value, index) => {
            const x = (index / (this.maxDataPoints - 1)) * width;
            const y = height - (value / maxRate) * height;
            
            if (index === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        });
        
        ctx.stroke();
    }

    // イベントリスナーの設定
    setupEventListeners() {
        // ページの可視性が変わった時の処理
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                console.log('Page hidden - reducing update frequency');
            } else {
                console.log('Page visible - restoring update frequency');
            }
        });
        
        // ウィンドウサイズ変更時のチャート再描画
        window.addEventListener('resize', () => {
            setTimeout(() => {
                Object.values(this.charts).forEach(chart => {
                    if (chart.data) {
                        this.drawLineChart(chart);
                    } else if (chart.rxData) {
                        this.drawNetworkChart(chart);
                    }
                });
            }, 100);
        });
    }

    // ユーティリティ関数
    formatBytes(bytes) {
        if (bytes === 0) return '0 B';
        
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        
        if (days > 0) {
            return `${days}日 ${hours}時間 ${minutes}分`;
        } else if (hours > 0) {
            return `${hours}時間 ${minutes}分`;
        } else {
            return `${minutes}分`;
        }
    }
}

// アプリケーション開始
document.addEventListener('DOMContentLoaded', () => {
    console.log('Starting Raspberry Pi Performance Monitor Dashboard');
    new PerformanceMonitor();
});