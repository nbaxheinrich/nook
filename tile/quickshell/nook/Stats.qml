// Live system numbers, polled every 2 s and shared by the bar and the SYS widget.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int cpu: 0
    property int ram: 0
    property int disk: 0
    property int temp: 0
    property int gpu: 0
    property int gpuTemp: 0
    property int vram: 0              // % used
    property int vramUsed: 0          // MiB
    property int vramTotal: 0
    property int gpuWatt: 0
    property int gpuFan: 0
    property string gpuName: ""
    property var gpuHist: []
    property var cpuHist: []
    property var netHist: []          // KiB/s down, last 24 samples
    property real rx: 0               // bytes/s
    property real tx: 0

    property var _prevCpu: null
    property var _prevNet: null

    // braille sparkline, one char per sample
    function spark(h, max) {
        const g = "⣀⣠⣤⣴⣶⣾⣿";
        const m = max || Math.max(1, ...h);
        return h.map(v => g[Math.min(6, Math.floor(v / m * 6.99))]).join("");
    }
    // [████░░░░]
    function bar(pct, n) {
        const k = Math.round(pct / 100 * n);
        return "█".repeat(k) + "░".repeat(n - k);
    }
    function rate(b) {
        if (b > 1048576) return (b / 1048576).toFixed(1) + "M";
        if (b > 1024) return Math.round(b / 1024) + "K";
        return Math.round(b) + "B";
    }

    // one read of everything: cpu line, meminfo, root fs, net bytes, a temperature
    Process {
        id: proc
        command: ["sh", "-c",
            "head -1 /proc/stat; " +
            "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print \"mem\",t,a}' /proc/meminfo; " +
            "df -P / | awk 'NR==2{print \"disk\",$5}'; " +
            "awk -F'[: ]+' 'NR>2 && $2!=\"lo\"{r+=$3;t+=$11}END{print \"net\",r,t}' /proc/net/dev; " +
            "for z in /sys/class/hwmon/hwmon*; do n=$(cat $z/name 2>/dev/null); case $n in k10temp|coretemp|zenpower) echo temp $(cat $z/temp1_input); break;; esac; done; " +
            "command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,fan.speed,name --format=csv,noheader,nounits | head -1 | sed 's/, */|/g; s/^/gpu|/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now();
                for (const l of this.text.trim().split("\n")) {
                    if (l.startsWith("gpu|")) {
                        // gpu|util|temp|memUsed|memTotal|watts|fan|name  ("[N/A]" where a card has none)
                        const g = l.trim().split("|");
                        root.gpu = parseInt(g[1]) || 0;
                        root.gpuTemp = parseInt(g[2]) || 0;
                        root.vramUsed = parseInt(g[3]) || 0;
                        root.vramTotal = parseInt(g[4]) || 0;
                        root.vram = root.vramTotal > 0 ? Math.round(root.vramUsed * 100 / root.vramTotal) : 0;
                        root.gpuWatt = Math.round(parseFloat(g[5]) || 0);
                        root.gpuFan = parseInt(g[6]) || 0;
                        root.gpuName = (g[7] || "").replace(/^NVIDIA (GeForce )?/, "").toLowerCase();
                        root.gpuHist = root.gpuHist.concat([root.gpu]).slice(-24);
                        continue;
                    }
                    const f = l.trim().split(/\s+/);
                    if (f[0] === "cpu") {
                        const v = f.slice(1).map(Number);
                        const idle = v[3] + v[4], total = v.reduce((a, b) => a + b, 0);
                        if (root._prevCpu) {
                            const dt = total - root._prevCpu.total, di = idle - root._prevCpu.idle;
                            root.cpu = dt > 0 ? Math.round((dt - di) * 100 / dt) : 0;
                            root.cpuHist = root.cpuHist.concat([root.cpu]).slice(-12);
                        }
                        root._prevCpu = { idle, total };
                    } else if (f[0] === "mem") {
                        root.ram = Math.round((1 - Number(f[2]) / Number(f[1])) * 100);
                    } else if (f[0] === "disk") {
                        root.disk = parseInt(f[1]);
                    } else if (f[0] === "net") {
                        const r = Number(f[1]), t = Number(f[2]);
                        if (root._prevNet) {
                            const s = (now - root._prevNet.at) / 1000;
                            root.rx = Math.max(0, (r - root._prevNet.r) / s);
                            root.tx = Math.max(0, (t - root._prevNet.t) / s);
                            root.netHist = root.netHist.concat([root.rx / 1024]).slice(-24);
                        }
                        root._prevNet = { r, t, at: now };
                    } else if (f[0] === "temp") {
                        root.temp = Math.round(Number(f[1]) / 1000);
                    }
                }
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: proc.running = true
    }
}
