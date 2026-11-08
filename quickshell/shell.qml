//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    function closeTrayMenus() {
        let items = SystemTray.items.values;
        if (!items) return;
        for (let i = 0; i < items.length; i++) {
            let item = items[i];
            if (item.menu && item.menu.isOpen) {
                item.menu.close();
            }
        }
    }

    IpcHandler {
        target: "startmenu"
        function toggle(): void { 
            root.closeTrayMenus()
            if (startMenu.visible) {
                startMenu.visible = false;
            } else {
                mediaPopup.visible = false;
                startMenu.visible = true;
            }
        }
        function open(): void { 
            root.closeTrayMenus()
            mediaPopup.visible = false;
            startMenu.visible = true;
        }
        function close(): void { 
            startMenu.visible = false 
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            startMenu.visible = false;
            mediaPopup.visible = false;
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    property real cpuUsage: 0
    property real cpuTemp: 0
    property double prevTotal: 0
    property double prevIdle: 0

    FileView {
        id: procStat
        path: "/proc/stat"
        onLoaded: {
            const line = text().split("\n")[0];
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            if (f.length < 5) return;
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            const dIdle = idle - root.prevIdle;
            const dTotal = total - root.prevTotal;
            if (root.prevTotal > 0 && dTotal > 0) {
                root.cpuUsage = Math.round(100 * (1 - dIdle / dTotal));
            }
            root.prevIdle = idle;
            root.prevTotal = total;
        }
    }

    Process {
        id: tempProcess
        command: ["sensors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    let maxTemp = 0;
                    for (const chip in data) {
                        if (chip.includes("k10temp") || chip.includes("coretemp") || chip.includes("zenpower")) {
                            for (const sensor in data[chip]) {
                                for (const key in data[chip][sensor]) {
                                    if (key.endsWith("_input")) {
                                        let val = data[chip][sensor][key];
                                        if (val > maxTemp) maxTemp = val;
                                    }
                                }
                            }
                        }
                    }
                    if (maxTemp > 0) root.cpuTemp = maxTemp;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procStat.reload();
            tempProcess.running = true;
        }
    }

    readonly property var activePlayer: {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].playbackState === MprisPlaybackState.Playing) return ps[i];
        }
        return ps.length > 0 ? ps[0] : null;
    }

    property real mediaPosition: 0
    property bool isSeeking: false
    property real seekPreview: 0
    property real lastPlayerVolume: 1.0

    Timer {
        interval: 1000
        running: root.activePlayer !== null && root.activePlayer.playbackState === MprisPlaybackState.Playing && !root.isSeeking
        repeat: true
        triggeredOnStart: true
        onTriggered: root.mediaPosition = root.activePlayer ? (root.activePlayer.position || 0) : 0
    }
    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() { root.mediaPosition = root.activePlayer?.position || 0; }
        function onPositionChanged() { if (!root.isSeeking) root.mediaPosition = root.activePlayer?.position || 0; }
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + String(s).padStart(2, "0");
    }

    function resolveIcon(appId) {
        if (!appId) return "";
        let cleanId = appId.replace(/\.desktop$/, "").toLowerCase();
        
        if (cleanId.includes("steam")) return Quickshell.iconPath("steam");
        if (cleanId.includes("renoise")) return Quickshell.iconPath("renoise");

        let entry = DesktopEntries.heuristicLookup(cleanId);
        if (entry && entry.icon) return Quickshell.iconPath(entry.icon, "");

        entry = DesktopEntries.byId(cleanId);
        if (entry && entry.icon) return Quickshell.iconPath(entry.icon, "");

        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].id && apps[i].id.toLowerCase() === cleanId) {
                if (apps[i].icon) return Quickshell.iconPath(apps[i].icon, "");
            }
            if (apps[i].startupClass && apps[i].startupClass.toLowerCase() === cleanId) {
                if (apps[i].icon) return Quickshell.iconPath(apps[i].icon, "");
            }
        }
        return Quickshell.iconPath(cleanId, "");
    }

    property var customFolders: [
        { "name": "archi", "path": "/home/archi/" },
        { "name": "games", "path": "/disk2/games/" },
        { "name": "Downloads", "path": "/home/archi/Downloads/" },
        { "name": "images", "path": "/home/archi/images/" },
        { "name": "VideoObs", "path": "/disk2/VideoObs/" },
        { "name": "audio", "path": "/disk2/audio/" },
        { "name": "disk2", "path": "/disk2/" }
    ]

    ListModel { id: taskbarModel }

    function syncTaskbar() {
        let toplevels = ToplevelManager.toplevels.values;
        if (!toplevels) return;
        
        for (let i = taskbarModel.count - 1; i >= 0; i--) {
            let tl = taskbarModel.get(i).toplevel;
            if (toplevels.indexOf(tl) === -1) taskbarModel.remove(i);
        }
        
        for (let j = 0; j < toplevels.length; j++) {
            let tl = toplevels[j];
            let found = false;
            for (let i = 0; i < taskbarModel.count; i++) {
                if (taskbarModel.get(i).toplevel === tl) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                taskbarModel.append({
                    "toplevel": tl,
                    "appId": tl.appId
                });
            }
        }
    }
    Component.onCompleted: syncTaskbar()

    Connections {
        target: ToplevelManager.toplevels
        function onObjectInsertedPost(obj, index) {
            if (obj.appId) {
                taskbarModel.append({
                    "toplevel": obj,
                    "appId": obj.appId
                });
            }
        }
        function onObjectRemovedPost(obj, index) {
            for (let i = 0; i < taskbarModel.count; i++) {
                if (taskbarModel.get(i).toplevel === obj) {
                    taskbarModel.remove(i);
                    break;
                }
            }
        }
    }

    PanelWindow {
        id: panel
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 30
        exclusionMode: ExclusionMode.Auto

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#3a93ff" }
                GradientStop { position: 1.0; color: "#0058ee" }
            }
            border.color: "transparent"
            border.width: 0
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: "#80c2ff"
            }

            Rectangle {
                id: startButton
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 80; height: 26
                gradient: Gradient {
                    GradientStop { position: 0.0; color: startMouse.containsMouse ? "#4bb84b" : "#3c8d3c" }
                    GradientStop { position: 1.0; color: startMouse.containsMouse ? "#247524" : "#1d5a1d" }
                }
                topRightRadius: 10
                bottomRightRadius: 10
                border.color: "#1b4e1b"
                border.width: 1
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: "start"
                    color: "white"
                    font.bold: true; font.italic: true
                    font.pixelSize: 14; font.family: "Tahoma"
                }
                MouseArea {
                    id: startMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.closeTrayMenus()
                        if (startMenu.visible) {
                            startMenu.visible = false;
                        } else {
                            mediaPopup.visible = false;
                            startMenu.visible = true;
                        }
                    }
                }
            }

            Item {
                id: taskbarContainer
                anchors.left: startButton.right
                anchors.leftMargin: 6
                anchors.right: trayArea.left
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Rectangle {
                    id: leftArrow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 22
                    color: leftHover.containsMouse ? "#1c5bb3" : "#3b7fe5"
                    border.color: "#104091"
                    radius: 3
                    opacity: enabled ? 1.0 : 0.3
                    enabled: taskbarList.contentWidth > taskbarList.width && taskbarList.contentX > 0

                    Text { anchors.centerIn: parent; text: "<"; color: "white"; font.bold: true; font.pixelSize: 12 }
                    
                    MouseArea {
                        id: leftHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: leftScrollTimer.start()
                        onReleased: leftScrollTimer.stop()
                        onExited: leftScrollTimer.stop()
                    }
                    Timer {
                        id: leftScrollTimer
                        interval: 50; repeat: true
                        onTriggered: {
                            taskbarList.contentX = Math.max(0, taskbarList.contentX - 30);
                            if (taskbarList.contentX <= 0) leftScrollTimer.stop();
                        }
                    }
                }

                Rectangle {
                    id: rightArrow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 22
                    color: rightHover.containsMouse ? "#1c5bb3" : "#3b7fe5"
                    border.color: "#104091"
                    radius: 3
                    opacity: enabled ? 1.0 : 0.3
                    enabled: taskbarList.contentWidth > taskbarList.width && taskbarList.contentX < (taskbarList.contentWidth - taskbarList.width)

                    Text { anchors.centerIn: parent; text: ">"; color: "white"; font.bold: true; font.pixelSize: 12 }
                    
                    MouseArea {
                        id: rightHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: rightScrollTimer.start()
                        onReleased: rightScrollTimer.stop()
                        onExited: rightScrollTimer.stop()
                    }
                    Timer {
                        id: rightScrollTimer
                        interval: 50; repeat: true
                        onTriggered: {
                            taskbarList.contentX = Math.min(taskbarList.contentWidth - taskbarList.width, taskbarList.contentX + 30);
                            if (taskbarList.contentX >= (taskbarList.contentWidth - taskbarList.width)) rightScrollTimer.stop();
                        }
                    }
                }

                ListView {
                    id: taskbarList
                    anchors.left: leftArrow.enabled ? leftArrow.right : parent.left
                    anchors.right: rightArrow.enabled ? rightArrow.left : parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: leftArrow.enabled ? 4 : 0
                    anchors.rightMargin: rightArrow.enabled ? 4 : 0
                    height: 22
                    orientation: ListView.Horizontal
                    spacing: 2
                    clip: true
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds

                    Behavior on contentX { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    model: DelegateModel {
                        id: visualModel
                        model: taskbarModel

                        delegate: Item {
                            id: taskItem
                            required property var modelData
                            required property int index
                            property int visualIndex: DelegateModel.itemsIndex
                            
                            width: 140; height: 22

                            Rectangle {
                                id: taskButton
                                x: 0; y: 0
                                width: parent.width; height: parent.height
                                color: (dragArea.containsMouse || dragArea.drag.active) ? "#4a8cf0" : (modelData.toplevel.activated ? "#1c5bb3" : "#3b7fe5")
                                border.color: "#104091"
                                radius: 3

                                Drag.active: dragArea.drag.active
                                Drag.source: taskItem
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Row {
                                    width: parent.width - 8
                                    height: parent.height
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Image {
                                        id: appIcon
                                        source: root.resolveIcon(modelData.appId)
                                        width: 14; height: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        fillMode: Image.PreserveAspectFit
                                        visible: source != ""
                                    }

                                    Text {
                                        text: modelData.toplevel.title
                                        color: "white"; font.pixelSize: 11; font.family: "Tahoma"
                                        elide: Text.ElideRight
                                        width: parent.width - 18
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: (drag) => {
                                    if (drag.source && drag.source.visualIndex !== undefined) {
                                        if (drag.source.visualIndex !== taskItem.visualIndex) {
                                            visualModel.items.move(drag.source.visualIndex, taskItem.visualIndex, 1);
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: taskButton
                                drag.axis: Drag.XAxis
                                drag.threshold: 10

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton && !dragArea.drag.active) {
                                        modelData.toplevel.activate();
                                    } else if (mouse.button === Qt.RightButton) {
                                        modelData.toplevel.close();
                                    }
                                }
                                
                                onReleased: {
                                    if (dragArea.drag.active) {
                                        taskButton.x = 0;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: trayArea
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: trayRow.implicitWidth + 12
                height: 24
                color: "#0c59b9"
                border.color: "#083b7a"
                border.width: 1
                radius: 2

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8
                    layoutDirection: Qt.RightToLeft

                    Text {
                        id: clockText
                        color: "#ffffff"; font.pixelSize: 11; font.family: "Tahoma"
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(new Date(), "HH:mm")
                        Timer {
                            interval: 1000; running: true; repeat: true
                            onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
                        }
                    }

                    Rectangle { width: 1; height: 14; color: "#4183c6"; anchors.verticalCenter: parent.verticalCenter }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            color: "#ffffff"; font.pixelSize: 11; font.family: "Tahoma"
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CPU " + root.cpuUsage + "%"
                        }
                        Text {
                            color: "#ffffff"; font.pixelSize: 11; font.family: "Tahoma"
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.cpuTemp > 0 ? Math.round(root.cpuTemp) + "°C" : "--°C"
                        }
                    }

                    Text {
                        color: "#ffffff"; font.pixelSize: 11; font.family: "Tahoma"
                        anchors.verticalCenter: parent.verticalCenter
                        text: Pipewire.defaultAudioSink?.ready
                              ? (Pipewire.defaultAudioSink.audio.muted ? "MUTE" : "VOL " + Math.round(Pipewire.defaultAudioSink.audio.volume * 100))
                              : "VOL --"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (Pipewire.defaultAudioSink?.ready)
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                            }
                            onWheel: (wheel) => {
                                if (Pipewire.defaultAudioSink?.ready) {
                                    let step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                    let vol = Pipewire.defaultAudioSink.audio.volume + step
                                    Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1, vol))
                                }
                            }
                        }
                    }

                    Item {
                        id: mediaIndicator
                        visible: root.activePlayer !== null
                        width: visible ? Math.min(140, mediaLabel.implicitWidth + 20) : 0
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            color: mediaHover.containsMouse ? "#1c6ed4" : "transparent"
                            radius: 2
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "♪" : "❚❚"
                                font.pixelSize: 11; font.bold: true; font.family: "Tahoma"
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: mediaLabel
                                text: {
                                    if (!root.activePlayer) return "";
                                    let t = root.activePlayer.trackTitle || "Unknown";
                                    return t.length > 20 ? t.substring(0, 18) + "…" : t;
                                }
                                font.pixelSize: 11; font.family: "Tahoma"
                                color: "#ffffff"
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: mediaHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onClicked: (mouse) => {
                                if (!root.activePlayer) return;
                                if (mouse.button === Qt.LeftButton) {
                                    root.closeTrayMenus()
                                    if (mediaPopup.visible) {
                                        mediaPopup.visible = false;
                                    } else {
                                        startMenu.visible = false;
                                        mediaPopup.visible = true;
                                    }
                                }
                                else if (mouse.button === Qt.RightButton) { if (root.activePlayer.canGoNext) root.activePlayer.next(); }
                                else if (mouse.button === Qt.MiddleButton) { if (root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying(); }
                            }
                            onWheel: (wheel) => {
                                if (!root.activePlayer) return;
                                if (wheel.angleDelta.y > 0) {
                                    if (root.activePlayer.canGoNext) root.activePlayer.next();
                                } else {
                                    if (root.activePlayer.canGoPrevious) root.activePlayer.previous();
                                }
                            }
                        }
                    }

                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            id: trayItem
                            required property SystemTrayItem modelData
                            width: Math.max(26, trayLabel.implicitWidth + 10)
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                color: hoverArea.containsMouse ? "#1c6ed4" : "transparent"
                                radius: 2
                            }

                            Text {
                                id: trayLabel
                                anchors.centerIn: parent
                                text: {
                                    let name = modelData.title || modelData.id || "App";
                                    return name.substring(0, 4).toUpperCase();
                                }
                                color: "white"; font.pixelSize: 10; font.bold: true; font.family: "Tahoma"
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                                onClicked: (mouse) => {
                                    startMenu.visible = false;
                                    mediaPopup.visible = false;

                                    let pos = trayItem.mapToItem(panel.contentItem, 0, trayItem.height)
                                    if (mouse.button === Qt.LeftButton) {
                                        if (modelData.onlyMenu) modelData.display(panel, pos.x, pos.y)
                                        else modelData.activate()
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate()
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu) modelData.display(panel, pos.x, pos.y)
                                        else modelData.secondaryActivate()
                                    }
                                }
                                onWheel: (wheel) => {
                                    modelData.scroll(wheel.angleDelta.y, Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: mediaPopup
        anchor.window: panel
        anchor.rect.x: panel.width - mediaPopup.implicitWidth - 4
        anchor.rect.y: -mediaPopup.implicitHeight - 2
        implicitWidth: 320; implicitHeight: 220
        visible: false
        grabFocus: true 
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#ece9d8"
            border.color: "#0a246a"
            border.width: 3
            radius: 4
            focus: true
            Keys.onEscapePressed: (event) => { mediaPopup.visible = false; event.accepted = true; }

            Rectangle {
                id: mpTitleBar
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 24
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#0a246a" }
                    GradientStop { position: 1.0; color: "#a6caf0" }
                }
                topLeftRadius: 4; topRightRadius: 4

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Media Player"
                    color: "white"; font.bold: true; font.family: "Tahoma"; font.pixelSize: 11
                }

                Rectangle {
                    width: 16; height: 14
                    anchors.right: parent.right; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: mpCloseHover.containsMouse ? "#e81123" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"; color: "white"; font.bold: true; font.pixelSize: 10
                    }
                    MouseArea {
                        id: mpCloseHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: mediaPopup.visible = false
                    }
                }
            }

            Column {
                anchors.top: mpTitleBar.bottom; anchors.topMargin: 8
                anchors.left: parent.left; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 8
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: 64; height: 64
                        color: "#d4d0c8"; border.color: "#808080"
                        Image {
                            anchors.fill: parent
                            source: root.activePlayer?.trackArtUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: source != ""
                        }
                        Text { anchors.centerIn: parent; text: "♪"; font.pixelSize: 24; color: "#555555"; visible: root.activePlayer?.trackArtUrl === "" }
                    }
                    Column {
                        width: parent.width - 74; spacing: 4
                        Text { text: root.activePlayer?.trackTitle || "No title"; font.pixelSize: 12; font.bold: true; font.family: "Tahoma"; color: "#000000"; elide: Text.ElideRight; width: parent.width }
                        Text { text: root.activePlayer?.trackArtist || "Unknown artist"; font.pixelSize: 10; font.family: "Tahoma"; color: "#333333"; elide: Text.ElideRight; width: parent.width }
                        Text { text: root.activePlayer?.identity || "MPRIS Player"; font.pixelSize: 9; font.family: "Tahoma"; color: "#666666" }
                    }
                }

                Item {
                    id: seekBarItem
                    width: parent.width; height: 16

                    Rectangle {
                        id: seekTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 12
                        color: "#ffffff"; border.color: "#808080"

                        Rectangle {
                            id: seekFill
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: {
                                if (root.isSeeking) return Math.max(0, Math.min(seekTrack.width, root.seekPreview));
                                let len = root.activePlayer?.length || 0;
                                let pos = root.mediaPosition;
                                if (len <= 0) return 0;
                                return Math.max(0, Math.min(1, pos / len)) * seekTrack.width;
                            }
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4caf50" }
                                GradientStop { position: 1.0; color: "#2e7d32" }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onPressed: (mouse) => {
                                root.isSeeking = true;
                                root.seekPreview = Math.max(0, Math.min(width, mouse.x));
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    root.seekPreview = Math.max(0, Math.min(width, mouse.x));
                                }
                            }
                            onReleased: (mouse) => {
                                root.isSeeking = false;
                                if (!root.activePlayer || !root.activePlayer.canSeek) return;
                                let len = root.activePlayer.length;
                                if (len <= 0) return;
                                let ratio = Math.max(0, Math.min(1, mouse.x / width));
                                let targetPos = ratio * len;
                                let offset = targetPos - root.activePlayer.position;
                                root.activePlayer.seek(offset);
                                root.mediaPosition = targetPos;
                            }
                        }
                    }
                    Row {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.bottom
                        Text { text: root.formatTime(root.isSeeking ? (root.seekPreview / seekTrack.width) * (root.activePlayer?.length || 0) : root.mediaPosition); font.pixelSize: 9; font.family: "Tahoma"; color: "#333333" }
                        Item { width: parent.width - 50; height: 1 }
                        Text { text: root.activePlayer ? root.formatTime(root.activePlayer.length || 0) : "0:00"; font.pixelSize: 9; font.family: "Tahoma"; color: "#333333" }
                    }
                }

                Row {
                    width: parent.width
                    height: 20
                    spacing: 6
                    visible: root.activePlayer !== null

                    Rectangle {
                        width: 20; height: 16
                        color: muteHover.containsMouse ? "#d0e0f0" : "transparent"
                        border.color: muteHover.containsMouse ? "#a0b0c0" : "transparent"
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            fillMode: Image.PreserveAspectFit
                            source: Quickshell.iconPath(
                                (!root.activePlayer || root.activePlayer.volume <= 0) ? "audio-volume-muted" :
                                root.activePlayer.volume < 0.33 ? "audio-volume-low" :
                                root.activePlayer.volume < 0.66 ? "audio-volume-medium" :
                                "audio-volume-high"
                            )
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    source = Quickshell.iconPath("audio-volume-medium");
                                }
                            }
                        }

                        MouseArea {
                            id: muteHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.activePlayer) {
                                    if (root.activePlayer.volume > 0) {
                                        root.lastPlayerVolume = root.activePlayer.volume;
                                        root.activePlayer.volume = 0;
                                    } else {
                                        root.activePlayer.volume = root.lastPlayerVolume > 0 ? root.lastPlayerVolume : 1.0;
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width - 26
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: volTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 6
                            color: "#ffffff"; border.color: "#808080"

                            Rectangle {
                                id: volFill
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: {
                                    if (!root.activePlayer) return 0;
                                    let v = root.activePlayer.volume;
                                    return Math.min(1, Math.max(0, v)) * parent.width;
                                }
                                color: "#387838"
                            }

                            Rectangle {
                                width: 8; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                x: volFill.width - (width / 2)
                                color: "#ece9d8"
                                border.color: "#808080"
                                radius: 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => updateVol(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x) }
                                function updateVol(x) {
                                    if (root.activePlayer) {
                                        root.activePlayer.volume = Math.max(0, Math.min(1, x / width));
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8; topPadding: 4

                    Rectangle {
                        width: 26; height: 26
                        color: prevHover.containsMouse ? "#d0e0f0" : "transparent"
                        radius: 3
                        border.color: prevHover.containsMouse ? "#a0b0c0" : "transparent"
                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 16; color: "#000000" }
                        MouseArea {
                            id: prevHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (root.activePlayer?.canGoPrevious) root.activePlayer.previous(); }
                        }
                    }

                    Rectangle {
                        width: 26; height: 26
                        color: playHover.containsMouse ? "#d0e0f0" : "transparent"
                        radius: 3
                        border.color: playHover.containsMouse ? "#a0b0c0" : "transparent"
                        Text { anchors.centerIn: parent; text: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"; font.pixelSize: 16; color: "#000000" }
                        MouseArea {
                            id: playHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (root.activePlayer?.canTogglePlaying) root.activePlayer.togglePlaying(); }
                        }
                    }

                    Rectangle {
                        width: 26; height: 26
                        color: nextHover.containsMouse ? "#d0e0f0" : "transparent"
                        radius: 3
                        border.color: nextHover.containsMouse ? "#a0b0c0" : "transparent"
                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 16; color: "#000000" }
                        MouseArea {
                            id: nextHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (root.activePlayer?.canGoNext) root.activePlayer.next(); }
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: startMenu
        anchor.window: panel
        anchor.rect.x: startButton.x
        anchor.rect.y: -startMenu.implicitHeight - 2
        implicitWidth: 380; implicitHeight: 480
        visible: false
        grabFocus: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#ffffff"
            border.color: "#0a246a"
            border.width: 2
            radius: 4
            focus: true
            Keys.onEscapePressed: (event) => { startMenu.visible = false; event.accepted = true; }

            Rectangle {
                id: header
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                height: 60
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#0058ee" }
                    GradientStop { position: 1.0; color: "#3a93ff" }
                }
                topLeftRadius: 4; topRightRadius: 4
                border.color: "#0a246a"; border.width: 1

                Row {
                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                    Rectangle {
                        width: 48; height: 48; radius: 4; color: "#a0a0a0"; border.color: "white"; border.width: 2
                        Image { anchors.fill: parent; source: "file:///home/archi/.config/quickshell/avatar.png"; fillMode: Image.PreserveAspectCrop }
                    }
                    Text {
                        text: "archi"; color: "white"; font.bold: true; font.pixelSize: 18; font.family: "Tahoma"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row {
                anchors.top: header.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.margins: 2

                Rectangle {
                    width: parent.width * 0.55
                    height: parent.height
                    color: "#ffffff"
                    
                    Column {
                        anchors.fill: parent; anchors.margins: 4; spacing: 4
                        
                        Rectangle {
                            width: parent.width; height: 24; color: "white"; border.color: "#808080"
                            
                            Text {
                                anchors.fill: parent; anchors.leftMargin: 4
                                text: "Search programs..."
                                color: "#808080"; font.pixelSize: 11; font.family: "Tahoma"
                                visible: searchInput.text === ""
                                verticalAlignment: Text.AlignVCenter
                                z: -1
                            }
                            
                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                font.pixelSize: 11; font.family: "Tahoma"; color: "black"; clip: true; focus: true; selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                z: 1

                                onTextChanged: {
                                    appList.currentIndex = 0;
                                    appList.positionViewAtBeginning();
                                }

                                Keys.onDownPressed: (event) => {
                                    if (appList.currentIndex < appList.count - 1) {
                                        appList.currentIndex++;
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                }
                                Keys.onUpPressed: (event) => {
                                    if (appList.currentIndex > 0) {
                                        appList.currentIndex--;
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                }
                                Keys.onReturnPressed: (event) => {
                                    if (appList.currentIndex >= 0 && appList.currentIndex < appList.count) {
                                        let item = appList.itemAtIndex(appList.currentIndex);
                                        if (item && item.modelData) {
                                            item.modelData.execute();
                                            startMenu.visible = false;
                                            searchInput.text = "";
                                        }
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        ListView {
                            id: appList
                            width: parent.width; height: parent.height - 28
                            clip: true; spacing: 0
                            currentIndex: 0
                            
                            model: ScriptModel {
                                values: DesktopEntries.applications.values.filter(app => {
                                    return searchInput.text === "" || app.name.toLowerCase().includes(searchInput.text.toLowerCase());
                                })
                            }

                            delegate: Rectangle {
                                required property DesktopEntry modelData
                                required property int index
                                width: appList.width
                                height: 28
                                color: appList.currentIndex === index ? "#316ac5" : "transparent"

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 4; spacing: 6
                                    Image { source: Quickshell.iconPath(modelData.icon, "application-x-executable"); width: 20; height: 20; fillMode: Image.PreserveAspectFit; smooth: true }
                                    Text { 
                                        text: modelData.name; 
                                        color: appList.currentIndex === index ? "white" : "black"; 
                                        font.pixelSize: 11; font.family: "Tahoma"; 
                                        anchors.verticalCenter: parent.verticalCenter 
                                    }
                                }
                                
                                MouseArea {
                                    id: mouseArea; 
                                    anchors.fill: parent; 
                                    hoverEnabled: true
                                    onEntered: { appList.currentIndex = index; }
                                    onClicked: {
                                        modelData.execute();
                                        startMenu.visible = false;
                                        searchInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width * 0.45
                    height: parent.height
                    color: "#d3e5fa"
                    border.color: "#a6caf0"; border.width: 1

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: root.customFolders
                        spacing: 2

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width; height: 22
                            color: folderHover.containsMouse ? "#316ac5" : "transparent"

                            Text {
                                anchors.fill: parent; anchors.leftMargin: 4
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.name
                                font.pixelSize: 11; font.family: "Tahoma"
                                color: folderHover.containsMouse ? "white" : "#0a246a"
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: folderHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    Quickshell.execDetached(["thunar", modelData.path]);
                                    startMenu.visible = false;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: footer
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                height: 40
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#e88a29" }
                    GradientStop { position: 1.0; color: "#d26800" }
                }
                bottomLeftRadius: 4; bottomRightRadius: 4
                border.color: "#b05a00"; border.width: 1

                Row {
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    spacing: 15
                    
                    Rectangle {
                        width: logOffText.implicitWidth + 12; height: 22
                        color: logOffHover.containsMouse ? "#ffaa44" : "transparent"
                        radius: 3
                        Text { id: logOffText; anchors.centerIn: parent; text: "Log Off"; color: "white"; font.bold: true; font.pixelSize: 11; font.family: "Tahoma" }
                        MouseArea { id: logOffHover; anchors.fill: parent; hoverEnabled: true; onClicked: { Quickshell.execDetached(["labwc", "--exit"]); startMenu.visible = false; } } 
                    }
                    
                    Rectangle {
                        width: turnOffText.implicitWidth + 12; height: 22
                        color: turnOffHover.containsMouse ? "#ffaa44" : "transparent"
                        radius: 3
                        Text { id: turnOffText; anchors.centerIn: parent; text: "Turn Off Computer"; color: "white"; font.bold: true; font.pixelSize: 11; font.family: "Tahoma" }
                        MouseArea { 
                            id: turnOffHover; 
                            anchors.fill: parent; 
                            hoverEnabled: true; 
                            onClicked: { 
                                Quickshell.execDetached(["loginctl", "poweroff"]); 
                                startMenu.visible = false; 
                            } 
                        } 
                    }
                }
            }
        }
    }
}