import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var state: null
    property var theme: ({})

    function t(key, fallback) { return theme[key] || fallback }

    function isDockEnabled() {
        return root.state ? root.state.dockEnabled : true
    }

    function toggleDockEnabled() {
        if (root.state)
            root.state.dockEnabled = !root.state.dockEnabled
    }

    function isAutoHide() {
        return root.state ? root.state.dockAutoHide : false
    }

    function toggleAutoHide() {
        if (root.state)
            root.state.dockAutoHide = !root.state.dockAutoHide
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

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
                    implicitHeight: 142

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text {
                            text: "Dock"
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
                                        text: "Show dock"
                                        color: t("fg", "#eef6ef")
                                        font.pixelSize: 9
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        text: "Toggle dock visibility."
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
                                    color: root.isDockEnabled()
                                        ? Qt.alpha(t("accent", "#9ccfa0"), 0.35)
                                        : Qt.alpha(t("dim", "#45475a"), 0.35)
                                    border.color: root.isDockEnabled()
                                        ? Qt.alpha(t("accent", "#9ccfa0"), 0.55)
                                        : Qt.alpha(t("accent", "#9ccfa0"), 0.12)
                                    border.width: 1

                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7
                                        y: 3
                                        x: root.isDockEnabled() ? (parent.width - width - 3) : 3
                                        color: root.isDockEnabled()
                                            ? t("accent", "#9ccfa0")
                                            : Qt.alpha(t("fg", "#eef6ef"), 0.6)

                                        Behavior on x {
                                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleDockEnabled()
                                    }
                                }
                            }
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
                                        text: "Smart auto hide"
                                        color: t("fg", "#eef6ef")
                                        font.pixelSize: 9
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        text: "Hide the dock when focused on window and shows on hovering in the bottom area (Always show on empty desktop)"
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
                                    color: root.isAutoHide()
                                        ? Qt.alpha(t("accent", "#9ccfa0"), 0.35)
                                        : Qt.alpha(t("dim", "#45475a"), 0.35)
                                    border.color: root.isAutoHide()
                                        ? Qt.alpha(t("accent", "#9ccfa0"), 0.55)
                                        : Qt.alpha(t("accent", "#9ccfa0"), 0.12)
                                    border.width: 1

                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7
                                        y: 3
                                        x: root.isAutoHide() ? (parent.width - width - 3) : 3
                                        color: root.isAutoHide()
                                            ? t("accent", "#9ccfa0")
                                            : Qt.alpha(t("fg", "#eef6ef"), 0.6)

                                        Behavior on x {
                                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleAutoHide()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
