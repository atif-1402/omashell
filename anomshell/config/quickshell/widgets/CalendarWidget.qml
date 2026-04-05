import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var theme: ({})
    property var settings: null
    readonly property bool enabled: settings ? settings.calendarWidgetEnabled : false

    property real posX: settings ? settings.calendarWidgetPosX : 0.7
    property real posY: settings ? settings.calendarWidgetPosY : 0.7
    property real dragStartLeft: 0
    property real dragStartTop: 0
    property real pressOffsetX: 0
    property real pressOffsetY: 0
    property bool dragging: false
    property real dragLeft: 0
    property real dragTop: 0
    readonly property int cardW: 220
    readonly property int cardH: 220
    readonly property int safeMargin: 24

    property date now: new Date()

    readonly property color cBg:     Qt.darker(theme.bg || "#1e1e2e", 1.08)
    readonly property color cBorder: Qt.alpha(theme.fg || "#cdd6f4", 0.12)
    readonly property color cFg:     theme.fg || "#cdd6f4"
    readonly property color cMuted:  Qt.alpha(theme.fg || "#cdd6f4", 0.45)
    readonly property color cDim:    Qt.alpha(theme.fg || "#cdd6f4", 0.25)
    readonly property color cAccent: theme.accent || "#89b4fa"

    implicitWidth: cardW
    implicitHeight: cardH

    readonly property real posLeft: safeMargin + (screen.width  - width  - safeMargin * 2) * posX
    readonly property real posTop:  safeMargin + (screen.height - height - safeMargin * 2) * posY

    // no easing for direct drag

    WlrLayershell.anchors { left: true; top: true }
    WlrLayershell.margins { left: dragging ? dragLeft : posLeft; top: dragging ? dragTop : posTop }
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    visible: enabled
    exclusiveZone: 0

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    function firstDayOffset(y, m) {
        const d = new Date(y, m, 1).getDay()
        return (d + 6) % 7
    }

    function syncPositionFromSettings() {
        if (!settings) return
        if (typeof settings.calendarWidgetPosX === "number")
            posX = settings.calendarWidgetPosX
        if (typeof settings.calendarWidgetPosY === "number")
            posY = settings.calendarWidgetPosY
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

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: cBg
        border.color: cBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: Qt.formatDate(root.now, "MMMM").toUpperCase()
                    color: cFg
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Qt.formatDate(root.now, "yyyy")
                    color: cMuted
                    font.pixelSize: 9
                    font.family: "JetBrains Mono"
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: ["M","T","W","T","F","S","S"]
                    Item {
                        width: Math.floor((cardW - 28) / 7)
                        height: 14
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: cDim
                            font.pixelSize: 7
                            font.family: "JetBrains Mono"
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 6
                columnSpacing: 0

                Repeater {
                    model: 42
                    Item {
                        width: Math.floor((cardW - 28) / 7)
                        height: 20

                        property int yearVal:  root.now.getFullYear()
                        property int monthVal: root.now.getMonth()
                        property int offset:   root.firstDayOffset(yearVal, monthVal)
                        property int day:      index - offset + 1
                        property int maxDay:   root.daysInMonth(yearVal, monthVal)
                        property bool inMonth: day >= 1 && day <= maxDay
                        property bool isToday: inMonth && day === root.now.getDate()

                        Text {
                            anchors.centerIn: parent
                            text: inMonth ? String(day) : ""
                            color: isToday ? cBg : (inMonth ? cFg : cDim)
                            font.pixelSize: 10
                            font.family: "JetBrains Mono"
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 16
                            color: isToday ? Qt.alpha(cAccent, 1) : "transparent"
                            border.color: isToday ? Qt.alpha(cBg, 0.7) : "transparent"
                            border.width: isToday ? 1 : 0
                            z: -1
                        }
                    }
                }
            }
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
                settings.calendarWidgetPosX = posX
                settings.calendarWidgetPosY = posY
            }
        }
    }
}
