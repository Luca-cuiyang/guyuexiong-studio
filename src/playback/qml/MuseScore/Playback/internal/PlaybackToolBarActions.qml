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

pragma ComponentBehavior: Bound

import QtQuick

import Muse.UiComponents
import Muse.Ui

import DBScore.NotationScene
import DBScore.Playback

Item {
    id: root

    property PlaybackToolBarModel playbackModel: null

    property NavigationPanel navPanel: null
    readonly property int navigationOrderEnd: repeatButton.navigation.order

    property bool floating: false
    readonly property color playerButtonColor:
        Utils.colorWithAlpha(ui.theme.fontPrimaryColor, ui.theme.isDark ? 0.10 : 0.06)
    readonly property color playerButtonSelectedColor:
        Utils.colorWithAlpha(ui.theme.accentColor, ui.theme.isDark ? 0.68 : 0.46)

    // Not `+ endSeparator.width`: this way, the separator itself is outside the view,
    // which means that it will be exactly at the position of the KDDockWidgets separator
    // between this toolbar and the undo/redo toolbar.
    width: endSeparator.visible ? endSeparator.x
                                : repeatButton.x + repeatButton.width
    height: 30

    ListView {
        id: buttonsListView

        anchors.left: parent.left

        width: contentWidth
        height: contentHeight

        contentHeight: root.height
        spacing: 4

        model: root.playbackModel

        orientation: Qt.Horizontal
        interactive: false

        readonly property int navigationOrderEnd: count

        delegate: FlatButton {
            id: btn

            required property MenuItem item
            required property int index

            readonly property bool fullscreenItem:
                item.code === "command://app/fullscreen"
            readonly property bool muteItem:
                item.id === "drums-mute" || item.id === "accompaniment-mute"
            readonly property bool selected:
                (Boolean(item) && item.checked) || menuLoader.isMenuOpened
            readonly property int playerIconCode: {
                if (item.id === "drums-mute") {
                    return IconCode.PERCUSSION
                }
                if (item.id === "accompaniment-mute") {
                    return IconCode.WAVEFORM_MULTIVIEW
                }
                if (fullscreenItem) {
                    return item.checked ? IconCode.APP_UNMAXIMIZE : IconCode.APP_MAXIMIZE
                }
                return IconCode.NONE
            }
            readonly property string playerToolTip: {
                if (fullscreenItem) {
                    return item.checked
                        ? qsTrc("playback", "退出全屏")
                        : qsTrc("playback", "进入全屏")
                }
                if (muteItem) {
                    return item.title + (item.checked
                        ? qsTrc("playback", " · 已静音")
                        : qsTrc("playback", " · 有声"))
                }
                return item.title
            }

            width: item.id === "play-toggle" ? 42 : 30
            height: root.height

            icon: playerIconCode === IconCode.NONE ? item.icon : IconCode.NONE
            contentItem: playerIconCode === IconCode.NONE ? null : playerIconComponent

            toolTipTitle: Boolean(item) ? playerToolTip : ""
            toolTipDescription: Boolean(item) ? item.description : ""
            toolTipShortcut: Boolean(item)
                             ? (fullscreenItem ? "F11" : item.shortcuts)
                             : ""

            iconFont: ui.theme.toolbarIconsFont

            normalColor: selected ? root.playerButtonSelectedColor : root.playerButtonColor
            hoverHitColor: normalColor
            transparent: false

            navigation.panel: root.navPanel
            navigation.name: toolTipTitle
            navigation.order: index
            accessible.name: playerToolTip

            onClicked: {
                if (menuLoader.isMenuOpened || item.subitems.length) {
                    menuLoader.toggleOpened(item.subitems)
                    return
                }

                Qt.callLater(root.playbackModel.handleMenuItem, item.id)
            }

            Component {
                id: playerIconComponent

                Item {
                    implicitWidth: 18
                    implicitHeight: 18

                    StyledIconLabel {
                        anchors.centerIn: parent
                        iconCode: btn.playerIconCode
                        font: ui.theme.toolbarIconsFont
                        color: btn.iconColor
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 17
                        height: 2
                        radius: 1
                        rotation: -42
                        color: btn.iconColor
                        visible: btn.muteItem && btn.item.checked
                    }
                }
            }

            StyledMenuLoader {
                id: menuLoader

                onHandleMenuItem: function(itemId) {
                    root.playbackModel.handleMenuItem(itemId)
                }
            }
        }
    }

    SeparatorLine {
        id: buttonsSeparator

        anchors.left: buttonsListView.right
        anchors.leftMargin: 6
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        orientation: Qt.Vertical
        visible: !root.floating
    }

    TimeInputField {
        id: timeField

        anchors.left: buttonsSeparator.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        //! NOTE: explicit width prevents the content from jumping around
        // when a score is being played
        // See: https://github.com/musescore/MuseScore/issues/9633
        width: 64

        maxTime: root.playbackModel.maxPlayTime
        maxMillisecondsNumber: 9
        time: root.playbackModel.playTime

        navigationPanel: root.navPanel
        navigationOrderStart: buttonsListView.navigationOrderEnd + 1

        onTimeEdited: function(newTime) {
            root.playbackModel.playTime = newTime
        }
    }

    MeasureAndBeatFields {
        id: measureAndBeatFields

        anchors.left: timeField.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter

        measureNumber: root.playbackModel.measureNumber
        maxMeasureNumber: root.playbackModel.maxMeasureNumber
        beatNumber: root.playbackModel.beatNumber
        maxBeatNumber: root.playbackModel.maxBeatNumber

        font: timeField.font

        navigationPanel: root.navPanel
        navigationOrderStart: timeField.navigationOrderEnd + 1

        onMeasureNumberEdited: function(newValue) {
            root.playbackModel.measureNumber = newValue
        }

        onBeatNumberEdited: function(newValue) {
            root.playbackModel.beatNumber = newValue
        }
    }

    Loader {
        id: tempoLoader

        anchors.left: measureAndBeatFields.right
        anchors.leftMargin: 6

        readonly property int navigationOrderEnd: item?.navigation?.order ?? measureAndBeatFields.navigationOrderEnd

        // Fixed width prevents items from jumping around; but we
        // scale it according to the font size to prevent clipping
        readonly property real tempoViewWidth: 5 * ui.theme.bodyFont.pixelSize

        sourceComponent: root.floating ? tempoViewComponent : tempoButtonComponent

        Component {
            id: tempoViewComponent

            Item {
                implicitWidth: tempoLoader.tempoViewWidth
                implicitHeight: root.height

                TempoView {
                    id: tempoView
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    noteSymbol: root.playbackModel.tempo.noteSymbol
                    tempoValue: root.playbackModel.tempo.value

                    noteSymbolFont.pixelSize: ui.theme.iconsFont.pixelSize
                    tempoValueFont: timeField.font
                }
            }
        }

        Component {
            id: tempoButtonComponent

            PopupButton {
                id: playbackSpeedButton

                implicitWidth: tempoLoader.tempoViewWidth
                implicitHeight: root.height

                normalColor: root.isPopupOpened
                             ? root.playerButtonSelectedColor
                             : root.playerButtonColor
                hoverHitColor: normalColor
                transparent: false

                toolTipTitle: "速度"

                navigation.panel: root.navPanel
                navigation.order: measureAndBeatFields.navigationOrderEnd + 1

                contentItem: TempoView {
                    anchors.centerIn: parent

                    noteSymbol: root.playbackModel.tempo.noteSymbol
                    tempoValue: root.playbackModel.tempo.value

                    noteSymbolFont.pixelSize: ui.theme.iconsFont.pixelSize
                    tempoValueFont: timeField.font
                }

                property PlaybackToolBarModel playbackModel: root.playbackModel

                popupComponent: PlaybackSpeedPopup {
                    playbackModel: playbackSpeedButton.playbackModel
                }
            }
        }
    }

    FlatButton {
        id: loopInButton

        anchors.left: tempoLoader.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter

        width: 46
        height: root.height

        text: qsTrc("playback", "起点")
        toolTipTitle: qsTrc("playback", "循环起点")
        toolTipDescription: qsTrc("playback", "把选中的音符或休止符设为循环起点")

        normalColor: root.playbackModel.loopInEnabled
                     ? root.playerButtonSelectedColor
                     : root.playerButtonColor
        hoverHitColor: normalColor
        transparent: false

        navigation.panel: root.navPanel
        navigation.name: toolTipTitle
        navigation.order: measureAndBeatFields.navigationOrderEnd + 2
        accessible.name: toolTipTitle
        accessible.description: root.playbackModel.loopInEnabled ? "已开启" : "已关闭"

        onClicked: root.playbackModel.toggleLoopIn()
    }

    FlatButton {
        id: loopOutButton

        anchors.left: loopInButton.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 46
        height: root.height

        text: qsTrc("playback", "终点")
        toolTipTitle: qsTrc("playback", "循环终点")
        toolTipDescription: qsTrc("playback", "把选中的音符或休止符设为循环终点")

        normalColor: root.playbackModel.loopOutEnabled
                     ? root.playerButtonSelectedColor
                     : root.playerButtonColor
        hoverHitColor: normalColor
        transparent: false

        navigation.panel: root.navPanel
        navigation.name: toolTipTitle
        navigation.order: measureAndBeatFields.navigationOrderEnd + 3
        accessible.name: toolTipTitle
        accessible.description: root.playbackModel.loopOutEnabled ? "已开启" : "已关闭"

        onClicked: root.playbackModel.toggleLoopOut()
    }

    FlatButton {
        id: repeatButton

        anchors.left: loopOutButton.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 30
        height: root.height

        icon: IconCode.PLAY_REPEATS
        iconFont: ui.theme.toolbarIconsFont
        toolTipTitle: qsTrc("playback", "播放反复")
        toolTipDescription: qsTrc("playback", "开启或关闭播放反复")

        normalColor: root.playbackModel.playRepeatsEnabled
                     ? root.playerButtonSelectedColor
                     : root.playerButtonColor
        hoverHitColor: normalColor
        transparent: false

        navigation.panel: root.navPanel
        navigation.name: toolTipTitle
        navigation.order: measureAndBeatFields.navigationOrderEnd + 4
        accessible.name: toolTipTitle
        accessible.description: root.playbackModel.playRepeatsEnabled ? "已开启" : "已关闭"

        onClicked: root.playbackModel.togglePlayRepeats()
    }

    SeparatorLine {
        id: endSeparator
        anchors.left: repeatButton.right
        anchors.leftMargin: 6
        anchors.topMargin: 2
        anchors.bottomMargin: 2

        orientation: Qt.Vertical
        visible: !root.floating
    }
}
