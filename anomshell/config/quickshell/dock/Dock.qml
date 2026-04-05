import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    property var theme: ({})
    property var settings: null
    property var launcher: null
    property var notifServer: null

    property var apps: []
    property var clients: []
    property var lastClients: []
    property double lastClientsAt: 0
    property var pinnedEntries: []
    property var runningEntries: []
    property bool hideOnFullscreen: true
    property bool fullscreenActive: false
    property bool dockShown: true
    property string focusedAddress: ""
    readonly property bool hasFocusedWindow:
        focusedAddress !== "" && focusedAddress !== "0x0" && focusedAddress !== "0x"

    readonly property var pinnedKeys: settings ? (settings.dockPinnedApps || []) : []
    readonly property color cBg: theme.bg || "#1e1e2e"
    readonly property color cBorder: theme.dim || "#45475a"
    readonly property color cFg: theme.fg || "#cdd6f4"
    readonly property color cMuted: theme.muted || "#585b70"
    readonly property color cAccent: theme.accent || "#89b4fa"
    readonly property string launcherIconPreset: settings?.launcherIconPreset || "omarchy"
    readonly property string launcherIconText: launcherIconPreset === "arch"
        ? ""
        : launcherIconPreset === "hyprland"
            ? ""
            : launcherIconPreset === "nix"
                ? ""
                : launcherIconPreset === "command"
                    ? "󰘳"
                    : launcherIconPreset === "windows"
                        ? "󰖳"
                        : "\ue900"
    readonly property string launcherIconFont: launcherIconPreset === "omarchy"
        ? "Omarchy"
        : "JetBrainsMono Nerd Font Propo"
    readonly property int launcherIconSizeDock: Math.max(12, Math.min(18, (settings?.launcherIconSize || 12) + 3))

    anchors { left: true; bottom: true }
    margins {
        left: Math.max(0, Math.round((screen.width - width) / 2))
        bottom: 10
    }

    color: "transparent"
    exclusiveZone: 0
    visible: settings ? ((settings.dockEnabled ?? true) && !fullscreenActive) : !fullscreenActive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int dockWidth: dockRow.implicitWidth + 14
    readonly property int dockHeight: 36
    readonly property bool dockAutoHideActive:
        (settings && settings.dockAutoHide && hasFocusedWindow)
    readonly property bool dockCollapsed: dockAutoHideActive && !dockShown
    width: dockWidth
    height: dockHeight
    implicitWidth: dockWidth
    implicitHeight: dockHeight

    function _isDirectIconSource(icon) {
        const value = icon || ""
        return value.startsWith("/") ||
            value.startsWith("file:") ||
            value.startsWith("image:") ||
            value.startsWith("qrc:") ||
            value.startsWith("data:")
    }

    function _iconProviderSource(icon) {
        const value = icon || ""
        if (value === "") return ""
        if (value.startsWith("/")) return "file://" + value
        if (_isDirectIconSource(value)) return value
        return "image://icon/" + encodeURIComponent(value)
    }

    function _hasAny(text, values) {
        for (const value of values) {
            if (text.includes(value)) return true
        }
        return false
    }

    function _customGlyph(text) {
        const lower = (text || "").toLowerCase()
        if (_hasAny(lower, ["spotify"])) return ""
        if (_hasAny(lower, ["discord", "vesktop"])) return ""
        if (_hasAny(lower, ["telegram"])) return ""
        if (_hasAny(lower, ["steam"])) return ""
        if (_hasAny(lower, ["slack"])) return "󰒱"
        if (_hasAny(lower, ["obs", "obsidian"])) return lower.includes("obsidian") ? "󰎚" : "󰐾"
        if (_hasAny(lower, ["dropbox"])) return "󰇣"
        if (_hasAny(lower, ["github", "gitkraken"])) return "󰊤"
        if (_hasAny(lower, ["signal"])) return "󰭹"
        if (_hasAny(lower, ["whatsapp"])) return "󰖣"
        if (_hasAny(lower, ["element", "matrix"])) return "󱘖"
        if (_hasAny(lower, ["teams"])) return "󰊻"
        if (_hasAny(lower, ["zoom"])) return "󰬡"
        if (_hasAny(lower, ["chromium", "chrome", "brave", "firefox", "browser"])) return "󰖟"
        if (_hasAny(lower, ["code", "vscode", "cursor", "zed"])) return "󰨞"
        if (_hasAny(lower, ["thunderbird", "mail"])) return "󰇮"
        if (_hasAny(lower, ["mpv", "vlc", "media"])) return "󰐊"
        if (_hasAny(lower, ["terminal", "kitty", "wezterm", "alacritty", "foot"])) return "󰆍"
        if (_hasAny(lower, ["files", "thunar", "nautilus", "dolphin"])) return "󰉋"
        return ""
    }

    function _tokenize(value) {
        return (value || "")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, " ")
            .trim()
            .split(/\s+/)
            .filter(t => t.length > 1)
    }

    function resolveAppForClass(className) {
        const cls = (className || "").toLowerCase()
        if (!cls) return null

        const classTokens = _tokenize(cls)
        const isWebAppClass =
            cls.startsWith("chrome-") ||
            cls.startsWith("chromium-") ||
            cls.startsWith("brave-") ||
            cls.startsWith("msedge-")

        function webAppKey() {
            if (!isWebAppClass) return ""
            const noPrefix = cls.replace(/^(chrome|chromium|brave|msedge)-/, "")
            const base = noPrefix.split("__")[0]
            return base || ""
        }

        // Exact matches first
        for (const app of apps) { if (app.idLower === cls) return app }
        for (const app of apps) { if (app.nameLower === cls) return app }
        for (const app of apps) { if (app.wmClassLower && app.wmClassLower === cls) return app }

        // Web apps: try to match on app id/name using the domain key
        if (isWebAppClass) {
            const wk = webAppKey()
            const wkBare = wk.replace(/\.[a-z0-9]+$/, "")
            for (const app of apps) {
                if (app.idLower.startsWith("chrome-") || app.idLower.startsWith("chromium-") || app.idLower.startsWith("brave-") || app.idLower.startsWith("msedge-")) {
                    if (app.idLower === cls) return app
                    if (wk && app.idLower.includes(wk)) return app
                    if (wkBare && app.idLower.includes(wkBare)) return app
                }
                if (wk && app.nameLower.includes(wk)) return app
                if (wkBare && app.nameLower.includes(wkBare)) return app
            }
            // If it's a web app class and we couldn't find a good match, bail to avoid wrong icons.
            return null
        }

        // Substring + token matches (helps web apps / PWAs)
        for (const app of apps) {
            if (app.wmClassLower && (cls.includes(app.wmClassLower) || app.wmClassLower.includes(cls))) return app
            if (cls.includes(app.idLower) || app.idLower.includes(cls)) return app
            if (cls.includes(app.nameLower)) return app
            if (classTokens.some(t => app.idLower.includes(t) || app.nameLower.includes(t))) return app
        }

        return null
    }

    function notificationCount(entry) {
        if (!notifServer || !entry) return 0
        const list = notifServer.notifications || []
        let count = 0
        for (const notif of list) {
            if (_notifMatchesEntry(entry, notif)) count += 1
        }
        return count
    }

    function _notifMatchesEntry(entry, notif) {
        const appName = (notif?.appName || "").toLowerCase().trim()
        if (!appName) return false
        const name = (entry?.name || "").toLowerCase()
        const key = (entry?.key || "").toLowerCase()
        if (name && appName === name) return true
        if (key && appName === key) return true
        if (name && appName.includes(name)) return true
        if (key && appName.includes(key)) return true
        if (entry?.windows) {
            for (const w of entry.windows) {
                const cls = (w.class || "").toLowerCase()
                if (cls && (appName === cls || appName.includes(cls))) return true
            }
        }
        return false
    }

    function focusWindow(addr) {
        if (!addr) return
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr])
    }

    function launchExec(exec) {
        if (!exec) return
        const cmd = exec.replace(/%[uUfFdDnNickvm]/g, "").trim()
        if (!cmd) return
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    function togglePin(key) {
        if (!settings || !key) return
        const next = pinnedKeys.slice()
        const idx = next.indexOf(key)
        if (idx >= 0) next.splice(idx, 1)
        else next.push(key)
        settings.dockPinnedApps = next
    }

    function movePinned(fromKey, toKey) {
        if (!settings || !fromKey) return
        const next = pinnedKeys.slice()
        const fromIdx = next.indexOf(fromKey)
        if (fromIdx < 0) return
        next.splice(fromIdx, 1)
        if (toKey) {
            const toIdx = next.indexOf(toKey)
            if (toIdx >= 0) next.splice(toIdx, 0, fromKey)
            else next.push(fromKey)
        } else {
            next.push(fromKey)
        }
        settings.dockPinnedApps = next
    }

    function rebuildEntries() {
        // Sort clients by workspace id so running entries follow ws order
        const sorted = clients.slice().sort((a, b) => {
            const wa = a.workspaceId ?? 9999
            const wb = b.workspaceId ?? 9999
            return wa !== wb ? wa - wb : 0
        })

        // Build running map preserving workspace-sorted insertion order
        const runningMap = {}
        const runningOrder = []
        for (const c of sorted) {
            const app = resolveAppForClass(c.class)
            const fallbackClass = (c.class || "").toLowerCase()
            const key = app?.id || fallbackClass
            if (!key) continue
            if (!runningMap[key]) {
                const iconFallback = app?.icon || c.class || ""
                runningMap[key] = {
                    key: key,
                    name: app?.name || c.class || key,
                    exec: app?.exec || "",
                    icon: iconFallback,
                    minWorkspaceId: c.workspaceId ?? 9999,
                    windows: []
                }
                runningOrder.push(key)
            }
            runningMap[key].windows.push(c)
        }

        const pins = []
        for (const key of pinnedKeys) {
            const app = apps.find(a => a.id === key) || null
            const running = runningMap[key]
            pins.push({
                key: key,
                name: app?.name || running?.name || key,
                exec: app?.exec || running?.exec || "",
                icon: app?.icon || running?.icon || "",
                minWorkspaceId: running?.minWorkspaceId ?? 9999,
                windows: running?.windows || []
            })
        }

        // Running (unpinned) entries in workspace order
        const run = []
        for (const key of runningOrder) {
            if (pinnedKeys.indexOf(key) >= 0) continue
            run.push(runningMap[key])
        }

        pinnedEntries = pins
        runningEntries = run
    }

    onPinnedKeysChanged: rebuildEntries()
    onClientsChanged: rebuildEntries()
    onAppsChanged: rebuildEntries()

    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            clientsProc.running = false
            clientsProc.running = true
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            appsProc.running = false
            appsProc.running = true
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.hideOnFullscreen
        onTriggered: {
            fullscreenProc.running = false
            fullscreenProc.running = true
        }
    }

    Timer {
        id: dockHideTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (settings && settings.dockAutoHide && root.hasFocusedWindow && !root.hoveringDock)
                dockShown = false
        }
    }

    function revealDock() {
        if (settings && settings.dockAutoHide && hasFocusedWindow) {
            dockShown = true
            dockHideTimer.stop()
        }
    }

    function scheduleHide() {
        if (settings && settings.dockAutoHide && hasFocusedWindow)
            dockHideTimer.restart()
    }

    property bool hoveringDock: false

    Connections {
        target: settings
        function onDockAutoHideChanged() {
            dockShown = !(settings && settings.dockAutoHide && root.hasFocusedWindow)
        }
    }

    Process {
        id: clientsProc
        command: ["bash", "-lc", "hyprctl -j clients 2>/dev/null"]
        running: true
        stdout: SplitParser {
            property string buf: ""
            onRead: data => buf += data
        }
        onExited: {
            const raw = clientsProc.stdout.buf || ""
            clientsProc.stdout.buf = ""
            try {
                const parsed = JSON.parse(raw)
                if (Array.isArray(parsed)) {
                    if (parsed.length === 0) {
                        const nowMs = Date.now()
                        if (root.lastClients.length > 0 && (nowMs - root.lastClientsAt) < 600) {
                            root.clients = root.lastClients
                            return
                        }
                    }
                    const mapped = parsed.map(c => ({
                        class: c.class || c.initialClass || "",
                        title: c.title || "",
                        address: c.address || "",
                        workspaceId: c.workspace?.id ?? 9999
                    }))
                    root.clients = mapped
                    if (mapped.length > 0) {
                        root.lastClients = mapped
                        root.lastClientsAt = Date.now()
                    }
                }
            } catch (e) {
                // keep last known clients
            }
        }
    }

    Process {
        id: appsProc
        command: ["bash", "-lc",
            "XDG_DATA_HOME=\"${XDG_DATA_HOME:-$HOME/.local/share}\"; " +
            "XDG_DATA_DIRS=\"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"; " +
            "for f in " +
            "/usr/share/applications/*.desktop " +
            "/usr/local/share/applications/*.desktop " +
            "\"$XDG_DATA_HOME\"/applications/*.desktop " +
            "\"$XDG_DATA_HOME\"/flatpak/exports/share/applications/*.desktop " +
            "/var/lib/flatpak/exports/share/applications/*.desktop; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  wmclass=$(grep -m1 '^StartupWMClass=' \"$f\" | cut -d= -f2-); " +
            "  [ \"$nodisplay\" = \"true\" ] && continue; " +
            "  [ -z \"$name\" ] && continue; " +
            "  [ -z \"$exec\" ] && continue; " +
            "  id=$(basename \"$f\" .desktop); " +
            "  printf '%s|%s|%s|%s|%s\\n' \"$name\" \"$exec\" \"$icon\" \"$id\" \"$wmclass\"; " +
            "done | sort -u"
        ]
        running: true
        stdout: SplitParser {
            property var list: []
            property string buf: ""
            onRead: data => {
                buf += data + "\n"
                const lines = buf.split("\n")
                buf = lines.pop()
                for (const line of lines) {
                    const t = (line || "").trim()
                    if (!t) continue
                    const parts = t.split("|")
                    if (parts.length < 4) continue
                    const name = parts[0].trim()
                    const exec = parts[1].trim()
                    const icon = parts[2].trim()
                    const id = parts[3].trim()
                    const wmclass = (parts[4] || "").trim()
                    if (name && exec && id) {
                        list.push({
                            name, exec, icon, id, wmclass,
                            nameLower: name.toLowerCase(),
                            idLower: id.toLowerCase(),
                            wmClassLower: wmclass.toLowerCase()
                        })
                    }
                }
            }
        }
        onExited: {
            root.apps = appsProc.stdout.list.slice()
            appsProc.stdout.list = []
            appsProc.stdout.buf = ""
        }
    }

    Process {
        id: fullscreenProc
        command: ["bash", "-lc", "hyprctl -j activewindow 2>/dev/null"]
        running: true
        stdout: SplitParser {
            property string buf: ""
            onRead: data => buf += data
        }
        onExited: {
            const raw = fullscreenProc.stdout.buf || ""
            fullscreenProc.stdout.buf = ""
            try {
                const obj = JSON.parse(raw)
                root.fullscreenActive = (obj.fullscreen || 0) > 0
                root.focusedAddress = obj.address || ""
            } catch (e) {
                root.fullscreenActive = false
                root.focusedAddress = ""
            }
        }
    }

    onFocusedAddressChanged: {
        clientsProc.running = false
        clientsProc.running = true

        if (settings && settings.dockAutoHide) {
            if (root.hasFocusedWindow) {
                if (!root.hoveringDock)
                    root.scheduleHide()
            } else {
                root.dockHideTimer.stop()
                root.dockShown = true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: cBg
        border.color: Qt.alpha(cBorder, 0.7)
        border.width: 1
        visible: (settings ? (settings.dockEnabled ?? true) : true) && !root.fullscreenActive
        enabled: !root.dockCollapsed
        transform: Translate {
            y: (settings && settings.dockAutoHide && root.hasFocusedWindow && !dockShown) ? (height + 8) : 0
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse
            onHoveredChanged: {
                root.hoveringDock = hovered
                if (hovered) root.revealDock()
                else root.scheduleHide()
            }
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 3

            DockButton {
                id: launcherBtn
                theme: root.theme
                label: "Launcher"
                glyph: root.launcherIconText
                glyphFont: root.launcherIconFont
                glyphSize: root.launcherIconSizeDock
                onActivated: {
                    if (root.launcher) {
                        root.launcher.mode = "apps"
                        root.launcher.showing = true
                    }
                }
            }

            DockButton {
                id: taskManagerBtn
                theme: root.theme
                label: "Task Manager"
                glyph: ""
                glyphFont: "JetBrainsMono Nerd Font Propo"
                glyphSize: 14
                onActivated: {
                    Quickshell.execDetached([
                        "quickshell", "ipc", "call", "openTaskManager", "handle"
                    ])
                }
            }

            DockSeparator { visible: pinnedEntries.length + runningEntries.length > 0 }

            Repeater {
                model: pinnedEntries
                delegate: DockItem {
                    theme: root.theme
                    entry: modelData
                    running: modelData.windows.length > 0
                    pinned: true
                    enableDrag: true
                    onActivate: {
                        if (entry.windows.length > 0)
                            root.focusWindow(entry.windows[0].address)
                        else
                            root.launchExec(entry.exec)
                    }
                    onTogglePin: root.togglePin(entry.key)
                }
            }

            DockSeparator { visible: runningEntries.length > 0 && pinnedEntries.length > 0 }

            Repeater {
                model: runningEntries
                delegate: DockItem {
                    theme: root.theme
                    entry: modelData
                    running: true
                    pinned: false
                    onActivate: root.focusWindow(entry.windows[0]?.address)
                    onTogglePin: root.togglePin(entry.key)
                }
            }

            DropArea {
                visible: pinnedEntries.length > 0
                keys: ["application/x-dock-key"]
                width: 4
                height: 28
                onDropped: drop => {
                    const key = drop.getDataAsString("application/x-dock-key")
                    if (key) root.movePinned(key, null)
                }
            }
        }
    }

    PanelWindow {
        id: dockHotspot
        visible: settings
            ? ((settings.dockEnabled ?? true) && (settings.dockAutoHide ?? false) && root.hasFocusedWindow && !root.fullscreenActive)
            : false
        anchors { left: true; right: true; bottom: true }
        margins { bottom: 0 }
        implicitHeight: 2
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onEntered: root.revealDock()
            onExited: root.scheduleHide()
            onClicked: root.revealDock()
        }
    }

    onVisibleChanged: {
        if (settings && settings.dockAutoHide && root.hasFocusedWindow)
            dockShown = false
        else
            dockShown = true
    }

    component DockSeparator: Item {
        width: 5
        height: 25
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: 15
            radius: 1
            color: Qt.alpha(root.cMuted, 0.7)
        }
    }

    component DockButton: Item {
        id: btn
        property var theme: ({})
        property string label: ""
        property string glyph: ""
        property string glyphFont: "JetBrainsMono Nerd Font Propo"
        property int glyphSize: 15
        signal activated()

        width: 28
        height: 28
        property bool hovered: ma.containsMouse

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: glyph !== "" ? glyph : label.slice(0, 1).toUpperCase()
            color: root.cAccent
            font.pixelSize: btn.glyphSize
            font.family: glyphFont
        }
        scale: btn.hovered ? 1.1 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            cursorShape: Qt.PointingHandCursor
            onEntered: { root.hoveringDock = true; root.revealDock() }
            onExited: { root.hoveringDock = false; root.scheduleHide() }
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    Quickshell.execDetached(["quickshell", "ipc", "call", "openSettings", "handle"])
                    mouse.accepted = true
                }
            }
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) btn.activated()
            }
        }
    }

    component DockItem: Item {
        id: item
        property var theme: ({})
        property var entry: ({})
        property bool running: false
        property bool pinned: false
        property bool enableDrag: false
        property bool focused: entry && entry.windows
            ? entry.windows.some(w => w.address === root.focusedAddress)
            : false
        property int notifCount: root.notificationCount(entry)
        signal activate()
        signal togglePin()

        width: 28
        height: 28
        property bool hovered: itemMa.containsMouse
        property bool dragging: false

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        IconImage {
            id: iconImg
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            width: 18
            height: 18
            source: root._iconProviderSource(entry.icon)
            visible: (entry.icon || "") !== "" && source !== ""
        }

        Text {
            id: glyphText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: iconImg.visible ? "" : (root._customGlyph(entry.name || entry.key || "") || (entry.name || entry.key || "?").slice(0, 1).toUpperCase())
            color: running ? root.cAccent : root.cFg
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font Propo"
        }

        // Running / focused dot
        Rectangle {
            visible: running
            width: focused ? 12 : 3
            height: 3
            radius: 1.5
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            color: root.cAccent
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        // Notification badge
        Rectangle {
            visible: notifCount > 0
            width: notifCount > 9 ? 14 : 11
            height: 11
            radius: 6
            color: root.cAccent
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: -2
            anchors.topMargin: -2

            Text {
                anchors.centerIn: parent
                text: notifCount > 9 ? "9+" : String(notifCount)
                color: root.cBg
                font.pixelSize: 7
                font.bold: true
                font.family: "JetBrainsMono Nerd Font Propo"
            }
        }

        MouseArea {
            id: itemMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            cursorShape: Qt.PointingHandCursor
            onEntered: { root.hoveringDock = true; root.revealDock() }
            onExited: { root.hoveringDock = false; root.scheduleHide() }
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    item.togglePin()
                    mouse.accepted = true
                }
            }
            onReleased: mouse => { item.dragging = false }
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    item.activate()
                    mouse.accepted = true
                }
            }
            onPressAndHold: {
                if (!item.enableDrag || !entry.key) return
                item.dragging = true
                Drag.start()
            }
        }

        scale: hovered ? 1.1 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Drag.active: item.dragging
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.mimeData: ({ "application/x-dock-key": entry.key })

        DropArea {
            anchors.fill: parent
            keys: ["application/x-dock-key"]
            onDropped: drop => {
                const key = drop.getDataAsString("application/x-dock-key")
                if (key) root.movePinned(key, entry.key)
            }
        }
    }
}
