import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var state: null
    property var theme: ({})

    function t(key, fallback) { return theme[key] || fallback }

    function isEnabled() {
        return root.state ? root.state.clockWidgetEnabled : true
    }

    function setEnabled(val) {
        if (root.state)
            root.state.clockWidgetEnabled = val
    }

    function calendarEnabled() {
        return root.state ? root.state.calendarWidgetEnabled : false
    }

    function setCalendarEnabled(val) {
        if (root.state)
            root.state.calendarWidgetEnabled = val
    }

    function pomodoroEnabled() {
        return root.state ? root.state.pomodoroWidgetEnabled : false
    }

    function setPomodoroEnabled(val) {
        if (root.state)
            root.state.pomodoroWidgetEnabled = val
    }

    function todoEnabled() {
        return root.state ? root.state.todoWidgetEnabled : false
    }

    function setTodoEnabled(val) {
        if (root.state)
            root.state.todoWidgetEnabled = val
    }



    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight

        Column {
            id: contentColumn
            width: root.width
            spacing: 10

            Rectangle {
                width: parent.width
                radius: 16
                color: Qt.darker(t("bg", "#0b100c"), 1.04)
                border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.1)
                border.width: 1
                implicitHeight: 168

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Clock widget"
                        color: Qt.alpha(t("muted", "#9fb29f"), 0.8)
                        font.pixelSize: 9
                        font.family: "JetBrains Mono"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 10
                        color: Qt.alpha(t("dim", "#45475a"), 0.14)
                        border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Desktop clock"
                                    color: t("fg", "#eef6ef")
                                    font.pixelSize: 9
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Show the floating desktop clock widget."
                                    color: Qt.alpha(t("muted", "#9fb29f"), 0.58)
                                    font.pixelSize: 7
                                    font.family: "JetBrains Mono"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 40
                                height: 20
                                radius: 10
                                color: root.isEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.35)
                                    : Qt.alpha(t("dim", "#45475a"), 0.35)
                                border.color: root.isEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.55)
                                    : Qt.alpha(t("accent", "#9ccfa0"), 0.12)
                                border.width: 1

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    y: 3
                                    x: root.isEnabled() ? (parent.width - width - 3) : 3
                                    color: root.isEnabled()
                                        ? t("accent", "#9ccfa0")
                                        : Qt.alpha(t("fg", "#eef6ef"), 0.6)

                                    Behavior on x {
                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setEnabled(!root.isEnabled())
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Time format"
                                color: t("fg", "#eef6ef")
                                font.pixelSize: 9
                                font.family: "JetBrains Mono"
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: "Switch between 24-hour and 12-hour time."
                                color: Qt.alpha(t("muted", "#9fb29f"), 0.58)
                                font.pixelSize: 7
                                font.family: "JetBrains Mono"
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 59
                            height: 22
                            radius: 11
                            color: Qt.alpha(t("dim", "#45475a"), 0.2)
                            border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.18)
                            border.width: 1

                            Rectangle {
                                width: 26  
                                height: 16
                                radius: 8
                                y: 3
                                x: (root.state && root.state.clockUse24h) ? 3 : (parent.width - width - 3)
                                color: t("accent", "#9ccfa0")

                                Behavior on x {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                text: "24H"
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: (root.state && root.state.clockUse24h)
                                    ? t("bg", "#0b100c")
                                    : Qt.alpha(t("fg", "#eef6ef"), 0.6)
                                font.pixelSize: 8
                                font.family: "JetBrains Mono"
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: "12H"
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: (root.state && !root.state.clockUse24h)
                                    ? t("bg", "#0b100c")
                                    : Qt.alpha(t("fg", "#eef6ef"), 0.6)
                                font.pixelSize: 8
                                font.family: "JetBrains Mono"
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.state)
                                        root.state.clockUse24h = !root.state.clockUse24h
                                }
                            }
                        }
                    }

                }
            }

            Rectangle {
                width: parent.width
                radius: 16
                color: Qt.darker(t("bg", "#0b100c"), 1.04)
                border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.1)
                border.width: 1
                implicitHeight: 92

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Calendar widget"
                        color: Qt.alpha(t("muted", "#9fb29f"), 0.8)
                        font.pixelSize: 9
                        font.family: "JetBrains Mono"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 10
                        color: Qt.alpha(t("dim", "#45475a"), 0.14)
                        border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Desktop calendar"
                                    color: t("fg", "#eef6ef")
                                    font.pixelSize: 9
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Show the floating calendar widget."
                                    color: Qt.alpha(t("muted", "#9fb29f"), 0.58)
                                    font.pixelSize: 7
                                    font.family: "JetBrains Mono"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 40
                                height: 20
                                radius: 10
                                color: root.calendarEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.35)
                                    : Qt.alpha(t("dim", "#45475a"), 0.35)
                                border.color: root.calendarEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.55)
                                    : Qt.alpha(t("accent", "#9ccfa0"), 0.12)
                                border.width: 1

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    y: 3
                                    x: root.calendarEnabled() ? (parent.width - width - 3) : 3
                                    color: root.calendarEnabled()
                                        ? t("accent", "#9ccfa0")
                                        : Qt.alpha(t("fg", "#eef6ef"), 0.6)

                                    Behavior on x {
                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setCalendarEnabled(!root.calendarEnabled())
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 16
                color: Qt.darker(t("bg", "#0b100c"), 1.04)
                border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.1)
                border.width: 1
                implicitHeight: 92

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Todo widget"
                        color: Qt.alpha(t("muted", "#9fb29f"), 0.8)
                        font.pixelSize: 9
                        font.family: "JetBrains Mono"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 10
                        color: Qt.alpha(t("dim", "#45475a"), 0.14)
                        border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Desktop todo"
                                    color: t("fg", "#eef6ef")
                                    font.pixelSize: 9
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Quick tasks you can check off."
                                    color: Qt.alpha(t("muted", "#9fb29f"), 0.58)
                                    font.pixelSize: 7
                                    font.family: "JetBrains Mono"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 40
                                height: 20
                                radius: 10
                                color: root.todoEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.35)
                                    : Qt.alpha(t("dim", "#45475a"), 0.35)
                                border.color: root.todoEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.55)
                                    : Qt.alpha(t("accent", "#9ccfa0"), 0.12)
                                border.width: 1

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    y: 3
                                    x: root.todoEnabled() ? (parent.width - width - 3) : 3
                                    color: root.todoEnabled()
                                        ? t("accent", "#9ccfa0")
                                        : Qt.alpha(t("fg", "#eef6ef"), 0.6)

                                    Behavior on x {
                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setTodoEnabled(!root.todoEnabled())
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                radius: 16
                color: Qt.darker(t("bg", "#0b100c"), 1.04)
                border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.1)
                border.width: 1
                implicitHeight: 92

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Pomodoro widget"
                        color: Qt.alpha(t("muted", "#9fb29f"), 0.8)
                        font.pixelSize: 9
                        font.family: "JetBrains Mono"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 10
                        color: Qt.alpha(t("dim", "#45475a"), 0.14)
                        border.color: Qt.alpha(t("accent", "#9ccfa0"), 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Desktop pomodoro"
                                    color: t("fg", "#eef6ef")
                                    font.pixelSize: 9
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "25 min focus + 5 min break with alerts."
                                    color: Qt.alpha(t("muted", "#9fb29f"), 0.58)
                                    font.pixelSize: 7
                                    font.family: "JetBrains Mono"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 40
                                height: 20
                                radius: 10
                                color: root.pomodoroEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.35)
                                    : Qt.alpha(t("dim", "#45475a"), 0.35)
                                border.color: root.pomodoroEnabled()
                                    ? Qt.alpha(t("accent", "#9ccfa0"), 0.55)
                                    : Qt.alpha(t("accent", "#9ccfa0"), 0.12)
                                border.width: 1

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    y: 3
                                    x: root.pomodoroEnabled() ? (parent.width - width - 3) : 3
                                    color: root.pomodoroEnabled()
                                        ? t("accent", "#9ccfa0")
                                        : Qt.alpha(t("fg", "#eef6ef"), 0.6)

                                    Behavior on x {
                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPomodoroEnabled(!root.pomodoroEnabled())
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
