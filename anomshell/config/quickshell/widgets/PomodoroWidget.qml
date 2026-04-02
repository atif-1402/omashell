import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var theme: ({})
    property var settings: null
    readonly property bool enabled: settings ? settings.pomodoroWidgetEnabled : false

    property real posX: settings ? settings.pomodoroWidgetPosX : 0.6
    property real posY: settings ? settings.pomodoroWidgetPosY : 0.6
    property real dragStartLeft: 0
    property real dragStartTop: 0
    property real pressOffsetX: 0
    property real pressOffsetY: 0
    property bool dragging: false
    property real dragLeft: 0
    property real dragTop: 0
    readonly property int cardW: 220
    readonly property int cardH: 140
    readonly property int safeMargin: 24

    readonly property int focusSeconds: 25 * 60
    readonly property int breakSeconds: 5 * 60

    property bool running: false
    property string mode: "focus"
    property int remaining: focusSeconds
    property int cycleCount: 0

    readonly property color cBg:     Qt.darker(theme.bg || "#1e1e2e", 1.08)
    readonly property color cBorder: Qt.alpha(theme.fg || "#cdd6f4", 0.12)
    readonly property color cFg:     theme.fg || "#cdd6f4"
    readonly property color cMuted:  Qt.alpha(theme.fg || "#cdd6f4", 0.55)
    readonly property color cDim:    Qt.alpha(theme.fg || "#cdd6f4", 0.25)
    readonly property color cAccent: theme.accent || "#89b4fa"

    implicitWidth: cardW
    implicitHeight: cardH

    readonly property real posLeft: safeMargin + (screen.width  - width  - safeMargin * 2) * posX
    readonly property real posTop:  safeMargin + (screen.height - height - safeMargin * 2) * posY

    // no easing for direct drag

    WlrLayershell.anchors { left: true; top: true }
    WlrLayershell.margins { left: dragging ? dragLeft : posLeft; top: dragging ? dragTop : posTop }
    color: "transparent"
    visible: enabled
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 0) {
                root.remaining -= 1
            } else {
                root.advancePhase()
            }
        }
    }

    function formatTime(sec) {
        const m = Math.floor(sec / 60)
        const s = sec % 60
        const mm = m < 10 ? "0" + m : String(m)
        const ss = s < 10 ? "0" + s : String(s)
        return mm + ":" + ss
    }

    function progress() {
        const total = root.mode === "focus" ? root.focusSeconds : root.breakSeconds
        return total > 0 ? 1 - (root.remaining / total) : 0
    }

    function playBeep() {
        Quickshell.execDetached([
            "bash", "-lc",
            "if command -v pw-play >/dev/null 2>&1; then " +
            "  pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || " +
            "  pw-play /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null; " +
            "elif command -v paplay >/dev/null 2>&1; then " +
            "  paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || " +
            "  paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null; " +
            "fi"
        ])
    }

    function advancePhase() {
        root.playBeep()
        if (root.mode === "focus") {
            root.mode = "break"
            root.remaining = root.breakSeconds
        } else {
            root.mode = "focus"
            root.remaining = root.focusSeconds
            root.cycleCount += 1
        }
    }

    function resetTimer() {
        root.running = false
        root.mode = "focus"
        root.remaining = root.focusSeconds
    }

    function syncPositionFromSettings() {
        if (!settings) return
        if (typeof settings.pomodoroWidgetPosX === "number")
            posX = settings.pomodoroWidgetPosX
        if (typeof settings.pomodoroWidgetPosY === "number")
            posY = settings.pomodoroWidgetPosY
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
            dragTop  = Math.max(0, Math.min(maxTop,  dragStartTop  + (mouse.y - pressOffsetY)))
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
                settings.pomodoroWidgetPosX = posX
                settings.pomodoroWidgetPosY = posY
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: cBg
        border.color: cBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.mode === "focus" ? "FOCUS" : "BREAK"
                    color: root.mode === "focus" ? cAccent : cMuted
                    font.pixelSize: 10
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.cycleCount > 0 ? "x" + root.cycleCount : ""
                    color: cDim
                    font.pixelSize: 9
                    font.family: "JetBrains Mono"
                }
            }

            Text {
                text: root.formatTime(root.remaining)
                color: cFg
                font.pixelSize: 34
                font.family: "JetBrains Mono"
                font.weight: Font.Bold
                font.letterSpacing: -1.5
            }

            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Qt.alpha(cDim, 0.45)

                Rectangle {
                    width: Math.max(6, parent.width * root.progress())
                    height: 4
                    radius: 2
                    color: cAccent
                }

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    y: -1
                    x: Math.max(0, Math.min(parent.width - width, parent.width * root.progress() - width / 2))
                    color: cAccent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 8
                    color: root.running
                        ? Qt.alpha(cAccent, 0.38)
                        : Qt.alpha(cAccent, 0.26)
                    border.color: root.running
                        ? Qt.alpha(cAccent, 0.75)
                        : Qt.alpha(cAccent, 0.55)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.running ? "Pause" : "Start"
                        color: cFg
                        font.pixelSize: 9
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.running = !root.running
                    }
                }

                Rectangle {
                    width: 52
                    height: 26
                    radius: 8
                    color: Qt.alpha(cDim, 0.25)
                    border.color: Qt.alpha(cDim, 0.6)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        color: Qt.alpha(cFg, 0.75)
                        font.pixelSize: 9
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetTimer()
                    }
                }
            }
        }
    }
}
