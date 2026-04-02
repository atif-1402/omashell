import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    property var theme: ({})
    property var settings: null
    readonly property bool enabled: settings ? settings.todoWidgetEnabled : true

    property real posX: settings ? settings.todoWidgetPosX : 0.5
    property real posY: settings ? settings.todoWidgetPosY : 0.5
    property bool dragging: false
    property real dragLeft: 0
    property real dragTop: 0
    property real pressOffsetX: 0
    property real pressOffsetY: 0
    property real dragStartLeft: 0
    property real dragStartTop: 0

    readonly property int cardW: 220
    readonly property int safeMargin: 24

    readonly property color cBg:     Qt.darker(theme.bg || "#1e1e2e", 1.08)
    readonly property color cBorder: Qt.alpha(theme.fg || "#cdd6f4", 0.12)
    readonly property color cFg:     theme.fg || "#cdd6f4"
    readonly property color cMuted:  Qt.alpha(theme.fg || "#cdd6f4", 0.45)
    readonly property color cDim:    Qt.alpha(theme.fg || "#cdd6f4", 0.25)
    readonly property color cAccent: theme.accent || "#89b4fa"

    // ── Todo state ────────────────────────────────────────────────────────────
    property var items: []
    property string inputText: ""
    property bool showInput: false

    readonly property string dataFile: (Quickshell.env("HOME") || "") + "/.config/quickshell/todo.json"

    implicitWidth: cardW
    implicitHeight: 220
    height: implicitHeight
    readonly property int contentH: height - 28

    readonly property real posLeft: safeMargin + (screen.width  - width  - safeMargin * 2) * posX
    readonly property real posTop:  safeMargin + (screen.height - height - safeMargin * 2) * posY

    WlrLayershell.anchors { left: true; top: true }
    WlrLayershell.margins { left: dragging ? dragLeft : posLeft; top: dragging ? dragTop : posTop }
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: showInput ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: enabled
    exclusiveZone: 0

    // ── Persistence ───────────────────────────────────────────────────────────
    function save() {
        const json = JSON.stringify(root.items)
        const payload = json.replace(/'/g, "'\\''")
        Quickshell.execDetached([
            "bash",
            "-lc",
            "mkdir -p " + (Quickshell.env("HOME") || "") + "/.config/quickshell; " +
            "printf '%s' '" + payload + "' > " + dataFile
        ])
    }

    Process {
        id: loadProcess
        command: ["bash", "-lc", "cat " + dataFile + " 2>/dev/null || echo '[]'"]
        running: true
        stdout: SplitParser {
            property string buf: ""
            onRead: data => buf += data
        }
        onExited: {
            try {
                const parsed = JSON.parse(loadProcess.stdout.buf.trim())
                if (Array.isArray(parsed)) root.items = parsed
            } catch (e) { root.items = [] }
            loadProcess.stdout.buf = ""
        }
    }

    function syncPositionFromSettings() {
        if (!settings) return
        if (typeof settings.todoWidgetPosX === "number") posX = settings.todoWidgetPosX
        if (typeof settings.todoWidgetPosY === "number") posY = settings.todoWidgetPosY
    }

    Connections {
        target: settings
        function onLoadedChanged() {
            if (settings && settings.loaded) root.syncPositionFromSettings()
        }
    }

    onPosXChanged: if (!dragging) dragLeft = posLeft
    onPosYChanged: if (!dragging) dragTop = posTop

    // ── Drag ─────────────────────────────────────────────────────────────────
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
                settings.todoWidgetPosX = posX
                settings.todoWidgetPosY = posY
            }
        }
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 18
        color: cBg
        border.color: cBorder
        border.width: 1

        Column {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 0

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TO-DO LIST"
                    color: cFg
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    anchors.right: addBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: doneLabel.width + 12
                    height: 16
                    radius: 8
                    color: Qt.alpha(cAccent, 0.12)
                    visible: root.items.length > 0

                    Text {
                        id: doneLabel
                        anchors.centerIn: parent
                        text: root.items.filter(i => i.done).length + "/" + root.items.length
                        color: cAccent
                        font.pixelSize: 8
                        font.family: "JetBrains Mono"
                    }
                }

                Rectangle {
                    id: addBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 99
                    color: showInput ? Qt.alpha(cAccent, 0.18) : Qt.alpha(cFg, 0)
                    border.color: showInput ? Qt.alpha(cAccent, 0.35) : Qt.alpha(cFg, 0.10)
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: showInput ? "" : ""
                        color: showInput ? cAccent : cMuted
                        font.pixelSize: 13
                        font.family: "JetBrains Mono"
                        font.weight: Font.Light
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            showInput = !showInput
                            inputText = ""
                            if (showInput) textInput.forceActiveFocus()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: cBorder
            }

            Item { width: 1; height: 8 }

            Rectangle {
                width: parent.width
                height: showInput ? 32 : 0
                visible: showInput
                radius: 8
                color: Qt.alpha(cFg, 0.05)
                border.color: Qt.alpha(cAccent, 0.30)
                border.width: 1
                clip: true

                TextInput {
                    id: textInput
                    anchors.left: parent.left
                    anchors.right: submitBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    text: root.inputText
                    color: cFg
                    font.pixelSize: 10
                    font.family: "JetBrains Mono"
                    selectionColor: Qt.alpha(cAccent, 0.35)
                    selectedTextColor: cFg
                    maximumLength: 60

                    onTextChanged: root.inputText = text

                    Keys.onReturnPressed: submitItem()
                    Keys.onEscapePressed: {
                        root.showInput = false
                        root.inputText = ""
                    }

                    Text {
                        anchors.fill: parent
                        text: "add a task..."
                        color: cDim
                        font.pixelSize: 10
                        font.family: "JetBrains Mono"
                        visible: textInput.text.length === 0
                    }
                }

                Rectangle {
                    id: submitBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20
                    radius: 5
                    color: Qt.alpha(cAccent, 0.20)

                    Text {
                        anchors.centerIn: parent
                        text: "󰌑"
                        color: cAccent
                        font.pixelSize: 10
                        font.family: "JetBrains Mono"
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: submitItem()
                    }
                }
            }

            Item { width: 1; height: showInput ? 8 : 0; visible: showInput }

            Flickable {
                id: listScroll
                width: parent.width
                height: Math.max(80, root.contentH - (28 + 1 + 8 + (showInput ? 32 + 8 : 0) + 10 + (root.items.some(i => i.done) ? 22 : 0)))
                clip: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: listCol
                    width: listScroll.width - 6
                    spacing: 2

                    Repeater {
                        model: root.items.length

                        Item {
                            id: todoRow
                            width: parent.width
                            height: 30

                            property var item: root.items[index]
                            property bool hovered: false

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: todoRow.hovered ? Qt.alpha(cFg, 0.04) : "transparent"
                            }

                            Rectangle {
                                id: checkbox
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14
                                radius: 4
                                color: todoRow.item.done ? cAccent : "transparent"
                                border.color: todoRow.item.done ? cAccent : Qt.alpha(cFg, 0.20)
                                border.width: 1

                                Rectangle {
                                    visible: todoRow.item.done
                                    anchors.centerIn: parent
                                    width: 7; height: 1.5
                                    radius: 1
                                    color: cBg
                                    rotation: -45
                                    x: -1; y: 1
                                }
                                Rectangle {
                                    visible: todoRow.item.done
                                    anchors.centerIn: parent
                                    width: 4; height: 1.5
                                    radius: 1
                                    color: cBg
                                    rotation: 45
                                    x: -3; y: 2
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toggleItem(index)
                                }
                            }

                            Flickable {
                                id: titleMarquee
                                anchors.left: checkbox.right
                                anchors.leftMargin: 8
                                anchors.right: deleteBtn.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                height: 18
                                clip: true
                                interactive: false
                                contentWidth: titleText.implicitWidth
                                contentHeight: height

                                Text {
                                    id: titleText
                                    text: todoRow.item.text
                                    color: todoRow.item.done ? cDim : cFg
                                    font.pixelSize: 10
                                    font.family: "JetBrains Mono"
                                    font.strikeout: todoRow.item.done
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                NumberAnimation on contentX {
                                    id: marqueeAnim
                                    from: 0
                                    to: Math.max(0, titleMarquee.contentWidth - titleMarquee.width)
                                    duration: 4000
                                    loops: Animation.Infinite
                                    easing.type: Easing.InOutSine
                                    running: titleMarquee.contentWidth > titleMarquee.width && todoRow.hovered
                                }
                            }

                            Text {
                                id: deleteBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: "× "
                                color: cDim
                                font.pixelSize: 13
                                font.family: "JetBrains Mono"
                                visible: todoRow.hovered

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: deleteItem(index)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                hoverEnabled: true
                                onEntered: todoRow.hovered = true
                                onExited:  todoRow.hovered = false
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40
                        visible: root.items.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: "no tasks — enjoy the day"
                            color: cDim
                            font.pixelSize: 9
                            font.family: "JetBrains Mono"
                            font.italic: true
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    radius: 2
                    color: Qt.alpha(cDim, 0.08)
                    visible: listScroll.contentHeight > listScroll.height

                    Rectangle {
                        width: parent.width
                        radius: 2
                        color: Qt.alpha(cAccent, 0.45)
                        height: Math.max(10, parent.height * (listScroll.height / listScroll.contentHeight))
                        y: (listScroll.contentY / Math.max(1, (listScroll.contentHeight - listScroll.height))) * (parent.height - height)
                    }
                }
            }


            Item { width: 1; height: 10 }

            Item {
                width: parent.width
                height: 22
                visible: root.items.some(i => i.done)

                Rectangle {
                    width: parent.width
                    height: 1
                    color: cBorder
                    anchors.top: parent.top
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    text: "clear done"
                    color: cDim
                    font.pixelSize: 8
                    font.family: "JetBrains Mono"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearDone()
                    }
                }
            }
        }
    }

    function submitItem() {
        const t = root.inputText.trim()
        if (t.length === 0) return
        const newItems = root.items.slice()
        newItems.push({ text: t, done: false })
        root.items = newItems
        root.inputText = ""
        textInput.text = ""
        save()
    }

    function toggleItem(idx) {
        const newItems = root.items.slice()
        newItems[idx] = { text: newItems[idx].text, done: !newItems[idx].done }
        root.items = newItems
        save()
    }

    function deleteItem(idx) {
        const newItems = root.items.slice()
        newItems.splice(idx, 1)
        root.items = newItems
        save()
    }

    function clearDone() {
        root.items = root.items.filter(i => !i.done)
        save()
    }
}
