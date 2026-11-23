/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 播放记录面板
 */
import QtQuick
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents

Rectangle {
    id: root

    property var playlistModel: null
    property color backgroundColor: ui.theme.backgroundSecondaryColor

    color: backgroundColor
    border.color: ui.theme.strokeColor
    radius: 8

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("project", "播放记录（%1）")
                      .arg(root.playlistModel ? root.playlistModel.count : 0)
                font: ui.theme.headerBoldFont
            }

            FlatButton {
                text: qsTrc("project", "清空")
                isNarrow: true
                transparent: true
                enabled: root.playlistModel && root.playlistModel.count > 0
                onClicked: {
                    if (root.playlistModel) {
                        root.playlistModel.clear()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView

                anchors.fill: parent
                clip: true
                model: root.playlistModel
                spacing: 2

                delegate: Rectangle {
                    id: recordRow

                    required property string title
                    required property bool isCurrent
                    required property int index

                    width: listView.width
                    height: 44
                    radius: 6
                    color: isCurrent ? ui.theme.accentColor : ui.theme.backgroundPrimaryColor

                    Accessible.role: Accessible.Button
                    Accessible.name: title

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playlistModel.playAt(recordRow.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: title
                            font: ui.theme.bodyFont
                            color: isCurrent ? ui.theme.backgroundPrimaryColor : ui.theme.fontPrimaryColor
                            elide: Text.ElideRight
                        }

                        FlatButton {
                            text: "✕"
                            isNarrow: true
                            toolTipTitle: qsTrc("project", "从播放记录移除")
                            onClicked: {
                                root.playlistModel.removeAt(recordRow.index)
                            }
                        }
                    }
                }
            }

            StyledTextLabel {
                anchors.centerIn: parent
                visible: !root.playlistModel || root.playlistModel.count === 0
                text: qsTrc("project", "暂无播放记录")
                font: ui.theme.bodyFont
                opacity: 0.55
            }
        }
    }
}
