/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 歌曲素材文件夹（统一磁贴平铺）
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import Muse.Ui
import Muse.UiComponents
import DBScore.Project

FocusScope {
    id: root

    property var song: null
    property var songModel: null
    property var courseModel: null
    property var lastPracticeModel: null
    property var playlistModel: null
    property int instrument: 0
    property string backLabel: qsTrc("project", "返回曲库中心")

    property var files: []
    property string previewPath: ""
    property string previewUrl: ""

    property string mediaPath: ""
    property string mediaUrl: ""
    property string mediaKind: ""

    property string pdfPath: ""
    property string pdfUrl: ""

    signal backRequested()
    signal playerRequested()

    readonly property string folder: root.song ? (root.song.folder || "") : ""

    // 磁贴尺寸令牌
    readonly property real tileWidth: 196
    readonly property real tileHeight: 184
    readonly property real tileSpacing: 16
    readonly property real tilePreviewHeight: 100

    function kindLabel(kind) {
        switch (kind) {
        case "score": return qsTrc("project", "鼓谱")
        case "image": return qsTrc("project", "图片")
        case "audio": return qsTrc("project", "音频")
        case "video": return qsTrc("project", "视频")
        case "document": return qsTrc("project", "文档")
        case "slides": return qsTrc("project", "课件")
        default: return qsTrc("project", "文件")
        }
    }

    function kindIcon(kind) {
        switch (kind) {
        case "score": return IconCode.MUSIC_NOTES
        case "image": return IconCode.IMAGE_MOUNTAINS
        case "audio": return IconCode.PLAY
        case "video": return IconCode.VIDEO
        default: return IconCode.OPEN_FILE
        }
    }

    function kindColor(kind) {
        switch (kind) {
        case "score": return ui.theme.accentColor
        case "image": return "#27AE60"
        case "audio": return "#2D9CDB"
        case "video": return "#9B51E0"
        case "document": return "#F2994A"
        case "slides": return "#EB5757"
        default: return "#7F8C8D"
        }
    }

    function formatSize(bytes) {
        if (bytes >= 1024 * 1024 * 1024) {
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + qsTrc("project", " 吉字节")
        }
        if (bytes >= 1024 * 1024) {
            return (bytes / (1024 * 1024)).toFixed(1) + qsTrc("project", " 兆字节")
        }
        if (bytes >= 1024) {
            return Math.round(bytes / 1024) + qsTrc("project", " 千字节")
        }
        return bytes + qsTrc("project", " 字节")
    }

    function formatTime(ms) {
        if (!ms || ms < 0) {
            return "0:00"
        }
        const total = Math.floor(ms / 1000)
        const minutes = Math.floor(total / 60)
        const seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" + seconds : seconds)
    }

    function mediaName() {
        if (!root.mediaPath) {
            return ""
        }
        const slash = root.mediaPath.lastIndexOf("/")
        return slash >= 0 ? root.mediaPath.substring(slash + 1) : root.mediaPath
    }

    function closeMedia() {
        root.mediaPath = ""
        root.mediaUrl = ""
        root.mediaKind = ""
    }

    function baseNameOf(path) {
        if (!path) {
            return ""
        }
        const slash = path.lastIndexOf("/")
        let name = slash >= 0 ? path.substring(slash + 1) : path
        const dot = name.lastIndexOf(".")
        if (dot > 0) {
            name = name.substring(0, dot)
        }
        return name
    }

    function instrumentIcon() {
        switch (root.instrument) {
        case 1: return IconCode.PERCUSSION
        case 2: return IconCode.MUSIC_NOTES
        case 3: return IconCode.MUSIC_NOTES
        case 4: return IconCode.MICROPHONE
        default: return IconCode.PERCUSSION
        }
    }

    function metaText() {
        const parts = []
        if (root.song && root.song.style) {
            parts.push(root.song.style)
        }
        parts.push(qsTrc("project", "%1 个素材").arg(root.allItems().length))
        return parts.join(qsTrc("project", " · "))
    }

    function reloadFiles() {
        if (!root.songModel || !root.song) {
            root.files = []
            return
        }
        root.files = root.songModel.listFiles(root.folder)
    }

    onFolderChanged: reloadFiles()

    Component.onCompleted: reloadFiles()

    Connections {
        target: root.songModel

        function onContentChanged(folder) {
            if (folder === root.folder) {
                root.reloadFiles()
            }
        }
    }

    Connections {
        target: root.courseModel

        function onContentChanged(folder) {
            if (folder === root.folder) {
                root.reloadFiles()
            }
        }
    }

    function allItems() {
        const result = []
        const scorePath = root.song ? (root.song.scorePath || "") : ""
        if (scorePath.length > 0) {
            result.push({
                            "kind": "score",
                            "name": root.song.scoreName || qsTrc("project", "鼓谱"),
                            "subtitle": qsTrc("project", "鼓谱 · %1").arg(root.baseNameOf(scorePath)),
                            "path": scorePath,
                            "url": "",
                            "size": 0
                        })
        }

        for (let i = 0; i < root.files.length; ++i) {
            const file = root.files[i]
            // Each .db is its own song. Never expose sibling score files as
            // another version of the currently opened song.
            if (file.type === "score") {
                continue
            }
            result.push({
                            "kind": file.type,
                            "name": file.baseName,
                            "subtitle": file.suffix.toUpperCase() + " · " + root.formatSize(file.size),
                            "path": file.path,
                            "url": file.url,
                            "suffix": file.suffix,
                            "size": file.size
                        })
        }

        return result
    }

    function activateItem(item) {
        if (!item) {
            return
        }

        root.previewPath = ""
        root.previewUrl = ""
        root.closeMedia()
        root.pdfPath = ""
        root.pdfUrl = ""

        if (item.kind === "score") {
            if (!item.path) {
                return
            }
            const title = root.song ? root.song.title : ""
            if (root.songModel && root.songModel.openScore(item.path, title)) {
                if (root.lastPracticeModel) {
                    root.lastPracticeModel.record(title, item.path, root.instrument)
                }
                if (root.playlistModel) {
                    root.playlistModel.add(item.path, title)
                    root.playlistModel.setCurrentPath(item.path)
                }
                // Reopening the same project does not emit a new page-open event.
                // Notify the shell explicitly so the player is shown every time.
                root.playerRequested()
            }
            return
        }

        if (item.kind === "image") {
            root.previewPath = item.path
            root.previewUrl = item.url
            return
        }

        if (item.kind === "audio" || item.kind === "video") {
            root.mediaPath = item.path
            root.mediaUrl = item.url
            root.mediaKind = item.kind
            return
        }

        if (item.kind === "document" && item.suffix === "pdf") {
            if (Qt.platform.os === "windows") {
                if (root.songModel) {
                    root.songModel.openFileExternally(item.path)
                }
            } else {
                root.pdfPath = item.path
                root.pdfUrl = item.url
            }
            return
        }

        if (root.songModel) {
            root.songModel.openFileExternally(item.path)
        }
    }

    function importFiles() {
        if (!root.songModel) {
            return
        }

        const target = root.folder.length > 0 ? root.folder : root.parentFolderOfScore()
        if (target.length === 0) {
            return
        }

        const count = root.songModel.importFilesToFolder(target)
        if (count > 0) {
            root.reloadFiles()
        }
    }

    function parentFolderOfScore() {
        if (root.folder.length > 0) {
            return root.folder
        }
        const path = root.song ? (root.song.scorePath || "") : ""
        if (path.length > 0) {
            const index = path.lastIndexOf("/")
            return index > 0 ? path.substring(0, index) : ""
        }
        return ""
    }

    // ── 顶部：返回 ────────────────────────────────────
    Item {
        id: breadcrumbBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 30

        FlatButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            isNarrow: true
            icon: IconCode.CHEVRON_LEFT
            text: root.backLabel
            transparent: true
            onClicked: root.backRequested()
        }
    }

    // ── 歌曲信息 ──────────────────────────────────────
    RowLayout {
        id: heroBlock

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: breadcrumbBar.bottom
        anchors.topMargin: 6
        height: 56
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            radius: 10
            color: root.song && root.song.coverColor ? root.song.coverColor : ui.theme.accentColor

            StyledIconLabel {
                anchors.centerIn: parent
                iconCode: root.instrumentIcon()
                font.pixelSize: 22
                color: "#FFFFFF"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            StyledTextLabel {
                Layout.fillWidth: true
                text: root.song ? root.song.title : ""
                font: Qt.font(Object.assign({}, ui.theme.headerBoldFont, { pixelSize: 22 }))
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
            }

            StyledTextLabel {
                Layout.fillWidth: true
                text: root.metaText()
                font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 12 }))
                color: ui.theme.fontPrimaryColor
                opacity: 0.55
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
            }
        }

        FlatButton {
            icon: IconCode.NEW_FILE
            text: qsTrc("project", "导入文件")
            accentButton: true
            isNarrow: true
            onClicked: root.importFiles()
        }
    }

    Rectangle {
        id: headerDivider

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heroBlock.bottom
        anchors.topMargin: 10
        height: 1
        color: ui.theme.strokeColor
        opacity: 0.5
    }

    // ── 素材磁贴 ──────────────────────────────────────
    ScrollView {
        id: folderScroll

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerDivider.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 12
        clip: true
        visible: root.allItems().length > 0

        Flow {
            width: folderScroll.availableWidth
            spacing: root.tileSpacing

            Repeater {
                model: root.allItems()

                Rectangle {
                    id: tile

                    required property var modelData

                    width: root.tileWidth
                    height: root.tileHeight
                    radius: 12
                    activeFocusOnTab: true
                    color: ui.theme.backgroundPrimaryColor
                    border.width: 1
                    border.color: tileHover.hovered || activeFocus
                                  ? ui.theme.accentColor
                                  : ui.theme.strokeColor

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name

                    HoverHandler {
                        id: tileHover
                    }

                    // 预览区
                    Rectangle {
                        id: preview

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        height: root.tilePreviewHeight
                        radius: 9
                        clip: true
                        color: modelData.kind === "image"
                               ? ui.theme.backgroundSecondaryColor
                               : Qt.rgba(root.kindColor(modelData.kind).r,
                                         root.kindColor(modelData.kind).g,
                                         root.kindColor(modelData.kind).b,
                                         0.09)

                        Image {
                            anchors.fill: parent
                            visible: modelData.kind === "image"
                            source: modelData.kind === "image" ? modelData.url : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: modelData.kind !== "image"
                            spacing: 6

                            StyledIconLabel {
                                Layout.alignment: Qt.AlignHCenter
                                iconCode: root.kindIcon(modelData.kind)
                                font.pixelSize: 34
                                color: root.kindColor(modelData.kind)
                            }

                            StyledTextLabel {
                                Layout.alignment: Qt.AlignHCenter
                                visible: modelData.kind !== "score"
                                text: root.kindLabel(modelData.kind)
                                font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 11 }))
                                color: root.kindColor(modelData.kind)
                                opacity: 0.85
                            }
                        }
                    }

                    // 标题
                    StyledTextLabel {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.top: preview.bottom
                        anchors.topMargin: 10
                        height: 20
                        text: modelData.name
                        font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont, { pixelSize: 13 }))
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    // 副标题
                    StyledTextLabel {
                        anchors.left: parent.left
                        anchors.right: modelData.kind === "score" ? actionChip.left : parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        height: 26
                        text: modelData.subtitle
                        font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 11 }))
                        color: ui.theme.fontPrimaryColor
                        opacity: 0.5
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    LibraryChip {
                        id: actionChip

                        visible: modelData.kind === "score"
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: qsTrc("project", "进入练习")
                        checked: true
                        chipHeight: 26
                        chipFont: Qt.font(Object.assign({}, ui.theme.bodyBoldFont, { pixelSize: 11 }))
                        onActivated: root.activateItem(modelData)
                    }

                    StyledIconLabel {
                        visible: modelData.kind !== "score"
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        iconCode: IconCode.CHEVRON_RIGHT
                        font.pixelSize: 12
                        opacity: 0.35
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            tile.forceActiveFocus()
                            root.activateItem(modelData)
                        }
                    }

                    Keys.onReturnPressed: root.activateItem(modelData)
                    Keys.onEnterPressed: root.activateItem(modelData)
                    Keys.onSpacePressed: root.activateItem(modelData)
                }
            }
        }
    }

    // ── 空状态 ────────────────────────────────────────
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerDivider.bottom
        anchors.topMargin: 24
        anchors.bottom: parent.bottom
        radius: 12
        color: ui.theme.backgroundPrimaryColor
        border.width: 1
        border.color: ui.theme.strokeColor
        visible: root.allItems().length === 0

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 520)
            spacing: 10

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("project", "这首歌还没有关联素材")
                font: ui.theme.headerBoldFont
                horizontalAlignment: Text.AlignHCenter
            }

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("project", "点击右上角「导入文件」，把图片、音频、视频、PDF 等素材加入这首歌。")
                font: ui.theme.bodyFont
                color: ui.theme.fontPrimaryColor
                opacity: 0.55
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            LibraryChip {
                Layout.alignment: Qt.AlignHCenter
                text: qsTrc("project", "导入文件")
                chipHeight: 34
                onActivated: root.importFiles()
            }
        }
    }

    // ── 音视频播放 ────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.mediaPath.length > 0
        color: "#0B0B0C"
        z: 110

        MediaPlayer {
            id: mediaPlayer

            source: root.mediaUrl
            videoOutput: videoOutput
            audioOutput: AudioOutput {
                volume: 0.85
            }

            onSourceChanged: {
                if (source.toString().length > 0) {
                    play()
                } else {
                    stop()
                }
            }
        }

        VideoOutput {
            id: videoOutput

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: mediaTopBar.bottom
            anchors.bottom: mediaControls.top
            visible: root.mediaKind === "video"
            fillMode: VideoOutput.PreserveAspectFit
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 140, 460)
            spacing: 16
            visible: root.mediaKind === "audio"

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 124
                Layout.preferredHeight: 124
                radius: 62
                color: "#1C1C1F"

                StyledIconLabel {
                    anchors.centerIn: parent
                    iconCode: IconCode.MUSIC_NOTES
                    font.pixelSize: 46
                    color: "#FFFFFF"
                }
            }

            StyledTextLabel {
                Layout.fillWidth: true
                text: root.mediaName()
                font: Qt.font(Object.assign({}, ui.theme.headerBoldFont, { pixelSize: 17 }))
                color: "#FFFFFF"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }
        }

        Item {
            id: mediaTopBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 50

            StyledTextLabel {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: mediaTopClose.left
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.mediaName()
                font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 13 }))
                color: "#FFFFFF"
                opacity: 0.75
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideMiddle
            }

            Rectangle {
                id: mediaTopClose

                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: mediaCloseHover.containsMouse ? "#2A2A2E" : "transparent"

                StyledIconLabel {
                    anchors.centerIn: parent
                    iconCode: IconCode.CLOSE_X_ROUNDED
                    font.pixelSize: 16
                    color: "#FFFFFF"
                    opacity: 0.8
                }

                MouseArea {
                    id: mediaCloseHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeMedia()
                }
            }
        }

        Rectangle {
            id: mediaControls

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 72
            color: "#141417"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: "#2A2A2E"

                    StyledIconLabel {
                        anchors.centerIn: parent
                        iconCode: mediaPlayer.playbackState === MediaPlayer.PlayingState
                                  ? IconCode.PAUSE
                                  : IconCode.PLAY
                        font.pixelSize: 15
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (mediaPlayer.playbackState === MediaPlayer.PlayingState) {
                                mediaPlayer.pause()
                            } else {
                                mediaPlayer.play()
                            }
                        }
                    }
                }

                StyledTextLabel {
                    Layout.preferredWidth: 42
                    text: root.formatTime(mediaPlayer.position)
                    font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 11 }))
                    color: "#FFFFFF"
                    opacity: 0.7
                    horizontalAlignment: Text.AlignRight
                }

                Slider {
                    id: positionSlider

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    from: 0
                    to: Math.max(1, mediaPlayer.duration)
                    onMoved: mediaPlayer.setPosition(value)

                    Binding on value {
                        when: !positionSlider.pressed
                        value: mediaPlayer.position
                    }
                }

                StyledTextLabel {
                    Layout.preferredWidth: 42
                    text: root.formatTime(mediaPlayer.duration)
                    font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 11 }))
                    color: "#FFFFFF"
                    opacity: 0.7
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    // PDF support is loaded only when requested. The official Windows Qt
    // runtime does not ship QtQuick.Pdf, so Windows uses the system reader
    // without preventing the main application from starting.
    Loader {
        id: pdfPreviewLoader

        anchors.fill: parent
        active: root.pdfPath.length > 0
        visible: active
        source: active ? "PdfPreviewOverlay.qml" : ""
        z: 120

        onLoaded: {
            item.pdfPath = Qt.binding(function() { return root.pdfPath })
            item.pdfUrl = Qt.binding(function() { return root.pdfUrl })
            item.closeRequested.connect(function() {
                root.pdfPath = ""
                root.pdfUrl = ""
            })
        }
    }

    // ── 图片高清预览 ──────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.previewPath.length > 0
        color: "#000000"
        opacity: visible ? 0.92 : 0
        z: 100

        Image {
            anchors.fill: parent
            anchors.leftMargin: 48
            anchors.rightMargin: 48
            anchors.topMargin: 64
            anchors.bottomMargin: 56
            source: root.previewUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        StyledTextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            text: qsTrc("project", "点击任意处关闭")
            font: ui.theme.bodyFont
            color: "#FFFFFF"
            opacity: 0.7
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.previewPath = ""
                root.previewUrl = ""
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: root.previewPath.length > 0
                 || root.mediaPath.length > 0
                 || root.pdfPath.length > 0
        onActivated: {
            root.previewPath = ""
            root.previewUrl = ""
            root.closeMedia()
            root.pdfPath = ""
            root.pdfUrl = ""
        }
    }
}
