/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 继续学习 hero 卡片
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents

Item {
    id: root

    property var model: null

    signal continueRequested()

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: ui.theme.backgroundPrimaryColor
        border.color: ui.theme.strokeColor

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84
                radius: 16
                color: ui.theme.accentColor

                StyledIconLabel {
                    anchors.centerIn: parent
                    iconCode: IconCode.PLAY
                    font.pixelSize: 38
                    color: "#FFFFFF"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: qsTrc("appshell", "继续学习")
                    font: ui.theme.bodyFont
                    opacity: 0.65
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: root.model ? root.model.title : ""
                    font: ui.theme.titleBoldFont
                    elide: Text.ElideRight
                }

            }

            FlatButton {
                text: qsTrc("appshell", "继续")
                accentButton: true
                enabled: root.model && root.model.hasLast
                onClicked: root.continueRequested()
            }
        }
    }
}
