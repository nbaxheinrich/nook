// SYS // LIVE: cpu, gpu, ram, disk as [████░░░░] bars, network as sparklines, uptime.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root
    readonly property string mono: Kirigami.Theme.fixedWidthFont.family
    readonly property string blocks: "▁▂▃▄▅▆▇█"
    property var down: []
    property var up: []

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: cpuTemp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpu; sensorId: "gpu/gpu1/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu1/temperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Sensors.Sensor { id: ramUsed; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: disk; sensorId: "disk/all/usedPercent"; updateRateLimit: 5000 }
    Sensors.Sensor { id: dl; sensorId: "network/all/download"; updateRateLimit: 1000 }
    Sensors.Sensor { id: ul; sensorId: "network/all/upload"; updateRateLimit: 1000 }
    Sensors.Sensor { id: host; sensorId: "os/system/hostname" }
    Sensors.Sensor { id: uptime; sensorId: "os/system/uptime"; updateRateLimit: 30000 }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.down = root.down.concat([Number(dl.value) || 0]).slice(-root.sparkLen)
            root.up = root.up.concat([Number(ul.value) || 0]).slice(-root.sparkLen)
        }
    }
    property int sparkLen: 32

    function bar(pct, n) {
        const v = Math.max(0, Math.min(100, Number(pct) || 0))
        const f = Math.round(v / 100 * n)
        return "[" + "█".repeat(f) + "░".repeat(n - f) + "]"
    }
    function spark(arr) {
        const max = Math.max.apply(null, arr.concat([1]))
        let s = ""
        for (let i = 0; i < root.sparkLen; i++) {
            const v = i < root.sparkLen - arr.length ? 0 : arr[i - (root.sparkLen - arr.length)]
            s += root.blocks[Math.min(7, Math.floor(v / max * 7.99))]
        }
        return s
    }
    function rate(b) {
        b = Number(b) || 0
        if (b > 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b > 1024) return (b / 1024).toFixed(0) + " kB/s"
        return b.toFixed(0) + " B/s"
    }
    function dur(s) {
        s = Number(s) || 0
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + h + "h " + m + "m"
    }

    fullRepresentation: ColumnLayout {
        id: col
        spacing: 2
        readonly property real fs: Math.max(11, Math.min(width / 30, height / 15))
        readonly property int cells: Math.max(8, Math.floor((width - fs * 0.6 * 22) / (fs * 0.6)))
        onCellsChanged: root.sparkLen = cells + 2

        component Row3: RowLayout {
            property string label
            property color hue
            property string barText
            property string value
            Layout.fillWidth: true
            spacing: col.fs * 0.6
            Text { text: label; color: hue; font { family: root.mono; pixelSize: col.fs; bold: true } Layout.preferredWidth: col.fs * 0.6 * 5 }
            Text { text: barText; color: hue; font { family: root.mono; pixelSize: col.fs } }
            Item { Layout.fillWidth: true }
            Text { text: value; color: "#bfae9f"; font { family: root.mono; pixelSize: col.fs } }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "SYS // LIVE"; color: "#c4b2f5"; font { family: root.mono; pixelSize: Math.max(10, col.fs * 0.75); bold: true; letterSpacing: 1.4 } }
            Item { Layout.fillWidth: true }
            Text { text: String(host.value || "").toLowerCase(); color: "#7d6d62"; font { family: root.mono; pixelSize: Math.max(10, col.fs * 0.75) } }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#4a3f38"; Layout.bottomMargin: col.fs * 0.4 }

        Row3 { label: "cpu"; hue: "#c4b2f5"; barText: root.bar(cpu.value, col.cells)
               value: Math.round(cpu.value || 0) + "%" + (cpuTemp.value ? " " + Math.round(cpuTemp.value) + "°" : "") }
        Row3 { visible: gpu.value !== undefined && gpu.value !== null; label: "gpu"; hue: "#f5a8c9"; barText: root.bar(gpu.value, col.cells)
               value: Math.round(gpu.value || 0) + "%" + (gpuTemp.value ? " " + Math.round(gpuTemp.value) + "°" : "") }
        Row3 { label: "ram"; hue: "#a6e6bf"; barText: root.bar(ram.value, col.cells)
               value: (Number(ramUsed.value || 0) / 1073741824).toFixed(1) + "G" }
        Row3 { label: "disk"; hue: "#f2e29b"; barText: root.bar(disk.value, col.cells); value: Math.round(disk.value || 0) + "%" }

        Item { Layout.fillHeight: true; Layout.minimumHeight: col.fs * 0.5 }

        Row3 { label: "↓net"; hue: "#a3cdf5"; barText: root.spark(root.down); value: root.rate(dl.value) }
        Row3 { label: "↑net"; hue: "#94dcd6"; barText: root.spark(root.up); value: root.rate(ul.value) }

        Item { Layout.fillHeight: true; Layout.minimumHeight: col.fs * 0.5 }
        Text {
            textFormat: Text.StyledText
            text: "<font color='#a6e6bf'>λ</font> <font color='#bfae9f'>uptime</font> <font color='#f9c49a'>" + root.dur(uptime.value) + "</font>"
            font { family: root.mono; pixelSize: col.fs * 0.9 }
        }
    }
}
