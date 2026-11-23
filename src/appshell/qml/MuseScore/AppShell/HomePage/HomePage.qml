/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 主页（左侧导航 + 内容）
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import Muse.Ui
import Muse.UiComponents
import DBScore.AppShell
import DBScore.Project

FocusScope {
    id: root

    property string section: "drum.library"
    property string initialSection: "drum.library"
    property var playlistModel: null
    property var accountModel: null
    readonly property bool windowActive: Window.active

    signal playerRequested()

    Component.onCompleted: {
        root.section = root.initialSection
        Qt.callLater(root.scheduleRefresh)
    }

    function subjectOf(section) {
        const idx = section.indexOf(".")
        return idx < 0 ? section : section.substring(0, idx)
    }

    function subOf(section) {
        const idx = section.indexOf(".")
        return idx < 0 ? "" : section.substring(idx + 1)
    }

    function refreshContent() {
        if (!root.accountModel || !root.accountModel.phoneLoggedIn
                || root.subjectOf(root.section) !== "drum") {
            return
        }
        songModel.refresh()
        courseModel.refresh()
    }

    function scheduleRefresh() {
        if (root.accountModel && root.accountModel.phoneLoggedIn
                && root.subjectOf(root.section) === "drum") {
            refreshDebounce.restart()
        }
    }

    onSectionChanged: {
        scheduleRefresh()
    }

    onWindowActiveChanged: {
        if (root.windowActive) {
            scheduleRefresh()
        }
    }

    function instrumentOf(section) {
        switch (subjectOf(section)) {
        case "djembe": return 1
        case "guitar": return 2
        case "band": return 3
        case "vocal": return 4
        default: return 0
        }
    }

    LastPracticeModel {
        id: lastPracticeModel

        Component.onCompleted: {
            lastPracticeModel.load()
        }
    }

    CourseModel {
        id: courseModel
    }

    SongModel {
        id: songModel
    }

    FavoritesModel {
        id: favoritesModel
    }

    Timer {
        id: refreshDebounce
        interval: 250
        repeat: false
        onTriggered: root.refreshContent()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible && root.accountModel !== null
                 && root.accountModel.phoneLoggedIn
        onTriggered: root.refreshContent()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左侧导航栏
        Rectangle {
            Layout.preferredWidth: 248
            Layout.fillHeight: true
            color: ui.theme.backgroundPrimaryColor

            // 右侧细分隔线，和内容区明确分层
            Rectangle {
                width: 1
                height: parent.height
                anchors.right: parent.right
                color: ui.theme.strokeColor
                opacity: 0.5
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                anchors.topMargin: 16
                anchors.bottomMargin: 14
                spacing: 0

                // Logo
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    spacing: 11

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 11
                        color: ui.theme.accentColor

                        StyledTextLabel {
                            anchors.centerIn: parent
                            text: "DB"
                            font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                                        { pixelSize: 13, weight: Font.DemiBold }))
                            color: "#FFFFFF"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "鼓乐熊Studio")
                            font: Qt.font(Object.assign({}, ui.theme.headerBoldFont,
                                                        { pixelSize: 17, weight: Font.DemiBold }))
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 2
                            radius: 1
                            color: ui.theme.accentColor
                            opacity: 0.9
                        }
                    }
                }

                // 导航可滚动区：内容再多也不会挤压或重叠
                Flickable {
                    id: menuFlick

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 18
                    clip: true
                    contentWidth: width
                    contentHeight: homeMenu.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    HomeMenu {
                        id: homeMenu

                        width: menuFlick.width
                        currentPageName: root.section

                        onSelected: function(name) {
                            root.section = name
                        }
                    }
                }

                // 会员状态条
                Rectangle {
                    id: accountCard

                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    Layout.topMargin: 10
                    radius: 12
                    activeFocusOnTab: true
                    color: root.section === "profile"
                           ? Qt.rgba(ui.theme.accentColor.r, ui.theme.accentColor.g,
                                     ui.theme.accentColor.b, 0.10)
                           : ui.theme.backgroundSecondaryColor
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus || root.section === "profile"
                                  ? ui.theme.accentColor
                                  : ui.theme.strokeColor

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTrc("appshell", "教师中心：%1")
                                     .arg(root.accountModel ? root.accountModel.shortStatusText : "")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 17
                            color: ui.theme.accentColor
                            clip: true

                            Image {
                                id: sidebarAvatarImage

                                anchors.fill: parent
                                source: root.accountModel ? root.accountModel.avatarUrl : ""
                                visible: source.toString().length > 0
                                         && status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            StyledTextLabel {
                                anchors.centerIn: parent
                                visible: !root.accountModel
                                         || !root.accountModel.phoneLoggedIn
                                         || root.accountModel.avatarUrl.length === 0
                                         || sidebarAvatarImage.status !== Image.Ready
                                text: root.accountModel ? root.accountModel.avatarLetter : "D"
                                font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                                            { pixelSize: 12, weight: Font.DemiBold }))
                                color: "#FFFFFF"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledTextLabel {
                                Layout.fillWidth: true
                                text: root.accountModel
                                      ? (root.accountModel.phoneNickname.length > 0
                                         ? root.accountModel.phoneNickname
                                         : root.accountModel.phoneMasked)
                                      : qsTrc("appshell", "未登录")
                                font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                                            { pixelSize: 13, weight: Font.DemiBold }))
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    Layout.alignment: Qt.AlignVCenter
                                    color: root.accountModel && root.accountModel.hasProAccess
                                           ? "#2ECC71" : "#F1C40F"
                                }

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: root.accountModel ? root.accountModel.shortStatusText : ""
                                    font: Qt.font(Object.assign({}, ui.theme.bodyFont,
                                                                { pixelSize: 10.5, weight: Font.Medium }))
                                    opacity: 0.62
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StyledIconLabel {
                            Layout.preferredWidth: 11
                            Layout.alignment: Qt.AlignVCenter
                            iconCode: IconCode.CHEVRON_RIGHT
                            font.pixelSize: 11
                            color: ui.theme.fontPrimaryColor
                            opacity: 0.28
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            accountCard.forceActiveFocus()
                            root.section = "profile"
                        }
                    }

                    Keys.onReturnPressed: root.section = "profile"
                    Keys.onEnterPressed: root.section = "profile"
                    Keys.onSpacePressed: root.section = "profile"
                }
            }
        }

        // 内容区
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: ui.theme.backgroundSecondaryColor

            Loader {
                anchors.fill: parent

                sourceComponent: {
                    if (root.section === "learning") {
                        return learningComp
                    }
                    if (root.section === "profile") {
                        return profileComp
                    }
                    if (root.subOf(root.section) === "library") {
                        return libraryComp
                    }
                    return courseComp
                }
            }
        }
    }

    Component {
        id: libraryComp

        SongLibraryPage {
            instrument: root.instrumentOf(root.section)
            courseModel: courseModel
            songModel: songModel
            lastPracticeModel: lastPracticeModel
            playlistModel: root.playlistModel
            onPlayerRequested: root.playerRequested()
        }
    }

    Component {
        id: courseComp

        CourseCenterPage {
            instrument: root.instrumentOf(root.section)
            section: root.subOf(root.section)
            courseModel: courseModel
            songModel: songModel
            favoritesModel: favoritesModel
            lastPracticeModel: lastPracticeModel
            playlistModel: root.playlistModel
            onPlayerRequested: root.playerRequested()
        }
    }

    Component {
        id: learningComp

        MyLearningPage {
            favoritesModel: favoritesModel
            lastPracticeModel: lastPracticeModel
        }
    }

    Component {
        id: profileComp

        ProfilePage {
            accountModel: root.accountModel
        }
    }
}
