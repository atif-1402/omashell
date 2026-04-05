import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    property var theme: ({})
    property var settings: null
    property real posX: settings ? settings.clockWidgetPosX : 0.8
    property real posY: settings ? settings.clockWidgetPosY : 0.8
    property bool autoPosition: false
    property real dragStartLeft: 0
    property real dragStartTop: 0
    property real pressOffsetX: 0
    property real pressOffsetY: 0
    property bool dragging: false
    property real dragLeft: 0
    property real dragTop: 0
    readonly property bool clockEnabled: settings ? settings.clockWidgetEnabled : true
    readonly property bool use24h: settings ? settings.clockUse24h : true
    property date now: new Date()
    property string lastWallpaper: ""
    readonly property int safeMargin: 24

    // Themed palette
    readonly property color nBg:     Qt.darker(theme.bg || "#1e1e2e", 1.08)
    readonly property color nBorder: Qt.alpha(theme.fg || "#cdd6f4", 0.10)
    readonly property color nWhite:  theme.fg || "#cdd6f4"
    readonly property color nGray:   Qt.alpha(theme.fg || "#cdd6f4", 0.70)
    readonly property color nDim:    Qt.alpha(theme.fg || "#cdd6f4", 0.35)
    readonly property color nMuted:  Qt.alpha(theme.fg || "#cdd6f4", 0.45)
    readonly property color nDotOn:  theme.accent || theme.fg || "#89b4fa"
    readonly property color nDotOff: Qt.alpha(theme.fg || "#cdd6f4", 0.14)
    readonly property color nLine:   Qt.alpha(theme.fg || "#cdd6f4", 0.12)

    implicitWidth: 220
    implicitHeight: 130

    readonly property real posLeft: safeMargin + (screen.width  - width  - safeMargin * 2) * posX
    readonly property real posTop:  safeMargin + (screen.height - height - safeMargin * 2) * posY

    WlrLayershell.anchors { left: true; top: true }
    WlrLayershell.margins { left: dragging ? dragLeft : posLeft; top: dragging ? dragTop : posTop }
    color: "transparent"
    visible: clockEnabled
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    function syncPositionFromSettings() {
        if (!settings) return
        if (typeof settings.clockWidgetPosX === "number")
            posX = settings.clockWidgetPosX
        if (typeof settings.clockWidgetPosY === "number")
            posY = settings.clockWidgetPosY
    }

    function pad(n) { return n < 10 ? "0" + n : String(n) }
    function hour12(h) {
        const v = h % 12
        return v === 0 ? 12 : v
    }

    // How many dots to fill (0–12) based on minute (each dot = 5 min)
    function filledDots() {
        return Math.floor(root.now.getMinutes() / 5)
    }

    function scanWallpaper() {
        if (!autoPosition) return
        wallpaperScan.running = false
        wallpaperScan.running = true
    }

    Connections {
        target: settings
        function onLoadedChanged() {
            if (settings && settings.loaded)
                root.syncPositionFromSettings()
        }
    }

    onPosXChanged: if (!dragging) dragLeft = posLeft
    onPosYChanged: if (!dragging) dragTop = posTop
    Timer {
        id: wallpaperPoll
        interval: 4000
        repeat: true
        running: autoPosition
        onTriggered: {
            wallpaperPathProbe.running = false
            wallpaperPathProbe.running = true
        }
    }

    Process {
        id: wallpaperPathProbe
        command: ["bash", "-lc",
            "BG_LINK=\"$HOME/.config/omarchy/current/background\"; " +
            "if [ -L \"$BG_LINK\" ]; then readlink -f \"$BG_LINK\"; else echo \"$BG_LINK\"; fi"
        ]
        running: true
        stdout: SplitParser {
            property string buf: ""
            onRead: data => buf += data
        }
        onExited: {
            const p = (wallpaperPathProbe.stdout.buf || "").trim()
            wallpaperPathProbe.stdout.buf = ""
            if (p && p !== root.lastWallpaper) {
                root.lastWallpaper = p
                scanWallpaper()
            }
        }
    }

    Process {
        id: wallpaperScan
        command: ["bash", "-lc",
            "ID=(identify); CV=(convert); " +
            "command -v identify >/dev/null 2>&1 || ID=(magick identify); " +
            "command -v convert  >/dev/null 2>&1 || CV=(magick); " +
            "command -v ${ID[0]} >/dev/null 2>&1 || exit 0; " +
            "command -v ${CV[0]} >/dev/null 2>&1 || exit 0; " +
            "BG_LINK=\"$HOME/.config/omarchy/current/background\"; " +
            "if [ -L \"$BG_LINK\" ]; then IMG=$(readlink -f \"$BG_LINK\"); else IMG=\"$BG_LINK\"; fi; " +
            "[ -f \"$IMG\" ] || exit 0; " +
            "read W H < <(\"${ID[@]}\" -format '%w %h' \"$IMG\" 2>/dev/null); " +
            "[ -z \"$W\" ] && exit 0; " +
            "GRID=5; CW=$((W/GRID)); CH=$((H/GRID)); " +
            "best=1; bestx=0; besty=0; " +
            "for iy in $(seq 0 $((GRID-1))); do " +
            "  for ix in $(seq 0 $((GRID-1))); do " +
            "    x=$((ix*CW)); y=$((iy*CH)); " +
            "    m=$(${CV[@]} \"$IMG\" -crop ${CW}x${CH}+${x}+${y} -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null); " +
            "    [ -z \"$m\" ] && continue; " +
            "    comp=$(awk -v a=\"$m\" -v b=\"$best\" 'BEGIN{print (a<b)?1:0}'); " +
            "    if [ \"$comp\" -eq 1 ]; then best=\"$m\"; bestx=$ix; besty=$iy; fi; " +
            "  done; " +
            "done; " +
            "cx=$(awk -v ix=$bestx -v cw=$CW -v w=$W 'BEGIN{print (ix*cw + cw/2)/w}'); " +
            "cy=$(awk -v iy=$besty -v ch=$CH -v h=$H 'BEGIN{print (iy*ch + ch/2)/h}'); " +
            "echo pos|$cx|$cy"
        ]
        running: true
        stdout: SplitParser {
            property string px: ""
            property string py: ""
            onRead: data => {
                const line = data.trim()
                if (!line) return
                const parts = line.split("|")
                if (parts.length !== 3 || parts[0] !== "pos") return
                px = parts[1]
                py = parts[2]
            }
        }
        onExited: {
            const nx = Number(wallpaperScan.stdout.px)
            const ny = Number(wallpaperScan.stdout.py)
            if (autoPosition && !isNaN(nx) && !isNaN(ny)) {
                posX = Math.max(0, Math.min(1, nx))
                posY = Math.max(0, Math.min(1, ny))
            }
            wallpaperScan.stdout.px = ""
            wallpaperScan.stdout.py = ""
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: mouse => {
            if (mouse.button !== Qt.RightButton) return
            dragging = true
            pressOffsetX = mouse.x
            pressOffsetY = mouse.y
            dragStartLeft = posLeft
            dragStartTop = posTop
            dragLeft = posLeft
            dragTop = posTop
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            const maxLeft = Math.max(0, screen.width  - width  - safeMargin * 2)
            const maxTop  = Math.max(0, screen.height - height - safeMargin * 2)
            dragLeft = Math.max(0, Math.min(maxLeft, dragStartLeft + (mouse.x - pressOffsetX)))
            dragTop = Math.max(0, Math.min(maxTop,  dragStartTop  + (mouse.y - pressOffsetY)))
        }
        onReleased: {
            dragging = false
            const maxLeft = Math.max(0, screen.width  - width  - safeMargin * 2)
            const maxTop  = Math.max(0, screen.height - height - safeMargin * 2)
            posX = maxLeft > 0 ? ((dragLeft - safeMargin) / maxLeft) : 0
            posY = maxTop  > 0 ? ((dragTop - safeMargin) / maxTop)  : 0
            dragLeft = posLeft
            dragTop = posTop
            if (settings) {
                settings.clockWidgetPosX = posX
                settings.clockWidgetPosY = posY
            }
        }
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: nBg
        border.color: nBorder
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // ── Glyph dot row (12 dots = 60 min, each dot = 5 min) ──────────
            Row {
                spacing: 4
                Repeater {
                    model: 12
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: index < filledDots() ? nDotOn : nDotOff

                        Behavior on color {
                            ColorAnimation { duration: 400 }
                        }
                    }
                }
            }

            // ── Time ────────────────────────────────────────────────────────
            Row {
                spacing: 0

                Text {
                    text: pad(root.use24h ? root.now.getHours() : root.hour12(root.now.getHours()))
                    color: nWhite
                    font.pixelSize: 48
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.letterSpacing: -2
                    lineHeight: 1
                }

                Text {
                    text: ":"
                    color: nDim
                    font.pixelSize: 48
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.letterSpacing: -2
                    lineHeight: 1

                    // blink every second
                    property bool visible2: true
                    opacity: visible2 ? 1.0 : 0.0
                    Timer {
                        interval: 1000; repeat: true; running: true
                        onTriggered: parent.visible2 = !parent.visible2
                    }
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }

                Text {
                    text: pad(root.now.getMinutes())
                    color: nGray
                    font.pixelSize: 48
                    font.family: "JetBrains Mono"
                    font.weight: Font.Bold
                    font.letterSpacing: -2
                    lineHeight: 1
                }
            }

            // ── Divider line ─────────────────────────────────────────────────
            Item {
                width: parent.width
                height: 1

                Rectangle {
                    width: parent.width
                    height: 1
                    color: nLine
                }
            }

            // ── Date row ────────────────────────────────────────────────────
            Row {
                width: parent.width

                Text {
                    text: Qt.formatDate(root.now, "ddd").toUpperCase()
                         + " · "
                         + Qt.formatDate(root.now, "dd MMM").toUpperCase()
                    color: nMuted
                    font.pixelSize: 9
                    font.family: "JetBrains Mono"
                    font.letterSpacing: 1.5
                }
            }
        }
    }
}
