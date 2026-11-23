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
import DBScore.Playback

import "internal"

Item {
    id: root

    property alias floating: thePlaybackModel.isToolbarFloating
    readonly property alias isPlaying: thePlaybackModel.isPlaying
    property bool expanded: false
    property real availableWidth: 0

    property NavigationPanel navigationPanel: NavigationPanel {
        id: navPanel
        name: "PlaybackToolBar"
        enabled: root.enabled && root.visible
        accessible.name: qsTrc("playback", "Playback toolbar")
    }

    property alias navigationPanelSection: navPanel.section
    property alias navigationPanelOrder: navPanel.order

    PlaybackToolBarModel {
        id: thePlaybackModel
    }

    width: root.expanded ? root.availableWidth : content.width + (root.floating ? 12 : 0)
    height: content.height

    Component.onCompleted: {
        thePlaybackModel.load()
    }

    function resetTempo() {
        thePlaybackModel.resetTempo()
    }

    function enablePlayRepeats() {
        thePlaybackModel.enablePlayRepeats()
    }

    Column {
        id: content

        width: root.expanded ? root.width : playbackActions.width
        spacing: root.expanded ? 2 : 8

        enabled: thePlaybackModel.isPlayAllowed

        Item {
            width: content.width
            height: playbackActions.height

            PlaybackToolBarActions {
                id: playbackActions

                anchors.horizontalCenter: parent.horizontalCenter
                playbackModel: thePlaybackModel
                floating: root.floating
                navPanel: root.navigationPanel
            }
        }

        RowLayout {
            visible: root.expanded
            width: content.width
            height: 18
            spacing: 10

            StyledTextLabel {
                Layout.preferredWidth: 46
                text: Qt.formatTime(thePlaybackModel.playTime, "mm:ss")
                font: ui.theme.bodyFont
                color: ui.theme.fontPrimaryColor
                opacity: 0.72
                horizontalAlignment: Text.AlignRight
            }

            StyledSlider {
                Layout.fillWidth: true
                value: thePlaybackModel.playPosition
                stepSize: 0.05

                navigation.panel: navPanel
                navigation.order: playbackActions.navigationOrderEnd + 1

                onMoved: {
                    thePlaybackModel.playPosition = value
                }
            }

            StyledTextLabel {
                Layout.preferredWidth: 46
                text: Qt.formatTime(thePlaybackModel.maxPlayTime, "mm:ss")
                font: ui.theme.bodyFont
                color: ui.theme.fontPrimaryColor
                opacity: 0.72
            }
        }

        StyledSlider {
            visible: !root.expanded
            width: playbackActions.width

            value: thePlaybackModel.playPosition
            stepSize: 0.05

            navigation.panel: navPanel
            navigation.order: playbackActions.navigationOrderEnd + 1

            onMoved: {
                thePlaybackModel.playPosition = value
            }
        }
    }
}
