/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 我的教学
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import DBScore.AppShell
import DBScore.Project

FocusScope {
    id: root

    property var lastPracticeModel: null
    property var favoritesModel: null

    Component.onCompleted: {
        if (root.favoritesModel) {
            root.favoritesModel.load()
        }
    }

    function recentReports() {
        const result = []
        for (let i = reportModel.reports.length - 1; i >= 0; --i) {
            result.push(reportModel.reports[i])
        }
        // 取最新 14 次练习（result 已按时间倒序）
        return result.slice(0, 14)
    }

    PracticeReportModel {
        id: reportModel

        Component.onCompleted: {
            reportModel.load()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ui.theme.backgroundSecondaryColor
    }

    ScrollView {
        id: pageScroll

        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            x: 46
            y: 46
            width: Math.max(0, pageScroll.availableWidth - 92)
            spacing: 20

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "我的教学")
                font: ui.theme.titleBoldFont
                horizontalAlignment: Text.AlignLeft
            }

            ContinueLearningCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 112
                visible: root.lastPracticeModel && root.lastPracticeModel.hasLast

                model: root.lastPracticeModel

                onContinueRequested: {
                    if (root.lastPracticeModel) {
                        root.lastPracticeModel.continuePractice()
                    }
                }
            }

            // 打卡连胜
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: 16
                color: ui.theme.backgroundPrimaryColor
                border.color: ui.theme.strokeColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 20

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "连续练习")
                            font: ui.theme.bodyFont
                            opacity: 0.65
                        }

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "%1 天").arg(reportModel.currentStreak)
                            font: ui.theme.titleBoldFont
                            color: ui.theme.accentColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "累计练习")
                            font: ui.theme.bodyFont
                            opacity: 0.65
                        }

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "%1 天").arg(reportModel.totalPracticeDays)
                            font: ui.theme.headerBoldFont
                        }
                    }

                    Row {
                        spacing: 8

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: reportModel.practicedToday ? "#2ECC71" : "#F1C40F"
                        }

                        StyledTextLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: reportModel.practicedToday
                                  ? qsTrc("appshell", "今日已打卡")
                                  : qsTrc("appshell", "今日未打卡")
                            font: ui.theme.bodyBoldFont
                        }
                    }
                }
            }

            // 最近 7 天打卡
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: reportModel.recentDays

                    delegate: Column {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 5

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30
                            height: 30
                            radius: 15
                            color: modelData.practiced ? "#2ECC71" : "transparent"
                            border.color: modelData.practiced ? "#2ECC71" : ui.theme.strokeColor

                            StyledTextLabel {
                                anchors.centerIn: parent
                                text: modelData.label
                                font: ui.theme.bodyFont
                                color: modelData.practiced ? "#FFFFFF" : ui.theme.fontSecondaryColor
                            }
                        }

                        StyledTextLabel {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.isToday ? qsTrc("appshell", "今天") : " "
                            font: ui.theme.bodyFont
                            opacity: 0.55
                        }
                    }
                }
            }

            // 收藏
            StyledTextLabel {
                Layout.fillWidth: true
                Layout.topMargin: 10
                text: qsTrc("appshell", "收藏")
                font: ui.theme.headerBoldFont
                horizontalAlignment: Text.AlignLeft
            }

            Flow {
                id: favoritesFlow

                Layout.fillWidth: true
                spacing: 10

                StyledTextLabel {
                    visible: favoritesModel.favorites.length === 0
                    width: parent.width
                    text: qsTrc("appshell", "还没有收藏，去曲库或课程中心点亮星标吧")
                    font: ui.theme.bodyFont
                    opacity: 0.55
                }

                Repeater {
                    model: favoritesModel.favorites

                    delegate: Rectangle {
                        required property var modelData

                        width: Math.min(200, favoritesFlow.width)
                        height: 40
                        radius: 10
                        activeFocusOnTab: modelData.filePath !== ""
                        color: ui.theme.backgroundPrimaryColor
                        border.color: activeFocus ? ui.theme.accentColor : ui.theme.strokeColor
                        border.width: activeFocus ? 2 : 1

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            StyledIconLabel {
                                iconCode: IconCode.STAR
                                font.pixelSize: 16
                            }

                            StyledTextLabel {
                                Layout.fillWidth: true
                                text: modelData.title
                                font: ui.theme.bodyFont
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.filePath !== ""
                            onClicked: {
                                parent.forceActiveFocus()
                                favoritesModel.openFavorite(modelData.filePath, modelData.title)
                            }
                        }

                        Keys.onReturnPressed: favoritesModel.openFavorite(modelData.filePath, modelData.title)
                        Keys.onEnterPressed: favoritesModel.openFavorite(modelData.filePath, modelData.title)
                        Keys.onSpacePressed: favoritesModel.openFavorite(modelData.filePath, modelData.title)
                    }
                }
            }

            // 进步趋势
            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "进步趋势")
                font: ui.theme.headerBoldFont
                horizontalAlignment: Text.AlignLeft
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                radius: 14
                color: ui.theme.backgroundPrimaryColor
                border.color: ui.theme.strokeColor

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.recentReports()

                        delegate: Rectangle {
                            required property var modelData

                            width: 14
                            height: 10 + modelData.accuracy * 80
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.accuracy >= 0.8 ? "#2ECC71"
                                                             : (modelData.accuracy >= 0.6 ? "#F1C40F" : "#E74C3C")
                        }
                    }

                    StyledTextLabel {
                        visible: root.recentReports().length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTrc("appshell", "完成几次练习后，这里会显示命中率变化")
                        font: ui.theme.bodyFont
                        opacity: 0.55
                    }
                }
            }

            // 练习报告
            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "练习报告")
                font: ui.theme.headerBoldFont
                horizontalAlignment: Text.AlignLeft
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledTextLabel {
                    visible: reportModel.reports.length === 0
                    Layout.fillWidth: true
                    text: qsTrc("appshell", "还没有练习记录，开始第一段练习吧")
                    font: ui.theme.bodyFont
                    opacity: 0.55
                    horizontalAlignment: Text.AlignHCenter
                    Layout.topMargin: 24
                }

                Repeater {
                    model: reportModel.reports

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 68
                        radius: 10
                        color: ui.theme.backgroundPrimaryColor
                        border.color: ui.theme.strokeColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font: ui.theme.bodyBoldFont
                                    elide: Text.ElideRight
                                }

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: modelData.date
                                    font: ui.theme.bodyFont
                                    opacity: 0.6
                                }
                            }

                            ColumnLayout {
                                spacing: 4

                                StyledTextLabel {
                                    text: qsTrc("appshell", "命中率 %1%").arg(Math.round(modelData.accuracy * 100))
                                    font: ui.theme.bodyBoldFont
                                    horizontalAlignment: Text.AlignRight
                                }

                                Row {
                                    spacing: 2
                                    layoutDirection: Qt.RightToLeft

                                    Repeater {
                                        model: 5

                                        delegate: StyledIconLabel {
                                            required property int index

                                            iconCode: IconCode.STAR
                                            font.pixelSize: 14
                                            color: index < modelData.starRating ? "#F1C40F" : ui.theme.strokeColor
                                        }
                                    }
                                }

                                StyledTextLabel {
                                    text: qsTrc("appshell", "完美%1 早%2 晚%3 漏%4 · 最高连击%5").arg(modelData.perfect)
                                          .arg(modelData.early).arg(modelData.late).arg(modelData.missed).arg(modelData.maxCombo)
                                    font: ui.theme.bodyFont
                                    opacity: 0.7
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
            }
        }
    }
}
