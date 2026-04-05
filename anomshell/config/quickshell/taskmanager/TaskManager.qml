// TaskManager.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool showing: false
    property var theme: ({})

    readonly property color cBg:      theme.bg     || "#1e1e2e"
    readonly property color cBorder:  theme.dim    || "#45475a"
    readonly property color cFg:      theme.fg     || "#cdd6f4"
    readonly property color cMuted:   theme.muted  || "#585b70"
    readonly property color cAccent:  theme.accent || "#89b4fa"
    readonly property color cDim:     Qt.alpha(cFg, 0.45)
    readonly property color cSurface: Qt.darker(cBg, 1.08)
    readonly property color cGreen:   "#a6e3a1"
    readonly property color cYellow:  "#f9e2af"
    readonly property color cRed:     "#f38ba8"

    function cpuColor(val) {
        const v = Number(val) || 0
        if (v >= 60) return root.cRed
        if (v >= 30) return root.cYellow
        return root.cGreen
    }

    implicitWidth:  860
    implicitHeight: 560
    anchors { left: true; right: true; top: true; bottom: true }
    margins { left: 0; right: 0; top: 0; bottom: 0 }
    color: "transparent"
    visible: showing
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Persist window position ───────────────────────────────────────────────
    property real cardX: Math.max(24, (screen.width  - implicitWidth)  / 2)
    property real cardY: Math.max(24, (screen.height - implicitHeight) / 2)

    function clampCard() {
        const maxX = screen.width  - card.width  - 24
        const maxY = screen.height - card.height - 24
        cardX = Math.max(24, Math.min(maxX, cardX))
        cardY = Math.max(24, Math.min(maxY, cardY))
    }

    onWidthChanged:  clampCard()
    onHeightChanged: clampCard()

    Process {
        id: posLoadProc
        command: ["bash", "-lc", "cat ~/.cache/taskmanager-pos 2>/dev/null || true"]
        stdout: SplitParser {
            property string buf: ""
            onRead: data => buf += data
        }
        running: false
        onExited: {
            const raw = (stdout.buf || "").trim()
            stdout.buf = ""
            const parts = raw.split(",")
            if (parts.length === 2) {
                const x = Number(parts[0])
                const y = Number(parts[1])
                if (Number.isFinite(x) && Number.isFinite(y)) {
                    root.cardX = x
                    root.cardY = y
                    root.clampCard()
                }
            }
        }
    }

    Process {
        id: posSaveProc
        property real sx: 0
        property real sy: 0
        command: ["bash", "-lc", "mkdir -p ~/.cache && printf '%s,%s' '" + sx + "' '" + sy + "' > ~/.cache/taskmanager-pos"]
        running: false
    }

    Timer {
        id: posSaveTimer
        interval: 800
        repeat: false
        onTriggered: {
            posSaveProc.sx = root.cardX
            posSaveProc.sy = root.cardY
            posSaveProc.running = false
            posSaveProc.running = true
        }
    }

    onCardXChanged: posSaveTimer.restart()
    onCardYChanged: posSaveTimer.restart()

    // ── Keyboard shortcuts ────────────────────────────────────────────────────
    property int selectedProcessIndex: -1

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && showing) {
            showing = false
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Tab) {
            root.activeTab = (root.activeTab + 1) % 4
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Slash && root.activeTab === 1) {
            processSearchInput.forceActiveFocus()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_K && root.activeTab === 1 && selectedProcessIndex >= 0) {
            if (selectedProcessIndex < root.filteredProcesses.length)
                root.requestKill(root.filteredProcesses[selectedProcessIndex])
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Up && root.activeTab === 1) {
            selectedProcessIndex = Math.max(0, selectedProcessIndex - 1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down && root.activeTab === 1) {
            selectedProcessIndex = Math.min(root.filteredProcesses.length - 1, selectedProcessIndex + 1)
            event.accepted = true
            return
        }
    }

    // ── Tab state ─────────────────────────────────────────────────────────────
    property int activeTab: 0

    // ── Pause/freeze ──────────────────────────────────────────────────────────
    property bool paused: false

    // ── Stats state ───────────────────────────────────────────────────────────
    property double cpuUsage:  0
    property double memUsage:  0
    property double diskUsage: 0
    property double netUp:     0
    property double netDown:   0
    property string memText:   "— GB"
    property string diskText:  "— GB"
    property string netIf:     ""

    property var cpuHistory:     []
    property var memHistory:     []
    property var diskHistory:    []
    property var netDownHistory: []
    property var netUpHistory:   []

    // Peak tracking
    property double cpuPeak: 0
    property double memPeak: 0

    function applyStatLine(text) {
        const line = (text || "").trim()
        if (!line) return

        if (line.startsWith("CPU ")) {
            const tokens = line.slice(4).trim().split(/\s+/)
            const nums = []
            for (const token of tokens) {
                const n = Number(token)
                if (Number.isFinite(n)) nums.push(n)
            }
            if (nums.length < 4) return
            if (statsProc.lastCpu && statsProc.lastCpu.length >= 4) {
                const idle  = (nums[3] || 0) - (statsProc.lastCpu[3] || 0)
                const total = nums.reduce((a, b) => a + b, 0) - statsProc.lastCpu.reduce((a, b) => a + b, 0)
                if (total > 0) {
                    root.cpuUsage = Math.max(0, Math.min(100, (1 - idle / total) * 100))
                    root.cpuHistory = root.pushHistory(root.cpuHistory, root.cpuUsage)
                    if (root.cpuUsage > root.cpuPeak) root.cpuPeak = root.cpuUsage
                }
            }
            statsProc.lastCpu = nums
            return
        }

        if (line.startsWith("MEM ")) {
            const parts     = line.split(/\s+/)
            const total     = Number(parts[1] || 0)
            const available = Number(parts[2] || 0)
            const used      = Math.max(0, total - available)
            if (total > 0) {
                root.memUsage   = used / total * 100
                root.memHistory = root.pushHistory(root.memHistory, root.memUsage)
                root.memText    = (used / 1048576).toFixed(1) + " / " + (total / 1048576).toFixed(1) + " GB"
                if (root.memUsage > root.memPeak) root.memPeak = root.memUsage
            }
            return
        }

        if (line.startsWith("DISK ")) {
            const parts = line.split(/\s+/)
            const total = Number(parts[1] || 0)
            const used  = Number(parts[2] || 0)
            if (total > 0) {
                root.diskUsage   = used / total * 100
                root.diskHistory = root.pushHistory(root.diskHistory, root.diskUsage)
                root.diskText    = (used / 1048576).toFixed(0) + " / " + (total / 1048576).toFixed(0) + " GB"
            }
            return
        }

        if (line.startsWith("NET ")) {
            const parts = line.split(/\s+/)
            const iface = parts[1] || ""
            const rx    = Number(parts[2] || 0)
            const tx    = Number(parts[3] || 0)
            root.netIf  = iface
            if (root._netPrevTs > 0) {
                const nowTs = Date.now() / 1000
                const dt    = Math.max(0.5, nowTs - root._netPrevTs)
                root.netDown        = Math.max(0, (rx - root._netPrevRx) / dt / 1024)
                root.netUp          = Math.max(0, (tx - root._netPrevTx) / dt / 1024)
                root.netDownHistory = root.pushHistory(root.netDownHistory, Math.min(100, root.netDown / 10))
                root.netUpHistory   = root.pushHistory(root.netUpHistory,   Math.min(100, root.netUp   / 10))
            }
            root._netPrevRx = rx
            root._netPrevTx = tx
            root._netPrevTs = Date.now() / 1000
        }
    }

    function pushHistory(arr, val) {
        const copy = arr.slice()
        copy.push(Math.max(0, Math.min(100, val)))
        if (copy.length > maxHistoryPoints) copy.shift()
        return copy
    }

    readonly property int pollIntervalMs:   1500
    readonly property int maxHistoryPoints: 240
    property string graphWindow: "1m"

    function graphWindowPoints() {
        const seconds = graphWindow === "30s" ? 30 : graphWindow === "5m" ? 300 : 60
        return Math.max(8, Math.round(seconds * 1000 / pollIntervalMs))
    }

    function windowedHistory(arr) {
        const points = graphWindowPoints()
        return arr.length > points ? arr.slice(arr.length - points) : arr
    }

    property double _cpuPrevTotal: 0
    property double _cpuPrevIdle:  0
    property double _netPrevRx:    0
    property double _netPrevTx:    0
    property double _netPrevTs:    0

    // ── Process state ─────────────────────────────────────────────────────────
    property var    processes:             []
    property var    filteredProcesses:     []
    property string processSearch:         ""
    property string processNotice:         ""
    property bool   processAdvanced:       false
    property string processSortKey:        "cpu"
    property bool   processSortDescending: true

    property var selectedPids: ({})

    readonly property int psRowInset: 6
    readonly property int psPidW:     64
    readonly property int psCpuW:     72
    readonly property int psMemPctW:  60
    readonly property int psMemAbsW:  84
    readonly property int psBarW:     96
    readonly property int psActionW:  24
    readonly property int psScrollW:  8

    readonly property int safeProcessCap: 192
    readonly property var protectedProcessNames: [
        "quickshell", "hyprland", "systemd", "init", "dbus-daemon", "dbus-broker",
        "xwayland", "sddm", "greetd", "pipewire", "wireplumber", "networkmanager",
        "xdg-desktop-portal", "xdg-desktop-portal-hyprland"
    ]

    property double _memTotalKb: 0

    function rebuildFilteredProcesses() {
        const query = (processSearch || "").trim().toLowerCase()
        const next  = []
        for (const proc of processes) {
            const pid  = String(proc.pid  || "")
            const name = String(proc.name || "").toLowerCase()
            if (!processAdvanced && isProtectedProcess(proc)) continue
            if (!query || pid.includes(query) || name.includes(query)) next.push(proc)
        }
        next.sort((a, b) => {
            let cmp = 0
            if      (processSortKey === "name") cmp = String(a.name || "").localeCompare(String(b.name || ""))
            else if (processSortKey === "pid")  cmp = (Number(a.pid) || 0) - (Number(b.pid) || 0)
            else if (processSortKey === "mem")  cmp = (Number(a.mem) || 0) - (Number(b.mem) || 0)
            else                                cmp = (Number(a.cpu) || 0) - (Number(b.cpu) || 0)
            if (cmp === 0) cmp = (Number(a.pid) || 0) - (Number(b.pid) || 0)
            return processSortDescending ? -cmp : cmp
        })
        filteredProcesses = next
    }

    function setProcessSort(key) {
        if (!key) return
        if (processSortKey === key) processSortDescending = !processSortDescending
        else { processSortKey = key; processSortDescending = key !== "name" }
        rebuildFilteredProcesses()
    }

    function isProtectedProcess(proc) {
        if (!proc) return true
        const pid  = Number(proc.pid || 0)
        const name = String(proc.name || "").toLowerCase()
        if (!Number.isFinite(pid) || pid <= 2) return true
        for (const p of protectedProcessNames) {
            if (name === p || name.startsWith(p)) return true
        }
        return false
    }

    function requestKill(proc) {
        if (!proc) return
        if (isProtectedProcess(proc)) {
            processNotice = "Blocked: protected process (" + (proc.name || proc.pid) + ")"
            noticeTimer.restart()
            return
        }
        killProc.kill(proc.pid)
        processNotice = "Sent SIGTERM to " + (proc.name || proc.pid)
        noticeTimer.restart()
        refreshAfterKill.restart()
    }

    function killSelected() {
        const pids = Object.keys(selectedPids)
        let killed = 0
        for (const pid of pids) {
            const proc = processes.find(p => String(p.pid) === pid)
            if (proc && !isProtectedProcess(proc)) { killProc.kill(proc.pid); killed++ }
        }
        selectedPids = ({})
        processNotice = killed > 0 ? "Sent SIGTERM to " + killed + " process(es)" : "No eligible processes selected"
        noticeTimer.restart()
        refreshAfterKill.restart()
    }

    function memAbsText(memPct) {
        if (!_memTotalKb || !memPct) return "—"
        const kb = (_memTotalKb * Number(memPct)) / 100
        if (kb >= 1048576) return (kb / 1048576).toFixed(1) + "G"
        if (kb >= 1024)    return (kb / 1024).toFixed(0) + "M"
        return kb.toFixed(0) + "K"
    }

    function restartProc(proc) { proc.running = false; proc.running = true }

    onProcessesChanged:             rebuildFilteredProcesses()
    onProcessSearchChanged:         rebuildFilteredProcesses()
    onProcessAdvancedChanged:       { rebuildFilteredProcesses(); if (showing) root.restartProc(psProc) }
    onProcessSortKeyChanged:        rebuildFilteredProcesses()
    onProcessSortDescendingChanged: rebuildFilteredProcesses()

    Timer { id: noticeTimer;      interval: 2200; repeat: false; onTriggered: root.processNotice = "" }
    Timer { id: refreshAfterKill; interval: 260;  repeat: false; onTriggered: root.restartProc(psProc) }

    Timer {
        interval: root.pollIntervalMs
        repeat:   true
        running:  showing && !root.paused
        onTriggered: { root.restartProc(statsProc); root.restartProc(psProc) }
    }

    Process {
        id: statsProc
        command: ["bash", "-lc",
            "printf 'CPU %s\\n' \"$(head -n1 /proc/stat)\"; " +
            "free | awk '/^Mem:/ {printf \"MEM %d %d\\n\", $2, $7}'; " +
            "awk '/MemTotal/{printf \"MEMTOTAL %d\\n\", $2}' /proc/meminfo; " +
            "df -P / | awk 'END {gsub(/%/, \"\", $5); printf \"DISK %s %s\\n\", $2, $3}'; " +
            "awk 'BEGIN{found=0} NR>2 {gsub(\":\", \"\", $1); if ($1 != \"lo\") {print \"NET\", $1, $2, $10; found=1; exit}} END{if(!found) print \"NET -- 0 0\"}' /proc/net/dev"
        ]
        property var lastCpu: null
        stdout: SplitParser {
            onRead: data => {
                const lines = String(data).split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (line.startsWith("MEMTOTAL ")) {
                        root._memTotalKb = Number(line.split(/\s+/)[1] || 0)
                    } else {
                        root.applyStatLine(line)
                    }
                }
            }
        }
    }

    Process {
        id: psProc
        command: ["bash", "-lc", root.processAdvanced
            ? "ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu"
            : ("ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu | head -n " + String(root.safeProcessCap))]
        stdout: SplitParser {
            property string buf: ""
            onRead: data => {
                const chunk = String(data)
                buf += (chunk.indexOf("\n") >= 0) ? chunk : chunk + "\n"
            }
        }
        onExited: {
            const lines = (stdout.buf || "").split(/\r?\n/)
            stdout.buf  = ""
            const list  = []
            for (let i = 0; i < lines.length; i++) {
                const line  = lines[i].trim()
                if (!line) continue
                const parts = line.split(/\s+/)
                if (parts.length < 4) continue
                list.push({ pid: parts[0], name: parts[1], cpu: parts[2], mem: parts[3] })
            }
            root.processes = list
        }
        onRunningChanged: if (running) stdout.buf = ""
    }

    Process {
        id: killProc
        property string targetPid: ""
        command: ["kill", "-TERM", targetPid]
        function kill(pid) {
            targetPid = String(pid || "").trim()
            if (!/^\d+$/.test(targetPid)) return
            running = false; running = true
        }
    }

    // ── System info ───────────────────────────────────────────────────────────
    property string sysKernel:         ""
    property string sysOsName:         "Omarchy"
    property string sysOmarchyVersion: ""
    property string sysCpu:            ""
    property string sysCores:          ""
    property string sysArch:           ""
    property string sysHostname:       ""
    property string sysUptime:         ""
    property string sysMemTotal:       ""
    property string sysDiskDev:        ""
    property string sysCpuTemp:        ""
    property string sysGpuUsage:       ""

    Process {
        id: sysProc
        command: ["bash", "-lc",
            "kernel=$(uname -r 2>/dev/null); " +
            "osname='Omarchy'; " +
            "oversion=$(omarchy-version 2>/dev/null || true); " +
            "cpu=$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null | xargs); " +
            "cores=$(nproc --all 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null); " +
            "arch=$(uname -m 2>/dev/null); " +
            "host=$(hostname 2>/dev/null); " +
            "uptime=$(awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60); printf \"%dd %dh %dm\",d,h,m}' /proc/uptime 2>/dev/null); " +
            "memtot=$(awk '/MemTotal/{printf \"%.1f GB\", $2/1048576}' /proc/meminfo 2>/dev/null); " +
            "diskdev=$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2==\"disk\"{print $1; exit}'); " +
            "cputemp=$(sensors 2>/dev/null | awk '/^(Package id 0|Tdie|CPU Temperature|Core 0)/{gsub(/[^0-9.]/,\" \",$2); print $2\"+°C\"; exit}' || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf \"%.0f°C\", $1/1000}' || echo '—'); " +
            "gpuusage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | awk '{print $1\"%\"}' || radeontop -d - -l 1 2>/dev/null | awk '/gpu/{match($0,/gpu ([0-9.]+)%/,a); if(a[1]) print a[1]\"%\"}' || echo '—'); " +
            "printf 'KERNEL\\x1f%s\\x1eOS\\x1f%s\\x1eOVERSION\\x1f%s\\x1eCPU\\x1f%s\\x1eCORES\\x1f%s\\x1eARCH\\x1f%s\\x1eHOST\\x1f%s\\x1eUPTIME\\x1f%s\\x1eMEMTOTAL\\x1f%s\\x1eDISKDEV\\x1f%s\\x1eCPUTEMP\\x1f%s\\x1eGPUUSAGE\\x1f%s\\x1e' " +
            "\"$kernel\" \"$osname\" \"$oversion\" \"$cpu\" \"$cores\" \"$arch\" \"$host\" \"$uptime\" \"$memtot\" \"$diskdev\" \"$cputemp\" \"$gpuusage\""]
        stdout: SplitParser { property string buf: ""; onRead: data => buf += data }
        running: false
        onExited: {
            const raw     = stdout.buf || ""
            stdout.buf    = ""
            const records = raw.split("\u001e")
            const values  = ({})
            for (let i = 0; i < records.length; i++) {
                const rec = records[i]
                if (!rec) continue
                const sep = rec.indexOf("\u001f")
                if (sep < 0) continue
                values[rec.slice(0, sep)] = rec.slice(sep + 1).trim()
            }
            root.sysKernel         = values.KERNEL   || ""
            root.sysOsName         = values.OS       || "Omarchy"
            root.sysOmarchyVersion = values.OVERSION || ""
            root.sysCpu            = values.CPU      || ""
            root.sysHostname       = values.HOST     || ""
            root.sysUptime         = values.UPTIME   || ""
            root.sysMemTotal       = values.MEMTOTAL || ""
            root.sysDiskDev        = values.DISKDEV  || ""
            root.sysCores          = values.CORES    || ""
            root.sysArch           = values.ARCH     || ""
            root.sysCpuTemp        = values.CPUTEMP  || "—"
            root.sysGpuUsage       = values.GPUUSAGE || "—"
        }
    }

    onShowingChanged: {
        if (showing) {
            root.restartProc(statsProc)
            root.restartProc(psProc)
            if (sysKernel === "") sysProc.running = true
            clampCard()
            posLoadProc.running = false
            posLoadProc.running = true
        }
    }

    onActiveTabChanged: {
        if (showing && activeTab === 1) root.restartProc(psProc)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        x: root.cardX; y: root.cardY
        width: root.implicitWidth; height: root.implicitHeight
        radius: 14; color: root.cBg
        border.color: Qt.alpha(root.cAccent, 0.20); border.width: 1
        clip: true
        opacity: root.showing ? 1 : 0
        scale:   root.showing ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent; spacing: 0

            // ── Title bar ─────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 46
                color: root.cSurface; radius: 14

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: parent.color }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                    property real ox: 0; property real oy: 0
                    onPressed:         mouse => { ox = mouse.x; oy = mouse.y }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        root.cardX += mouse.x - ox; root.cardY += mouse.y - oy; root.clampCard()
                    }
                }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 8
                    Text { text: "Task Manager"; color: root.cFg; font.pixelSize: 13; font.weight: Font.DemiBold; font.family: "JetBrains Mono" }
                    Text { text: "·  system monitor"; color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono" }
                    Item { Layout.fillWidth: true }

                    // Pause button
                    Rectangle {
                        width: 22; height: 22; radius: 6
                        color: root.paused ? Qt.alpha(root.cYellow, 0.20) : Qt.alpha(root.cMuted, 0.22)
                        border.color: root.paused ? Qt.alpha(root.cYellow, 0.55) : Qt.alpha(root.cBorder, 0.4)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.paused ? "" : ""
                            color: root.paused ? root.cYellow : root.cFg
                            font.pixelSize: 8; font.family: "JetBrains Mono"
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.paused = !root.paused }
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 6
                        color: Qt.alpha(root.cMuted, 0.22)
                        border.color: Qt.alpha(root.cBorder, 0.4); border.width: 1
                        Text { anchors.centerIn: parent; text: "✕"; color: root.cFg; font.pixelSize: 9; font.family: "JetBrains Mono" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showing = false }
                    }
                }
            }

            // ── Tab bar ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 36; color: root.cSurface

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 2

                    Repeater {
                        model: ["Stats", "Processes", "Graphs", "System info"]
                        delegate: Rectangle {
                            required property string modelData
                            required property int    index
                            property bool active: root.activeTab === index
                            height: 28; width: tabLabel.implicitWidth + 22; radius: 7
                            color:        active ? Qt.alpha(root.cAccent, 0.14) : "transparent"
                            border.color: active ? Qt.alpha(root.cAccent, 0.35) : "transparent"
                            border.width: 1
                            Text {
                                id: tabLabel; anchors.centerIn: parent; text: modelData
                                color: active ? root.cAccent : root.cDim
                                font.pixelSize: 11; font.family: "JetBrains Mono"
                                font.weight: active ? Font.DemiBold : Font.Normal
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = index }
                        }
                    }

                    Item { Layout.fillWidth: true }
                    Text { text: "Tab · / · ↑↓ · k"; color: Qt.alpha(root.cDim, 0.5); font.pixelSize: 9; font.family: "JetBrains Mono" }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.cBorder, 0.5) }

            // ── Pane area ─────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true

                // ── Pane 0 : Stats ────────────────────────────────────────────
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 12
                    visible: root.activeTab === 0

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        StatCard { label: "CPU";    value: root.cpuUsage;  detail: Math.round(root.cpuUsage) + "%  peak " + Math.round(root.cpuPeak) + "%"; accent: root.cAccent; peakValue: root.cpuPeak }
                        StatCard { label: "Memory"; value: root.memUsage;  detail: root.memText + "  peak " + Math.round(root.memPeak) + "%"; accent: root.cGreen; peakValue: root.memPeak }
                        StatCard { label: "Disk";   value: root.diskUsage; detail: root.diskText; accent: root.cYellow; peakValue: -1 }
                        StatCard {
                            label: "Network · " + (root.netIf || "—")
                            value: Math.min(100, (root.netDown + root.netUp) / 10)
                            detail: "↓ " + root.netDown.toFixed(0) + "  ↑ " + root.netUp.toFixed(0) + " KB/s"
                            accent: "#cba6f7"; peakValue: -1
                        }
                    }

                    // CPU sparkline
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: root.cSurface; radius: 10
                        border.color: Qt.alpha(root.cBorder, 0.4); border.width: 1

                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 6

                            Text { text: "CPU  —  last " + root.graphWindow; color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono" }

                            Item {
                                width: parent.width; height: parent.height - 22

                                // Y-axis labels
                                Column {
                                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: 30; spacing: 0
                                    Repeater {
                                        model: ["100%", "75%", "50%", "25%"]
                                        delegate: Item {
                                            width: 30; height: parent.parent.height / 4
                                            Text {
                                                anchors.right: parent.right; anchors.rightMargin: 4
                                                anchors.top: parent.top; anchors.topMargin: -6
                                                text: modelData; color: Qt.alpha(root.cDim, 0.5)
                                                font.pixelSize: 8; font.family: "JetBrains Mono"
                                            }
                                        }
                                    }
                                    Item {
                                        width: 30; height: 1
                                        Text {
                                            anchors.right: parent.right; anchors.rightMargin: 4
                                            anchors.top: parent.top; anchors.topMargin: -6
                                            text: "0%"; color: Qt.alpha(root.cDim, 0.5)
                                            font.pixelSize: 8; font.family: "JetBrains Mono"
                                        }
                                    }
                                }

                                Canvas {
                                    anchors.left: parent.left; anchors.leftMargin: 32
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                    property var    pts:     root.windowedHistory(root.cpuHistory)
                                    property double peakVal: root.cpuPeak

                                    onPtsChanged:    requestPaint()
                                    onPeakValChanged: requestPaint()
                                    onWidthChanged:  requestPaint()
                                    onHeightChanged: requestPaint()

                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)

                                        for (let g = 0; g <= 4; g++) {
                                            const gy = Math.round(height * g / 4) + 0.5
                                            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy)
                                            ctx.strokeStyle = Qt.alpha(root.cBorder, g === 4 ? 0.35 : 0.18)
                                            ctx.lineWidth = 1; ctx.stroke()
                                        }
                                        for (let v = 1; v < 6; v++) {
                                            const gx = Math.round(width * v / 6) + 0.5
                                            ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height)
                                            ctx.strokeStyle = Qt.alpha(root.cBorder, 0.12)
                                            ctx.lineWidth = 1; ctx.stroke()
                                        }

                                        if (pts.length < 2) return

                                        function drawCurvePath() {
                                            const step = width / Math.max(1, pts.length - 1)
                                            ctx.moveTo(0, height - (pts[0] / 100 * height))
                                            if (pts.length === 2) { ctx.lineTo(step, height - (pts[1] / 100 * height)); return }
                                            for (let i = 1; i < pts.length - 1; i++) {
                                                const x = i*step, y = height-(pts[i]/100*height)
                                                const nx = (i+1)*step, ny = height-(pts[i+1]/100*height)
                                                ctx.quadraticCurveTo(x, y, (x+nx)/2, (y+ny)/2)
                                            }
                                            ctx.lineTo((pts.length-1)*step, height-(pts[pts.length-1]/100*height))
                                        }

                                        ctx.beginPath(); drawCurvePath()
                                        ctx.strokeStyle = root.cAccent; ctx.lineWidth = 1.5; ctx.lineJoin = "round"; ctx.stroke()
                                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                                        ctx.fillStyle = Qt.alpha(root.cAccent, 0.10); ctx.fill()

                                        // Current value label
                                        if (pts.length > 0) {
                                            const lastY = height - (pts[pts.length-1] / 100 * height)
                                            ctx.fillStyle = root.cAccent; ctx.font = "bold 9px monospace"
                                            ctx.textAlign = "right"
                                            ctx.fillText(Math.round(pts[pts.length-1]) + "%", width - 2, lastY - 4)
                                        }

                                        // Peak dot
                                        if (peakVal > 0) {
                                            const peakY = height - (peakVal / 100 * height)
                                            ctx.beginPath(); ctx.arc(width - 8, peakY, 3, 0, Math.PI * 2)
                                            ctx.fillStyle = root.cRed; ctx.fill()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Pane 1 : Processes ────────────────────────────────────────
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 8
                    visible: root.activeTab === 1

                    // Search + controls
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6

                        Rectangle {
                            Layout.fillWidth: true; height: 32; radius: 8
                            color: root.cSurface
                            border.color: Qt.alpha(root.cBorder, 0.5); border.width: 1

                            TextInput {
                                id: processSearchInput
                                anchors.left: parent.left; anchors.right: clearSearch.visible ? clearSearch.left : parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10; anchors.rightMargin: 8
                                color: root.cFg; text: root.processSearch
                                font.pixelSize: 11; font.family: "JetBrains Mono"
                                selectionColor: Qt.alpha(root.cAccent, 0.35); selectedTextColor: root.cFg
                                onTextChanged: root.processSearch = text
                            }
                            Text {
                                anchors.left: processSearchInput.left; anchors.verticalCenter: parent.verticalCenter
                                text: "search by process or PID...  ( / to focus )"
                                color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono"
                                visible: processSearchInput.text.length === 0
                            }
                            Rectangle {
                                id: clearSearch
                                width: 20; height: 20; radius: 6
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                color: Qt.alpha(root.cMuted, 0.18)
                                border.color: Qt.alpha(root.cBorder, 0.5); border.width: 1
                                visible: processSearchInput.text.length > 0
                                Text { anchors.centerIn: parent; text: "×"; color: root.cFg; font.pixelSize: 11; font.family: "JetBrains Mono" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: processSearchInput.text = "" }
                            }
                        }

                        // Kill selected
                        Rectangle {
                            width: 90; height: 32; radius: 8
                            color: Object.keys(root.selectedPids).length > 0 ? Qt.alpha(root.cRed, 0.18) : Qt.alpha(root.cMuted, 0.14)
                            border.color: Object.keys(root.selectedPids).length > 0 ? Qt.alpha(root.cRed, 0.45) : Qt.alpha(root.cBorder, 0.4)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "Kill (" + Object.keys(root.selectedPids).length + ")"
                                color: Object.keys(root.selectedPids).length > 0 ? root.cRed : root.cDim
                                font.pixelSize: 10; font.family: "JetBrains Mono"; font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: Object.keys(root.selectedPids).length > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.killSelected()
                            }
                        }

                        // Safe/Advanced
                        Rectangle {
                            width: 80; height: 32; radius: 8
                            color: root.processAdvanced ? Qt.alpha(root.cAccent, 0.20) : Qt.alpha(root.cMuted, 0.16)
                            border.color: root.processAdvanced ? Qt.alpha(root.cAccent, 0.50) : Qt.alpha(root.cBorder, 0.5)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: root.processAdvanced ? "Advanced" : "Safe"
                                color: root.processAdvanced ? root.cAccent : root.cDim
                                font.pixelSize: 10; font.family: "JetBrains Mono"; font.weight: Font.DemiBold
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.processAdvanced = !root.processAdvanced }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.processNotice !== ""
                            ? root.processNotice
                            : ((root.processAdvanced ? "Advanced mode" : "Safe mode") + " · Showing " + root.filteredProcesses.length + " process(es)" + (root.paused ? "  ·   paused" : ""))
                        color: root.processNotice !== "" ? root.cAccent : root.cDim
                        font.pixelSize: 10; font.family: "JetBrains Mono"; elide: Text.ElideRight
                    }

                    // Header
                    Item {
                        Layout.fillWidth: true; height: 24
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin:  root.psRowInset + 34
                            anchors.rightMargin: root.psRowInset + root.psScrollW + root.psActionW
                            spacing: 0
                            PsHeaderCell { text: "PID";     cellWidth: root.psPidW;    sortKey: "pid" }
                            PsHeaderCell { text: "Name";    cellWidth: -1; fill: true; sortKey: "name" }
                            PsHeaderCell { text: "CPU %";   cellWidth: root.psCpuW;    rightAlign: true; sortKey: "cpu" }
                            PsHeaderCell { text: "MEM %";   cellWidth: root.psMemPctW; rightAlign: true; sortKey: "mem" }
                            PsHeaderCell { text: "MEM";     cellWidth: root.psMemAbsW; rightAlign: true }
                            PsHeaderCell { text: "CPU bar"; cellWidth: root.psBarW }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.cBorder, 0.5) }

                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                        Flickable {
                            id: psFlick
                            anchors.fill: parent; anchors.rightMargin: root.psScrollW + 2
                            clip: true; contentWidth: width; contentHeight: psColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds; flickableDirection: Flickable.VerticalFlick
                            interactive: contentHeight > height

                            Column {
                                id: psColumn; width: psFlick.width; spacing: 1

                                Repeater {
                                    model: root.filteredProcesses.length
                                    delegate: Rectangle {
                                        required property int index
                                        property var  row:           root.filteredProcesses[index]
                                        property bool protectedProc: root.isProtectedProcess(row)
                                        property bool hovered:       false
                                        property bool isSelected:    !!root.selectedPids[row.pid]
                                        property bool isKeySelected: root.selectedProcessIndex === index
                                        width: psColumn.width; height: 30; radius: 6
                                        color: isSelected      ? Qt.alpha(root.cAccent, 0.12)
                                             : isKeySelected   ? Qt.alpha(root.cFg, 0.08)
                                             : hovered         ? Qt.alpha(root.cFg, 0.05)
                                             : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: root.psRowInset; anchors.rightMargin: root.psRowInset
                                            spacing: 0

                                            // Checkbox
                                            Rectangle {
                                                width: 16; height: 16; radius: 4
                                                color: isSelected ? Qt.alpha(root.cAccent, 0.30) : Qt.alpha(root.cMuted, 0.12)
                                                border.color: isSelected ? Qt.alpha(root.cAccent, 0.7) : Qt.alpha(root.cBorder, 0.4)
                                                border.width: 1
                                                visible: !protectedProc
                                                Text { anchors.centerIn: parent; text: "✓"; color: root.cAccent; font.pixelSize: 9; visible: isSelected }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const copy = Object.assign({}, root.selectedPids)
                                                        if (copy[row.pid]) delete copy[row.pid]
                                                        else copy[row.pid] = true
                                                        root.selectedPids = copy
                                                    }
                                                }
                                            }
                                            Item { width: protectedProc ? 16 : 0; height: 1 }
                                            Item { width: 8; height: 1 }

                                            PsCell { text: row.pid;  cellWidth: root.psPidW; dim: true }
                                            PsCell { text: row.name; cellWidth: -1; fill: true }

                                            // Colored CPU %
                                            Item {
                                                width: root.psCpuW; height: parent.height
                                                Text {
                                                    anchors.right: parent.right; anchors.rightMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: row.cpu; color: root.cpuColor(row.cpu)
                                                    font.pixelSize: 11; font.family: "JetBrains Mono"
                                                    font.weight: Number(row.cpu) >= 10 ? Font.DemiBold : Font.Normal
                                                }
                                            }

                                            PsCell { text: row.mem;                  cellWidth: root.psMemPctW; rightAlign: true; dim: true }
                                            PsCell { text: root.memAbsText(row.mem); cellWidth: root.psMemAbsW; rightAlign: true; dim: true }

                                            // Animated bar
                                            Item {
                                                width: root.psBarW; height: parent.height
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.right: parent.right
                                                    anchors.leftMargin: 4; anchors.rightMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 3; radius: 2; color: Qt.alpha(root.cBorder, 0.5)
                                                    Rectangle {
                                                        height: parent.height; radius: 2
                                                        color: root.cpuColor(row.cpu)
                                                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                                        width: Math.max(2, parent.width * Math.min(1, (Number(row.cpu) || 0) / 30))
                                                    }
                                                }
                                            }

                                            // Kill button
                                            Rectangle {
                                                width: root.psActionW; height: root.psActionW; radius: 6
                                                color:        protectedProc ? Qt.alpha(root.cMuted, 0.10) : Qt.alpha(root.cMuted, 0.20)
                                                border.color: Qt.alpha(root.cBorder, protectedProc ? 0.25 : 0.4); border.width: 1
                                                opacity: hovered ? 1 : 0
                                                Text { anchors.centerIn: parent; text: "×"; color: protectedProc ? root.cDim : root.cRed; font.pixelSize: 12; font.family: "JetBrains Mono" }
                                                MouseArea {
                                                    anchors.fill: parent; enabled: hovered
                                                    cursorShape: protectedProc ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                                    onClicked: root.requestKill(row)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                            onEntered: { hovered = true; root.selectedProcessIndex = index }
                                            onExited:  hovered = false
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: psFlick.top; anchors.bottom: psFlick.bottom; anchors.right: parent.right
                            width: root.psScrollW - 2; radius: 1; color: Qt.alpha(root.cBorder, 0.35)
                            visible: psFlick.contentHeight > (psFlick.height + 1)
                            Rectangle {
                                width: parent.width; radius: 1; color: Qt.alpha(root.cAccent, 0.75)
                                height: Math.max(18, parent.height * (psFlick.height / Math.max(psFlick.contentHeight, 1)))
                                y: (Math.max(psFlick.contentY, 0) / Math.max(1, psFlick.contentHeight - psFlick.height)) * (parent.height - height)
                            }
                        }
                    }
                }

                // ── Pane 2 : Graphs ───────────────────────────────────────────
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14; spacing: 8
                    visible: root.activeTab === 2

                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Text { text: "Window"; color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono" }
                        Repeater {
                            model: ["30s", "1m", "5m"]
                            delegate: Rectangle {
                                required property string modelData
                                property bool active: root.graphWindow === modelData
                                width: 36; height: 22; radius: 6
                                color:        active ? Qt.alpha(root.cAccent, 0.16) : root.cSurface
                                border.color: active ? Qt.alpha(root.cAccent, 0.50) : Qt.alpha(root.cBorder, 0.45)
                                border.width: 1
                                Text { anchors.centerIn: parent; text: modelData; color: active ? root.cAccent : root.cDim; font.pixelSize: 9; font.family: "JetBrains Mono"; font.weight: active ? Font.DemiBold : Font.Normal }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.graphWindow = modelData }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: root.paused ? " paused" : ""; color: root.cYellow; font.pixelSize: 10; font.family: "JetBrains Mono" }
                    }

                    GridLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        columns: 2; rowSpacing: 10; columnSpacing: 10

                        GraphCard { label: "CPU";              history: root.windowedHistory(root.cpuHistory);     lineColor: root.cAccent; peakValue: root.cpuPeak }
                        GraphCard { label: "Memory";           history: root.windowedHistory(root.memHistory);     lineColor: root.cGreen;  peakValue: root.memPeak }
                        GraphCard { label: "Network download"; history: root.windowedHistory(root.netDownHistory); lineColor: "#cba6f7";    peakValue: -1 }
                        GraphCard { label: "Network upload";   history: root.windowedHistory(root.netUpHistory);   lineColor: "#89dceb";    peakValue: -1 }
                    }
                }

                // ── Pane 3 : System info ──────────────────────────────────────
                GridLayout {
                    anchors.fill: parent; anchors.margins: 14
                    columns: 2; rowSpacing: 10; columnSpacing: 10
                    visible: root.activeTab === 3

                    SysInfoBlock {
                        label: "CPU"
                        rows: [
                            { k: "Model",       v: root.sysCpu     || "—" },
                            { k: "Cores",       v: root.sysCores   || "—" },
                            { k: "Arch",        v: root.sysArch    || "—" },
                            { k: "Temperature", v: root.sysCpuTemp || "—" },
                        ]
                    }
                    SysInfoBlock {
                        label: "Memory"
                        rows: [
                            { k: "Total", v: root.sysMemTotal || "—" },
                            { k: "Used",  v: root.memText     || "—" },
                            { k: "Usage", v: Math.round(root.memUsage) + "%" },
                        ]
                    }
                    SysInfoBlock {
                        label: "Operating System"
                        rows: [
                            { k: "OS",       v: root.sysOsName         || "Omarchy" },
                            { k: "Version",  v: root.sysOmarchyVersion || "—" },
                            { k: "Kernel",   v: root.sysKernel         || "—" },
                            { k: "Hostname", v: root.sysHostname       || "—" },
                            { k: "Uptime",   v: root.sysUptime         || "—" },
                        ]
                    }
                    SysInfoBlock {
                        label: "Disk & GPU"
                        rows: [
                            { k: "Device",    v: root.sysDiskDev            || "—" },
                            { k: "Disk used", v: root.diskText              || "—" },
                            { k: "Disk %",    v: Math.round(root.diskUsage) + "%" },
                            { k: "GPU usage", v: root.sysGpuUsage           || "—" },
                        ]
                    }
                }
            }
        }
    }

    // ── Inline components ─────────────────────────────────────────────────────

    component StatCard: Rectangle {
        property string label:     ""
        property double value:     0
        property string detail:    ""
        property color  accent:    root.cAccent
        property double peakValue: -1
        Layout.fillWidth: true; height: 92; radius: 10
        color: root.cSurface; border.color: Qt.alpha(root.cBorder, 0.5); border.width: 1

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 5
            Text { text: label; color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono"; font.letterSpacing: 0.6 }
            Text { text: Math.round(value) + "%"; color: root.cFg; font.pixelSize: 20; font.weight: Font.DemiBold; font.family: "JetBrains Mono" }
            Item {
                width: parent.width; height: 4
                Rectangle {
                    anchors.fill: parent; radius: 2; color: Qt.alpha(root.cBorder, 0.5)
                    Rectangle {
                        height: parent.height; radius: 2; color: accent
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        width: Math.max(4, parent.width * Math.max(0, Math.min(100, value)) / 100)
                    }
                    // Peak marker line
                    Rectangle {
                        visible: peakValue >= 0
                        x: Math.max(0, Math.min(parent.width - 2, parent.width * peakValue / 100)) - 1
                        width: 2; height: parent.height; radius: 1; color: root.cRed; opacity: 0.85
                    }
                }
            }
            Text { text: detail; color: root.cDim; font.pixelSize: 9; font.family: "JetBrains Mono"; elide: Text.ElideRight; width: parent.width }
        }
    }

    component GraphCard: Rectangle {
        property string label:     ""
        property var    history:   []
        property color  lineColor: root.cAccent
        property double peakValue: -1

        // Crosshair state
        property real  hoverX:           -1
        property bool  crosshairVisible: false

        Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
        color: root.cSurface; border.color: Qt.alpha(root.cBorder, 0.4); border.width: 1

        Row {
            anchors.fill: parent; anchors.margins: 12; spacing: 0

            // Y-axis labels
            Column {
                width: 30; height: parent.height; spacing: 0
                Repeater {
                    model: ["100%", "75%", "50%", "25%"]
                    delegate: Item {
                        width: 30; height: (parent.parent.height - 22) / 4
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 2
                            anchors.top: parent.top; anchors.topMargin: -6
                            text: modelData; color: Qt.alpha(root.cDim, 0.5)
                            font.pixelSize: 7; font.family: "JetBrains Mono"
                        }
                    }
                }
                Item {
                    width: 30; height: 1
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 2
                        anchors.top: parent.top; anchors.topMargin: -6
                        text: "0%"; color: Qt.alpha(root.cDim, 0.5)
                        font.pixelSize: 7; font.family: "JetBrains Mono"
                    }
                }
                Item { width: 30; height: 22 }
            }

            Column {
                width: parent.width - 30; height: parent.height; spacing: 6

                Text { text: label; color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono" }

                Item {
                    width: parent.width; height: parent.height - 22

                    Canvas {
                        anchors.fill: parent
                        property var   pts: history
                        property color lc:  lineColor
                        property double pv: peakValue
                        property real   hvX: crosshairVisible ? hoverX : -1

                        onPtsChanged:    requestPaint()
                        onLcChanged:     requestPaint()
                        onPvChanged:     requestPaint()
                        onHvXChanged:    requestPaint()
                        onWidthChanged:  requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            // Horizontal grid
                            for (let g = 0; g <= 4; g++) {
                                const gy = Math.round(height * g / 4) + 0.5
                                ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy)
                                ctx.strokeStyle = Qt.alpha(root.cBorder, g === 4 ? 0.35 : 0.18)
                                ctx.lineWidth = 1; ctx.stroke()
                            }
                            // Vertical grid
                            for (let v = 1; v < 6; v++) {
                                const gx = Math.round(width * v / 6) + 0.5
                                ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height)
                                ctx.strokeStyle = Qt.alpha(root.cBorder, 0.12)
                                ctx.lineWidth = 1; ctx.stroke()
                            }

                            if (pts.length < 2) return

                            function ptY(val) { return height - (val / 100 * (height - 4)) - 2 }

                            function drawCurvePath() {
                                const step = width / Math.max(1, pts.length - 1)
                                ctx.moveTo(0, ptY(pts[0]))
                                if (pts.length === 2) { ctx.lineTo(step, ptY(pts[1])); return }
                                for (let i = 1; i < pts.length - 1; i++) {
                                    const x = i*step, y = ptY(pts[i]), nx = (i+1)*step, ny = ptY(pts[i+1])
                                    ctx.quadraticCurveTo(x, y, (x+nx)/2, (y+ny)/2)
                                }
                                ctx.lineTo((pts.length-1)*step, ptY(pts[pts.length-1]))
                            }

                            ctx.beginPath(); drawCurvePath()
                            ctx.strokeStyle = lc; ctx.lineWidth = 1.5; ctx.lineJoin = "round"; ctx.stroke()
                            ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                            ctx.fillStyle = Qt.alpha(lc, 0.09); ctx.fill()

                            // Current value label
                            if (pts.length > 0) {
                                const lastY = ptY(pts[pts.length-1])
                                ctx.fillStyle = lc; ctx.font = "bold 9px monospace"; ctx.textAlign = "right"
                                ctx.fillText(Math.round(pts[pts.length-1]) + "%", width - 2, lastY - 4)
                            }

                            // Peak dot
                            if (pv > 0) {
                                ctx.beginPath(); ctx.arc(width - 8, ptY(pv), 3, 0, Math.PI * 2)
                                ctx.fillStyle = root.cRed; ctx.fill()
                            }

                            // Crosshair + tooltip
                            if (hvX >= 0 && pts.length > 1) {
                                const step = width / Math.max(1, pts.length - 1)
                                const idx  = Math.max(0, Math.min(pts.length - 1, Math.round(hvX / step)))
                                const cx   = idx * step
                                const cy   = ptY(pts[idx])

                                ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, height)
                                ctx.strokeStyle = Qt.alpha(root.cFg, 0.25); ctx.lineWidth = 1
                                ctx.setLineDash([3, 3]); ctx.stroke(); ctx.setLineDash([])

                                ctx.beginPath(); ctx.arc(cx, cy, 4, 0, Math.PI * 2)
                                ctx.fillStyle = lc; ctx.fill()

                                const val = Math.round(pts[idx]) + "%"
                                ctx.font = "bold 10px monospace"
                                const tw = ctx.measureText(val).width + 10
                                const tx = Math.min(width - tw - 2, Math.max(2, cx - tw / 2))
                                const ty = Math.max(4, cy - 22)
                                ctx.fillStyle = Qt.alpha(root.cBg, 0.88)
                                ctx.beginPath(); ctx.roundRect(tx, ty, tw, 18, 4); ctx.fill()
                                ctx.fillStyle = lc; ctx.textAlign = "left"
                                ctx.fillText(val, tx + 5, ty + 13)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                            onEntered:         crosshairVisible = true
                            onExited:          crosshairVisible = false
                            onPositionChanged: mouse => { hoverX = mouse.x }
                        }
                    }
                }
            }
        }
    }

    component SysInfoBlock: Rectangle {
        property string label: ""
        property var    rows:  []
        Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
        color: root.cSurface; border.color: Qt.alpha(root.cBorder, 0.4); border.width: 1

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 0
            Text { text: label; color: root.cDim; font.pixelSize: 10; font.family: "JetBrains Mono"; font.letterSpacing: 0.6; bottomPadding: 8 }
            Repeater {
                model: rows.length
                delegate: Rectangle {
                    required property int index
                    width: parent.width; height: 26; color: "transparent"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(root.cBorder, 0.35); visible: index < rows.length - 1 }
                    RowLayout {
                        anchors.fill: parent
                        Text { text: rows[index].k; color: root.cDim; font.pixelSize: 11; font.family: "JetBrains Mono" }
                        Item { Layout.fillWidth: true }
                        Text { text: rows[index].v; color: root.cFg; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: "JetBrains Mono"; elide: Text.ElideLeft; Layout.maximumWidth: 220 }
                    }
                }
            }
        }
    }

    component PsHeaderCell: Item {
        property string text:       ""
        property int    cellWidth:  80
        property bool   fill:       false
        property bool   rightAlign: false
        property string sortKey:    ""
        readonly property bool sortable:   sortKey !== ""
        readonly property bool activeSort: sortable && root.processSortKey === sortKey
        Layout.preferredWidth: fill ? -1 : cellWidth; Layout.fillWidth: fill; height: 24

        Text {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
            text: parent.text + (parent.activeSort ? (root.processSortDescending ? " ↓" : " ↑") : "")
            color: parent.activeSort ? root.cAccent : root.cDim
            font.pixelSize: 9; font.family: "JetBrains Mono"; font.letterSpacing: 0.5
            horizontalAlignment: parent.rightAlign ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
        MouseArea {
            anchors.fill: parent; enabled: parent.sortable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.setProcessSort(parent.sortKey)
        }
    }

    component PsCell: Item {
        property string text:       ""
        property int    cellWidth:  80
        property bool   fill:       false
        property bool   rightAlign: false
        property bool   dim:        false
        Layout.preferredWidth: fill ? -1 : cellWidth; Layout.fillWidth: fill; height: 30

        Text {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
            text: parent.text; color: parent.dim ? root.cDim : root.cFg
            font.pixelSize: 11; font.family: "JetBrains Mono"
            horizontalAlignment: parent.rightAlign ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
    }
}