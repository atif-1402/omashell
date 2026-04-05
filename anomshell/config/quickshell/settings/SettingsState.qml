import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: homeDir + "/.config/quickshell"
    readonly property string settingsDir: configDir + "/settings"
    property string notificationPosition: "top-center"
    property string osdPosition: "bottom-center"
    property string barPosition: "top"
    property string barStyle: "dock"
    property string workspaceStyle: "og"
    property string launcherIconPreset: "command"
    property int launcherIconSize: 12
    property bool clockWidgetEnabled: true
    property bool clockUse24h: true
    property real clockWidgetPosX: 0.8
    property real clockWidgetPosY: 0.8
    property bool calendarWidgetEnabled: false
    property real calendarWidgetPosX: 0.7
    property real calendarWidgetPosY: 0.7
    property bool pomodoroWidgetEnabled: false
    property real pomodoroWidgetPosX: 0.6
    property real pomodoroWidgetPosY: 0.6
    property bool todoWidgetEnabled: false
    property real todoWidgetPosX: 0.5
    property real todoWidgetPosY: 0.5
    property var dockPinnedApps: []
    property bool dockEnabled: true
    property bool dockAutoHide: false
    property bool rememberSettingsWindowPosition: false
    property bool openSettingsOnGeneralAlways: true
    property bool loaded: false
    property string settingsPath: settingsDir + "/settings.json"
    property int saveDelayMs: 500
    readonly property var defaults: ({
        notificationPosition: "top-center",
        osdPosition: "bottom-center",
        barPosition: "top",
        barStyle: "dock",
        workspaceStyle: "og",
        launcherIconPreset: "command",
        launcherIconSize: 12,
        clockWidgetEnabled: true,
        clockUse24h: true,
        clockWidgetPosX: 0.8,
        clockWidgetPosY: 0.8,
        calendarWidgetEnabled: false,
        calendarWidgetPosX: 0.7,
        calendarWidgetPosY: 0.7,
        pomodoroWidgetEnabled: false,
        pomodoroWidgetPosX: 0.6,
        pomodoroWidgetPosY: 0.6,
        todoWidgetEnabled: false,
        todoWidgetPosX: 0.5,
        todoWidgetPosY: 0.5,
        dockPinnedApps: [],
        dockEnabled: true,
        dockAutoHide: false,
        rememberSettingsWindowPosition: false,
        openSettingsOnGeneralAlways: true
    })

    function _applyDefaults() {
        notificationPosition = defaults.notificationPosition
        osdPosition = defaults.osdPosition
        barPosition = defaults.barPosition
        barStyle = defaults.barStyle
        workspaceStyle = defaults.workspaceStyle
        launcherIconPreset = defaults.launcherIconPreset
        launcherIconSize = defaults.launcherIconSize
        clockWidgetEnabled = defaults.clockWidgetEnabled
        clockUse24h = defaults.clockUse24h
        clockWidgetPosX = defaults.clockWidgetPosX
        clockWidgetPosY = defaults.clockWidgetPosY
        calendarWidgetEnabled = defaults.calendarWidgetEnabled
        calendarWidgetPosX = defaults.calendarWidgetPosX
        calendarWidgetPosY = defaults.calendarWidgetPosY
        pomodoroWidgetEnabled = defaults.pomodoroWidgetEnabled
        pomodoroWidgetPosX = defaults.pomodoroWidgetPosX
        pomodoroWidgetPosY = defaults.pomodoroWidgetPosY
        todoWidgetEnabled = defaults.todoWidgetEnabled
        todoWidgetPosX = defaults.todoWidgetPosX
        todoWidgetPosY = defaults.todoWidgetPosY
        dockPinnedApps = defaults.dockPinnedApps
        dockEnabled = defaults.dockEnabled
        dockAutoHide = defaults.dockAutoHide
        rememberSettingsWindowPosition = defaults.rememberSettingsWindowPosition
        openSettingsOnGeneralAlways = defaults.openSettingsOnGeneralAlways
    }

    function _apply(raw) {
        try {
            const data = JSON.parse(raw || "{}")
            if (data.notificationPosition)
                notificationPosition = data.notificationPosition
            if (data.osdPosition)
                osdPosition = data.osdPosition
            if (data.barPosition)
                barPosition = data.barPosition
            if (data.barStyle) {
                if (data.barStyle === "flat")
                    barStyle = "flat"
                else
                    barStyle = "dock"
            }
            if (data.workspaceStyle) {
                if (data.workspaceStyle === "pills")
                    workspaceStyle = "strip"
                else if (["og", "strip", "pulse"].includes(data.workspaceStyle))
                    workspaceStyle = data.workspaceStyle
            }
            if (data.launcherIconPreset)
                launcherIconPreset = data.launcherIconPreset
            if (typeof data.launcherIconSize === "number")
                launcherIconSize = Math.max(10, Math.min(18, Math.round(data.launcherIconSize)))
            if (typeof data.clockWidgetEnabled === "boolean")
                clockWidgetEnabled = data.clockWidgetEnabled
            if (typeof data.clockUse24h === "boolean")
                clockUse24h = data.clockUse24h
            if (typeof data.clockWidgetPosX === "number")
                clockWidgetPosX = Math.max(0, Math.min(1, data.clockWidgetPosX))
            if (typeof data.clockWidgetPosY === "number")
                clockWidgetPosY = Math.max(0, Math.min(1, data.clockWidgetPosY))
            if (typeof data.calendarWidgetEnabled === "boolean")
                calendarWidgetEnabled = data.calendarWidgetEnabled
            if (typeof data.calendarWidgetPosX === "number")
                calendarWidgetPosX = Math.max(0, Math.min(1, data.calendarWidgetPosX))
            if (typeof data.calendarWidgetPosY === "number")
                calendarWidgetPosY = Math.max(0, Math.min(1, data.calendarWidgetPosY))
            if (typeof data.pomodoroWidgetEnabled === "boolean")
                pomodoroWidgetEnabled = data.pomodoroWidgetEnabled
            if (typeof data.pomodoroWidgetPosX === "number")
                pomodoroWidgetPosX = Math.max(0, Math.min(1, data.pomodoroWidgetPosX))
            if (typeof data.pomodoroWidgetPosY === "number")
                pomodoroWidgetPosY = Math.max(0, Math.min(1, data.pomodoroWidgetPosY))
            if (typeof data.todoWidgetEnabled === "boolean")
                todoWidgetEnabled = data.todoWidgetEnabled
            if (typeof data.todoWidgetPosX === "number")
                todoWidgetPosX = Math.max(0, Math.min(1, data.todoWidgetPosX))
            if (typeof data.todoWidgetPosY === "number")
                todoWidgetPosY = Math.max(0, Math.min(1, data.todoWidgetPosY))
            if (Array.isArray(data.dockPinnedApps))
                dockPinnedApps = data.dockPinnedApps.slice()
            if (typeof data.dockEnabled === "boolean")
                dockEnabled = data.dockEnabled
            if (typeof data.dockAutoHide === "boolean")
                dockAutoHide = data.dockAutoHide
            if (typeof data.rememberSettingsWindowPosition === "boolean")
                rememberSettingsWindowPosition = data.rememberSettingsWindowPosition
            if (typeof data.openSettingsOnGeneralAlways === "boolean")
                openSettingsOnGeneralAlways = data.openSettingsOnGeneralAlways
        } catch (e) {
            // keep defaults when the file is missing or malformed
            _applyDefaults()
        }
        loaded = true
    }

    function _writeSettings() {
        const payload = JSON.stringify({
            notificationPosition: notificationPosition,
            osdPosition: osdPosition,
            barPosition: barPosition,
            barStyle: barStyle,
            workspaceStyle: workspaceStyle,
            launcherIconPreset: launcherIconPreset,
            launcherIconSize: launcherIconSize,
            clockWidgetEnabled: clockWidgetEnabled,
            clockUse24h: clockUse24h,
            clockWidgetPosX: clockWidgetPosX,
            clockWidgetPosY: clockWidgetPosY,
            calendarWidgetEnabled: calendarWidgetEnabled,
            calendarWidgetPosX: calendarWidgetPosX,
            calendarWidgetPosY: calendarWidgetPosY,
            pomodoroWidgetEnabled: pomodoroWidgetEnabled,
            pomodoroWidgetPosX: pomodoroWidgetPosX,
            pomodoroWidgetPosY: pomodoroWidgetPosY,
            todoWidgetEnabled: todoWidgetEnabled,
            todoWidgetPosX: todoWidgetPosX,
            todoWidgetPosY: todoWidgetPosY,
            dockPinnedApps: dockPinnedApps,
            dockEnabled: dockEnabled,
            dockAutoHide: dockAutoHide,
            rememberSettingsWindowPosition: rememberSettingsWindowPosition,
            openSettingsOnGeneralAlways: openSettingsOnGeneralAlways
        }, null, 2)

        Quickshell.execDetached([
            "bash",
            "-lc",
            "mkdir -p " + root.settingsDir + " && tmp=" + root.settingsPath + ".tmp && cat > \"$tmp\" <<'EOF'\n" +
            payload +
            "\nEOF\nmv \"$tmp\" " + root.settingsPath
        ])
    }

    function resetToDefaults() {
        _applyDefaults()
        if (loaded) {
            saveTimer.stop()
            _writeSettings()
        }
    }

    function save() {
        if (!loaded)
            return
        saveTimer.restart()
    }

    onNotificationPositionChanged: save()
    onOsdPositionChanged: save()
    onBarPositionChanged: save()
    onBarStyleChanged: save()
    onWorkspaceStyleChanged: save()
    onLauncherIconPresetChanged: save()
    onLauncherIconSizeChanged: save()
    onClockWidgetEnabledChanged: save()
    onClockUse24hChanged: save()
    onClockWidgetPosXChanged: save()
    onClockWidgetPosYChanged: save()
    onCalendarWidgetEnabledChanged: save()
    onCalendarWidgetPosXChanged: save()
    onCalendarWidgetPosYChanged: save()
    onPomodoroWidgetEnabledChanged: save()
    onPomodoroWidgetPosXChanged: save()
    onPomodoroWidgetPosYChanged: save()
    onTodoWidgetEnabledChanged: save()
    onTodoWidgetPosXChanged: save()
    onTodoWidgetPosYChanged: save()
    onDockPinnedAppsChanged: save()
    onDockEnabledChanged: save()
    onDockAutoHideChanged: save()
    onRememberSettingsWindowPositionChanged: save()
    onOpenSettingsOnGeneralAlwaysChanged: save()

    Timer {
        id: saveTimer
        interval: root.saveDelayMs
        repeat: false
        onTriggered: root._writeSettings()
    }

    Process {
        id: loader
        command: ["bash", "-lc", "cat " + root.settingsPath + " 2>/dev/null"]
        running: true
        stdout: SplitParser {
            property string buf: ""
            onRead: data => buf += data + "\n"
        }
        onExited: {
            const raw = loader.stdout && loader.stdout.buf ? loader.stdout.buf : ""
            root._apply(raw)
            loader.stdout.buf = ""
        }
    }
}
