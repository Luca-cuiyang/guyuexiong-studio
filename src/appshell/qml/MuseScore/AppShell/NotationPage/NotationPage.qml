/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 播放器页面（纯 QML，只内嵌乐谱渲染引擎）
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import Muse.Ui
import Muse.UiComponents
import DBScore.AppShell
import DBScore.NotationScene
import DBScore.Playback

FocusScope {
    id: root

    Accessible.role: Accessible.Pane
    Accessible.name: "DB player"

    required property PlaylistModel playlistModel
    property bool playlistVisible: false
    property bool topChromeVisible: true
    property bool bottomChromeVisible: true
    property bool windowAspectLocked: false
    property var playerWindow: null
    property real savedWindowWidth: 0
    property real savedWindowHeight: 0
    readonly property int playerChromeHeight: 60
    readonly property color playerChromeColor: Qt.tint(
        ui.theme.backgroundSecondaryColor,
        Utils.colorWithAlpha(ui.theme.accentColor, ui.theme.isDark ? 0.34 : 0.18))
    readonly property color playerChromeDividerColor:
        Utils.colorWithAlpha(ui.theme.accentColor, 0.62)
    readonly property color playerChromeTextColor: ui.theme.fontPrimaryColor
    readonly property bool chromeAutoHideAllowed: playbackToolBar.isPlaying && !playlistVisible

    focus: true

    property NotationPageModel pageModel: NotationPageModel {
        playerViewLocked: true
    }

    Timer {
        interval: 3000
        repeat: false
        running: root.chromeAutoHideAllowed
                 && root.topChromeVisible
                 && !topEdgeHover.hovered
        onTriggered: root.topChromeVisible = false
    }

    Timer {
        id: nativeWindowActivationTimer
        interval: 50
        repeat: false
        onTriggered: root.activateNativeWindow()
    }

    Timer {
        interval: 3000
        repeat: false
        running: root.chromeAutoHideAllowed
                 && root.bottomChromeVisible
                 && !bottomEdgeHover.hovered
        onTriggered: root.bottomChromeVisible = false
    }

    Connections {
        target: playbackToolBar

        function onIsPlayingChanged() {
            if (!playbackToolBar.isPlaying) {
                root.revealChrome()
            }
        }
    }

    Component.onCompleted: {
        if (root.visible) {
            Qt.callLater(root.enterPlayer)
        }
    }

    Component.onDestruction: {
        root.deactivatePlayerWindow()
    }

    onVisibleChanged: {
        if (root.visible) {
            playbackToolBar.resetTempo()
            playbackToolBar.enablePlayRepeats()
            Qt.callLater(root.enterPlayer)
        } else {
            root.deactivatePlayerWindow()
        }
    }

    Connections {
        target: root.pageModel

        function onNotationReady() {
            if (root.visible) {
                nativeWindowActivationTimer.restart()
                Qt.callLater(root.focusPlayer)
            }
        }
    }

    function enterPlayer() {
        root.activatePlayerWindow()
        root.focusPlayer()
    }

    function activateNativeWindow() {
        if (!root.visible || !root.playerWindow) {
            return
        }

        if (root.playerWindow.windowBridge) {
            root.playerWindow.windowBridge.activate()
        }
        Qt.callLater(root.focusPlayer)
    }

    function focusPlayer() {
        if (!root.visible) {
            return
        }

        root.forceActiveFocus()
        if (mainNotationView && mainNotationView.paintView) {
            mainNotationView.defaultNavigationControl.requestActive()
            mainNotationView.paintView.forceFocusIn()
        }
    }

    function activatePlayerWindow() {
        root.playerWindow = Window.window
        if (!root.playerWindow) {
            return
        }

        root.playerWindow.playerMode = true
        // Changing window flags recreates the native window on macOS, which
        // drops its key-window state. Re-activate it after the native change.
        nativeWindowActivationTimer.restart()
        if (root.windowAspectLocked
                || root.playerWindow.visibility === Window.FullScreen
                || root.playerWindow.visibility === Window.Maximized) {
            return
        }

        root.savedWindowWidth = root.playerWindow.width
        root.savedWindowHeight = root.playerWindow.height
        root.windowAspectLocked = true
        root.syncWindowAspectRatio(true)
    }

    function deactivatePlayerWindow() {
        const playerWindow = root.playerWindow || Window.window
        if (!playerWindow) {
            return
        }

        playerWindow.playerMode = false
        if (!root.windowAspectLocked) {
            return
        }

        root.windowAspectLocked = false
        if (playerWindow.visibility === Window.FullScreen) {
            playerWindow.showNormal()
        }
        playerWindow.width = root.savedWindowWidth
        playerWindow.height = root.savedWindowHeight
    }

    function syncWindowAspectRatio(force) {
        if (!root.playerWindow || !root.windowAspectLocked
                || root.playerWindow.visibility === Window.FullScreen
                || root.playerWindow.visibility === Window.Maximized) {
            return
        }

        const targetHeight = Math.round(root.playerWindow.width * 9.0 / 16.0)
        if (force || Math.abs(root.playerWindow.height - targetHeight) > 1) {
            root.playerWindow.height = targetHeight
        }
    }

    onPlaylistVisibleChanged: {
        if (playlistVisible) {
            root.revealChrome()
        }
    }

    function revealChrome() {
        topChromeVisible = true
        bottomChromeVisible = true
    }

    Connections {
        target: root.playerWindow

        function onWidthChanged() {
            Qt.callLater(root.syncWindowAspectRatio, false)
        }

        function onVisibilityChanged() {
            root.syncWindowAspectRatio(false)
            root.revealChrome()
            nativeWindowActivationTimer.restart()
            Qt.callLater(function() {
                mainNotationView.paintView.synchronizePlaybackCursor()
            })
        }
    }

    Item {
        anchors.fill: parent

        // 顶部功能区
        Rectangle {
            id: topChrome

            property real visibilityOffset: root.topChromeVisible ? 0 : -height

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.playerChromeHeight
            z: 100
            enabled: root.topChromeVisible
            color: root.playerChromeColor
            transform: Translate { y: topChrome.visibilityOffset }

            Behavior on visibilityOffset {
                NumberAnimation {
                    duration: ui.isEffectsAllowed ? 220 : 0
                    easing.type: Easing.InOutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton && root.playerWindow
                            && root.playerWindow.visibility !== Window.FullScreen) {
                        root.playerWindow.startSystemMove()
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.playerChromeDividerColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 20
                spacing: 10

                FlatButton {
                    icon: IconCode.CHEVRON_LEFT
                    transparent: true
                    iconColor: root.playerChromeTextColor
                    toolTipTitle: qsTrc("appshell", "返回")
                    onClicked: root.pageModel.goBack()
                }

                StyledTextLabel {
                    text: "DB player"
                    font: ui.theme.bodyBoldFont
                    color: root.playerChromeTextColor
                }

                Item {
                    Layout.fillWidth: true
                }

                FlatButton {
                    icon: IconCode.LIST
                    text: qsTrc("appshell", "播放记录")
                    accentButton: root.playlistVisible
                    transparent: !root.playlistVisible
                    toolTipTitle: qsTrc("appshell", "显示或收起播放记录（%1 条）")
                                  .arg(root.playlistModel.count)
                    onClicked: root.playlistVisible = !root.playlistVisible
                }

            }
        }

        // 播放器视频区域固定为 16:9，谱面按原生矢量分辨率清晰绘制。
        Rectangle {
            anchors.fill: parent
            z: 0
            clip: true
            color: "#000000"

            NotationView {
                id: mainNotationView
                anchors.fill: parent

                name: "MainNotationView"
                isNavigatorVisible: false
                isBraillePanelVisible: false
                isMainView: true
                showScoreTabPanel: false
                readOnly: true
                followPlaybackCursorVertically: true
                zoomLocked: true
                userPanLocked: true
                Accessible.role: Accessible.Pane
                Accessible.name: qsTrc("appshell", "乐谱")
            }

            PlaylistPanel {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 320
                z: 90
                visible: root.playlistVisible
                playlistModel: root.playlistModel
                backgroundColor: ui.theme.backgroundSecondaryColor
            }
        }

        // 底部功能区
        Rectangle {
            id: bottomChrome

            property real visibilityOffset: root.bottomChromeVisible ? 0 : height

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.playerChromeHeight
            z: 100
            enabled: root.bottomChromeVisible
            color: root.playerChromeColor
            transform: Translate { y: bottomChrome.visibilityOffset }

            Behavior on visibilityOffset {
                NumberAnimation {
                    duration: ui.isEffectsAllowed ? 220 : 0
                    easing.type: Easing.InOutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: root.playerChromeDividerColor
            }

            PlaybackToolBar {
                id: playbackToolBar

                x: 16
                y: 5
                width: parent.width - 32
                height: parent.height - 10
                availableWidth: width
                expanded: true
                floating: false
            }
        }
    }

    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.topChromeVisible ? root.playerChromeHeight : 20
        z: 110

        HoverHandler {
            id: topEdgeHover

            onHoveredChanged: {
                if (hovered && !root.topChromeVisible) {
                    root.topChromeVisible = true
                }
            }
        }
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.bottomChromeVisible ? root.playerChromeHeight : 20
        z: 110

        HoverHandler {
            id: bottomEdgeHover

            onHoveredChanged: {
                if (hovered && !root.bottomChromeVisible) {
                    root.bottomChromeVisible = true
                }
            }
        }
    }

}
