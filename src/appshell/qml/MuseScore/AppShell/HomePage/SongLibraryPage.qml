/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 曲库中心（九宫格曲库 + 曲目列表）
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import DBScore.Project

FocusScope {
    id: root

    property var lastPracticeModel: null
    property var playlistModel: null
    property var courseModel: null
    property var songModel: null
    property int instrument: 0
    property int libraryMode: -1 // -1 曲库总览，0-6 具体曲库
    property string searchText: ""

    signal playerRequested()

    readonly property int categoryColumns: 3
    readonly property real categorySpacing: 16

    Component.onCompleted: {
        if (root.songModel) {
            root.songModel.load()
        }
    }

    readonly property var libraryTabs: [
        {
            "title": qsTrc("appshell", "级别曲库"),
            "subtitle": qsTrc("appshell", "预备级到比赛级"),
            "detail": qsTrc("appshell", "13 个级别"),
            "iconCode": IconCode.LEARN,
            "color": "#F57C00"
        },
        {
            "title": qsTrc("appshell", "热搜曲目"),
            "subtitle": qsTrc("appshell", "大家都在练"),
            "detail": qsTrc("appshell", "热门推荐"),
            "iconCode": IconCode.STAR,
            "color": "#E74C3C"
        },
        {
            "title": qsTrc("appshell", "时值曲库"),
            "subtitle": qsTrc("appshell", "四分、八分、切分、附点"),
            "detail": qsTrc("appshell", "20 类时值"),
            "iconCode": IconCode.CLOCK,
            "color": "#2980B9"
        },
        {
            "title": qsTrc("appshell", "风格曲目"),
            "subtitle": qsTrc("appshell", "流行、专业、演出比赛"),
            "detail": qsTrc("appshell", "3 种风格"),
            "iconCode": IconCode.MUSIC_NOTES,
            "color": "#8E44AD"
        },
        {
            "title": qsTrc("appshell", "考级曲库"),
            "subtitle": qsTrc("appshell", "国音、上打、RSL、川音、迷笛"),
            "detail": qsTrc("appshell", "5 大体系"),
            "iconCode": IconCode.GRADUATION_CAP,
            "color": "#27AE60"
        },
        {
            "title": qsTrc("appshell", "日更曲库"),
            "subtitle": qsTrc("appshell", "每天更新新曲"),
            "detail": qsTrc("appshell", "持续更新"),
            "iconCode": IconCode.PLAY,
            "color": "#16A085"
        },
        {
            "title": qsTrc("appshell", "AI曲库"),
            "subtitle": qsTrc("appshell", "AI 生成鼓谱"),
            "detail": qsTrc("appshell", "即将上线"),
            "iconCode": IconCode.MUSIC_NOTES,
            "color": "#9B51E0"
        }
    ]

    function categoryTitle() {
        if (root.libraryMode < 0 || root.libraryMode >= root.libraryTabs.length) {
            return ""
        }
        return root.libraryTabs[root.libraryMode].title
    }

    function categoryCardWidth(availableWidth) {
        const width = (availableWidth - (root.categoryColumns - 1) * root.categorySpacing - 2)
                / root.categoryColumns
        return Math.max(180, width)
    }

    function openCategory(index) {
        root.searchText = ""
        librarySearchField.currentText = ""
        root.libraryMode = index
    }

    function closeCategory() {
        root.searchText = ""
        librarySearchField.currentText = ""
        root.libraryMode = -1
    }

    Rectangle {
        anchors.fill: parent
        color: ui.theme.backgroundSecondaryColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.topMargin: 32
        anchors.bottomMargin: 24
        spacing: 16

        // ── 曲库总览 ─────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.libraryMode < 0

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "曲库中心")
                font: Qt.font(Object.assign({}, ui.theme.titleBoldFont, { pixelSize: 24 }))
                horizontalAlignment: Text.AlignLeft
            }

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "选择一个曲库，开始练习")
                font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 12 }))
                color: ui.theme.fontPrimaryColor
                opacity: 0.55
                horizontalAlignment: Text.AlignLeft
            }
        }

        ScrollView {
            id: categoryScroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.libraryMode < 0
            clip: true

            Flow {
                width: categoryScroll.availableWidth
                spacing: root.categorySpacing

                Repeater {
                    model: root.libraryTabs

                    FlatButton {
                        id: categoryCard

                        required property var modelData
                        required property int index

                        width: root.categoryCardWidth(categoryScroll.availableWidth)
                        height: width * 0.56
                        text: modelData.title
                        normalColor: "transparent"
                        hoverHitColor: "transparent"
                        contentItem: Item {}
                        onClicked: root.openCategory(index)

                        backgroundItem: Rectangle {
                            radius: 12
                            clip: true
                            color: "transparent"
                            border.width: 1
                            border.color: categoryCard.mouseArea.containsMouse
                                          ? ui.theme.accentColor
                                          : Qt.rgba(0, 0, 0, 0.18)

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: Qt.lighter(categoryCard.modelData.color, 1.2)
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: Qt.darker(categoryCard.modelData.color, 1.35)
                                    }
                                }
                            }

                            StyledIconLabel {
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.top: parent.top
                                anchors.topMargin: 14
                                iconCode: categoryCard.modelData.iconCode
                                font.pixelSize: 26
                                color: "#FFFFFF"
                                opacity: 0.55
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                anchors.bottomMargin: 16
                                spacing: 3

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: categoryCard.modelData.title
                                    font: Qt.font(Object.assign({}, ui.theme.titleBoldFont, { pixelSize: 20 }))
                                    color: "#FFFFFF"
                                    horizontalAlignment: Text.AlignLeft
                                }

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: categoryCard.modelData.subtitle
                                    font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 11 }))
                                    color: "#FFFFFF"
                                    opacity: 0.7
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                }

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: categoryCard.modelData.detail
                                    font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 10 }))
                                    color: "#FFFFFF"
                                    opacity: 0.55
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 具体曲库 ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12
            visible: root.libraryMode >= 0 && songLibraryView.selectedSong === null

            FlatButton {
                icon: IconCode.CHEVRON_LEFT
                isNarrow: true
                text: qsTrc("appshell", "返回曲库中心")
                transparent: true
                onClicked: root.closeCategory()
            }

            StyledTextLabel {
                text: root.categoryTitle()
                font: Qt.font(Object.assign({}, ui.theme.titleBoldFont, { pixelSize: 22 }))
                horizontalAlignment: Text.AlignLeft
            }

            Item {
                Layout.fillWidth: true
            }

            SearchField {
                id: librarySearchField

                Layout.preferredWidth: 260
                Layout.preferredHeight: 36

                hint: qsTrc("project", "搜索歌曲 / 风格")
                onSearchTextChanged: root.searchText = librarySearchField.searchText
            }
        }

        SongLibraryView {
            id: songLibraryView

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.libraryMode >= 0

            backgroundColor: ui.theme.backgroundSecondaryColor
            lastPracticeModel: root.lastPracticeModel
            playlistModel: root.playlistModel
            songModel: root.songModel
            searchText: root.searchText
            instrument: root.instrument
            libraryMode: root.libraryMode
            instrumentName: root.courseModel
                            ? root.courseModel.instrumentNames[root.instrument]
                            : ""
            onPlayerRequested: root.playerRequested()
        }
    }
}
