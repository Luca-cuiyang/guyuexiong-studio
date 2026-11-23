/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import DBScore.AppShell

StyledDialogView {
    id: root

    title: qsTrc("appshell/about", "关于 MusicXML")

    contentHeight: 312
    contentWidth: 456

    AboutModel {
        id: aboutModel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 30

        ColumnLayout {
            id: content

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 36
            Layout.leftMargin: 40
            Layout.rightMargin: 40

            spacing: 24

            StyledTextLabel {
                Layout.fillWidth: true

                text: qsTrc("appshell/about", "MusicXML 是一种用于交换数字乐谱的开放文件格式，已被众多音乐软件支持。")
                font: ui.theme.bodyBoldFont
                wrapMode: Text.WordWrap
            }

            Column {
                Layout.fillWidth: true
                spacing: 12

                StyledTextLabel {
                    width: parent.width

                    text: qsTrc("appshell/about", "版权所有 © 2004-2021 MusicXML 规范贡献者。该规范由 Music Notation Community Group 依据 W3C 社区最终规范协议（FSA）发布：")
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                }

                StyledTextLabel {
                    width: parent.width

                    text: {
                        var license = "<a href='%1'>%2</a>"
                        var musicXMLLicenseUrl = aboutModel.musicXMLLicenseUrl()
                        return license.arg(musicXMLLicenseUrl.url).arg(musicXMLLicenseUrl.displayName)
                    }
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 12

                StyledTextLabel {
                    width: parent.width
                    text: qsTrc("appshell/about", "可查阅易于理解的许可摘要：")
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                }

                StyledTextLabel {
                    width: parent.width

                    text: {
                        var license = "<a href='%1'>%2</a>"
                        var musicXMLLicenseDeedUrl = aboutModel.musicXMLLicenseDeedUrl()
                        return license.arg(musicXMLLicenseDeedUrl.url).arg(musicXMLLicenseDeedUrl.displayName)
                    }
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                }
            }
        }

        ButtonBox {
            Layout.fillWidth: true
            Layout.rightMargin: 16
            Layout.bottomMargin: 16

            buttons: [ ButtonBoxModel.Ok ]

            navigationPanel.section: root.navigationSection

            onStandardButtonClicked: function(buttonId) {
                if (buttonId === ButtonBoxModel.Ok) {
                    root.hide()
                }
            }
        }
    }
}
