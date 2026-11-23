/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 曲库视图（左侧二级分类 + 歌曲列表）
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import DBScore.Project

FocusScope {
    id: root

    property color backgroundColor: ui.theme.backgroundSecondaryColor

    property string searchText: ""
    property string selectedStyle: ""
    property int selectedLevel: -1
    property var filteredSongs: []
    property var lastPracticeModel: null
    property var playlistModel: null
    property var selectedSong: null
    property string prepareError: ""
    property SongModel songModel: null
    property int instrument: 0
    property int libraryMode: 0 // 0级别 1热搜 2时值 3风格 4考级 5日更 6AI
    property string instrumentName: ""

    signal playerRequested()

    // 二级分类栏尺寸令牌
    readonly property real railWidth: 196
    readonly property real railHeaderHeight: 30
    readonly property real railItemHeight: 32
    readonly property real railItemRadius: 7

    readonly property var styleOptions: [qsTrc("project", "流行"), qsTrc("project", "专业"),
                                          qsTrc("project", "演出比赛")]
    readonly property var gradeOptions: root.songModel ? root.songModel.levelNames : []
    readonly property var timeValueOptions: [qsTrc("project", "四分"), qsTrc("project", "八分"),
                                             qsTrc("project", "四+八"), qsTrc("project", "三连音"),
                                             qsTrc("project", "十六分"), qsTrc("project", "八+十六"),
                                             qsTrc("project", "前十六后八"), qsTrc("project", "前十六后八+十六"),
                                             qsTrc("project", "前八后十六"), qsTrc("project", "前八后十六+十六"),
                                             qsTrc("project", "前十六后八+前八后十六"), qsTrc("project", "切分音"),
                                             qsTrc("project", "十六分+切分"), qsTrc("project", "前十六后八+切分"),
                                             qsTrc("project", "前八后十六+切分"), qsTrc("project", "附点"),
                                             qsTrc("project", "十六分+附点"), qsTrc("project", "前十六后八+附点"),
                                             qsTrc("project", "前八后十六+附点"), qsTrc("project", "切分音+附点")]

    readonly property var examSystemOptions: [qsTrc("project", "国音"), qsTrc("project", "上打"),
                                              qsTrc("project", "RSL"), qsTrc("project", "川音"),
                                              qsTrc("project", "迷笛")]

    // ── 二级分类数据 ────────────────────────────────
    function railTitle() {
        switch (root.libraryMode) {
        case 0: return qsTrc("project", "级别")
        case 2: return qsTrc("project", "时值")
        case 3: return qsTrc("project", "风格")
        case 4: return qsTrc("project", "考级体系")
        default: return ""
        }
    }

    function railItems() {
        switch (root.libraryMode) {
        case 0: return [qsTrc("project", "全部级别")].concat(root.gradeOptions)
        case 2: return [qsTrc("project", "全部")].concat(root.timeValueOptions)
        case 3: return [qsTrc("project", "全部")].concat(root.styleOptions)
        case 4: return [qsTrc("project", "全部")].concat(root.examSystemOptions)
        default: return []
        }
    }

    function optionIndex(options, value) {
        if (value === "") {
            return 0
        }
        for (let i = 0; i < options.length; ++i) {
            if (options[i] === value) {
                return i + 1
            }
        }
        return 0
    }

    function railSelectedIndex() {
        switch (root.libraryMode) {
        case 0: return root.selectedLevel + 1
        case 2: return root.optionIndex(root.timeValueOptions, root.selectedStyle)
        case 3: return root.optionIndex(root.styleOptions, root.selectedStyle)
        case 4: return root.optionIndex(root.examSystemOptions, root.selectedStyle)
        default: return 0
        }
    }

    function selectRailItem(index) {
        if (root.libraryMode === 0) {
            root.selectedLevel = index - 1
            return
        }

        let options = null
        if (root.libraryMode === 2) {
            options = root.timeValueOptions
        } else if (root.libraryMode === 3) {
            options = root.styleOptions
        } else if (root.libraryMode === 4) {
            options = root.examSystemOptions
        }

        if (!options) {
            return
        }

        root.selectedStyle = index === 0 ? "" : options[index - 1]
    }

    function instrumentHasSongs() {
        if (!root.songModel) {
            return false
        }
        for (let i = 0; i < songModel.songs.length; ++i) {
            if (songModel.songs[i].instrument === root.instrument) {
                return true
            }
        }
        return false
    }

    function hasFilterRail() {
        return root.libraryMode === 0 || root.libraryMode === 2
                || root.libraryMode === 3 || root.libraryMode === 4
    }

    function levelNameForSong(song) {
        return song.level >= 0 && song.level < root.gradeOptions.length
                ? root.gradeOptions[song.level]
                : qsTrc("project", "未分级")
    }

    function songIsInCollection(song, collection) {
        return (song.collections || []).indexOf(collection) >= 0
    }

    function activeCollection() {
        switch (root.libraryMode) {
        case 1: return "hot"
        case 5: return "daily"
        case 6: return "ai"
        default: return ""
        }
    }

    function refreshFilteredSongs() {
        const result = []

        if (!root.songModel) {
            root.filteredSongs = result
            return
        }

        const query = root.searchText.toLowerCase()

        for (let i = 0; i < songModel.songs.length; ++i) {
            const song = songModel.songs[i]

            const matchInstrument = song.instrument === root.instrument
            const matchText = query === ""
                              || song.title.toLowerCase().indexOf(query) >= 0
                              || song.style.toLowerCase().indexOf(query) >= 0
            const matchStyle = root.libraryMode !== 3
                               || root.selectedStyle === ""
                               || song.style === root.selectedStyle
            const matchLevel = root.libraryMode !== 0
                               || root.selectedLevel < 0
                               || song.level === root.selectedLevel
            const collection = root.activeCollection()
            const matchCollection = collection === ""
                                    || root.songIsInCollection(song, collection)

            if (matchInstrument && matchText && matchStyle && matchLevel && matchCollection) {
                result.push(song)
            }
        }

        root.filteredSongs = result
    }

    onSearchTextChanged: refreshFilteredSongs()
    onSelectedStyleChanged: refreshFilteredSongs()
    onSelectedLevelChanged: refreshFilteredSongs()
    onInstrumentChanged: refreshFilteredSongs()
    onLibraryModeChanged: {
        root.selectedSong = null
        root.selectedStyle = ""
        root.selectedLevel = -1
        refreshFilteredSongs()
    }

    function openSong(song) {
        if (!song) {
            return
        }
        root.prepareError = ""
        if (song.lessonId && root.songModel) {
            root.selectedSong = null
            root.songModel.prepareSong(song)
            return
        }
        root.selectedSong = song
    }

    Connections {
        target: songModel

        function onSongsChanged() {
            root.refreshFilteredSongs()
        }

        function onSongReady(song) {
            root.selectedSong = song
        }

        function onSongPrepareFailed(message) {
            root.prepareError = message
            prepareErrorTimer.restart()
        }
    }

    Timer {
        id: prepareErrorTimer
        interval: 5000
        onTriggered: root.prepareError = ""
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: root.selectedSong === null

        // ── 二级分类：左侧竖向目录 ──────────────────
        Item {
            visible: root.hasFilterRail()
            Layout.preferredWidth: root.hasFilterRail() ? root.railWidth : 0
            Layout.minimumWidth: root.hasFilterRail() ? root.railWidth : 0
            Layout.maximumWidth: root.hasFilterRail() ? root.railWidth : 0
            Layout.fillHeight: true

            // 与歌曲列表之间的细分隔线
            Rectangle {
                width: 1
                height: parent.height
                anchors.right: parent.right
                color: ui.theme.strokeColor
                opacity: 0.6
            }

            StyledTextLabel {
                id: railHeader

                width: parent.width
                height: root.railHeaderHeight
                text: root.railTitle()
                font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 11, letterSpacing: 1 }))
                color: ui.theme.fontPrimaryColor
                opacity: 0.55
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                leftPadding: 4
            }

            Flickable {
                id: railFlick

                anchors.top: railHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                clip: true
                contentWidth: width
                contentHeight: railColumn.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: railColumn

                    width: railFlick.width
                    spacing: 2

                    Repeater {
                        model: root.railItems()

                        Rectangle {
                            id: railItem

                            required property var modelData
                            required property int index

                            width: railColumn.width
                            height: root.railItemHeight
                            radius: root.railItemRadius
                            activeFocusOnTab: true
                            color: index === root.railSelectedIndex()
                                   ? ui.theme.accentColor
                                   : (railItemHover.containsMouse
                                      ? ui.theme.backgroundSecondaryColor
                                      : "transparent")
                            border.width: activeFocus ? 1 : 0
                            border.color: ui.theme.accentColor

                            Accessible.role: Accessible.Button
                            Accessible.name: modelData

                            StyledTextLabel {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                font: Qt.font(Object.assign({},
                                                            index === root.railSelectedIndex()
                                                            ? ui.theme.bodyBoldFont
                                                            : ui.theme.bodyFont,
                                                            { pixelSize: 12.5 }))
                                color: index === root.railSelectedIndex()
                                       ? "#FFFFFF"
                                       : ui.theme.fontPrimaryColor
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: railItemHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    railItem.forceActiveFocus()
                                    root.selectRailItem(index)
                                }
                            }

                            Keys.onReturnPressed: root.selectRailItem(index)
                            Keys.onEnterPressed: root.selectRailItem(index)
                            Keys.onSpacePressed: root.selectRailItem(index)
                        }
                    }
                }
            }
        }

        // ── 歌曲列表 ────────────────────────────────
        ScrollView {
            id: songScroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            clip: true

            ColumnLayout {
                width: songScroll.availableWidth
                spacing: 8

                StyledTextLabel {
                    visible: root.filteredSongs.length === 0
                    Layout.fillWidth: true
                    text: root.instrumentHasSongs()
                          ? qsTrc("project", "没有符合条件的歌曲，换个筛选试试")
                          : qsTrc("project", "「%1」曲库即将上线，敬请期待").arg(root.instrumentName)
                    font: ui.theme.bodyFont
                    horizontalAlignment: Text.AlignLeft
                    opacity: 0.55
                }

                Repeater {
                    model: root.filteredSongs

                    delegate: Rectangle {
                        id: songCard

                        required property var modelData

                        Layout.fillWidth: true
                        height: 56
                        radius: 10
                        activeFocusOnTab: true
                        color: ui.theme.backgroundPrimaryColor
                        border.width: 1
                        border.color: rowHover.hovered || activeFocus
                                      ? ui.theme.accentColor
                                      : ui.theme.strokeColor

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title

                        HoverHandler {
                            id: rowHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                songCard.forceActiveFocus()
                                root.openSong(modelData)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 12

                            StyledIconLabel {
                                iconCode: IconCode.OPEN_FILE
                                font.pixelSize: 18
                                color: ui.theme.accentColor
                            }

                            StyledTextLabel {
                                Layout.fillWidth: true
                                text: modelData.title
                                font: ui.theme.bodyBoldFont
                                horizontalAlignment: Text.AlignLeft
                                elide: Text.ElideRight
                            }

                            StyledTextLabel {
                                text: root.levelNameForSong(modelData)
                                font: ui.theme.bodyFont
                                color: ui.theme.fontPrimaryColor
                                opacity: 0.55
                            }

                            FlatButton {
                                visible: root.playlistModel !== null
                                         && Boolean(modelData.scorePath)
                                icon: IconCode.PLUS
                                isNarrow: true
                                transparent: true
                                toolTipTitle: qsTrc("project", "加入播放记录")
                                onClicked: {
                                    if (modelData.scorePath) {
                                        root.playlistModel.addFromUser(modelData.scorePath, modelData.title)
                                    }
                                }
                            }

                            StyledIconLabel {
                                iconCode: IconCode.CHEVRON_RIGHT
                                font.pixelSize: 14
                                opacity: 0.35
                            }
                        }

                        Keys.onReturnPressed: root.openSong(modelData)
                        Keys.onEnterPressed: root.openSong(modelData)
                        Keys.onSpacePressed: root.openSong(modelData)
                    }
                }
            }
        }
    }

    // ── 歌曲素材文件夹 ──────────────────────────────
    SongFolderView {
        anchors.fill: parent
        visible: root.selectedSong !== null
        song: root.selectedSong
        songModel: root.songModel
        lastPracticeModel: root.lastPracticeModel
        playlistModel: root.playlistModel
        instrument: root.instrument
        backLabel: qsTrc("project", "返回歌曲列表")
        onBackRequested: root.selectedSong = null
        onPlayerRequested: root.playerRequested()
    }

    Rectangle {
        anchors.fill: parent
        z: 20
        visible: root.songModel && root.songModel.preparing
        color: Qt.rgba(0, 0, 0, 0.28)

        Rectangle {
            width: 300
            height: 82
            anchors.centerIn: parent
            radius: 14
            color: ui.theme.backgroundPrimaryColor

            Row {
                anchors.centerIn: parent
                spacing: 12

                BusyIndicator {
                    running: parent.parent.parent.visible
                }

                StyledTextLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTrc("project", "正在准备课件…")
                    font: ui.theme.bodyBoldFont
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        z: 21
        visible: root.prepareError.length > 0
        width: Math.min(parent.width - 40, prepareErrorText.implicitWidth + 32)
        height: 42
        radius: 10
        color: "#B3261E"

        StyledTextLabel {
            id: prepareErrorText
            anchors.centerIn: parent
            text: root.prepareError
            color: "#FFFFFF"
            font: ui.theme.bodyFont
        }
    }
}
