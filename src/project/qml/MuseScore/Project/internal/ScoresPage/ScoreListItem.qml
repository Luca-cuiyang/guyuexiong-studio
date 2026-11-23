/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2023 MuseScore Limited and others
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
import Muse.GraphicalEffects
import DBScore.Project

ListItemBlank {
    id: root

    required property var score
    property alias columns: columnsRepeater.model

    property alias thumbnailComponent: thumbnailLoader.sourceComponent

    property real itemInset: 12
    property real columnSpacing: 44
    property alias showBottomBorder: bottomBorder.visible
    property bool showRemoveFromRecentFiles: false

    signal revealInFileBrowserRequested(string scorePath)
    signal removeFromRecentFilesRequested(string scorePath)
    signal addToPlaylistRequested(string scorePath)

    implicitHeight: 64

    navigation.accessible.name: root.score.name ?? ""
    navigation.onActiveChanged: {
        if (navigation.active) {
            root.scrollIntoView()
        }
    }

    focusBorder.anchors.bottomMargin: bottomBorder.visible ? bottomBorder.height : 0

    MouseArea {
        anchors.fill: parent
        enabled: root.visible && root.enabled
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) {
            if (contextMenu.menuModel.length > 0) {
                contextMenu.show(Qt.point(mouse.x, mouse.y), root)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.itemInset
        anchors.rightMargin: root.itemInset

        spacing: root.columnSpacing

        RowLayout {
            spacing: 24

            Loader {
                id: thumbnailLoader

                Layout.preferredWidth: 30
                Layout.preferredHeight: 40

                sourceComponent: scoreThumbnailComp

                layer.enabled: ui.isEffectsAllowed
                layer.effect: RoundedCornersEffect {
                    radius: 2
                }
            }

            Component {
                id: scoreThumbnailComp

                ScoreThumbnail {
                    path: root.score.path ?? ""
                    suffix: root.score.suffix ?? ""
                    thumbnailUrl: root.score.thumbnailUrl ?? ""
                }
            }

            StyledTextLabel {
                Layout.fillWidth: true

                text: root.score.name ?? ""
                font: ui.theme.largeBodyFont
                horizontalAlignment: Text.AlignLeft
            }

        }

        Repeater {
            id: columnsRepeater

            delegate: Loader {
                Layout.preferredWidth: modelData.width(parent.width)

                // These properties are here to give the delegate access to them
                readonly property ScoreListItem listItem: root
                readonly property var score: root.score
                readonly property NavigationPanel navigationPanel: root.navigation.panel
                readonly property int navigationRow: root.navigation.row
                readonly property int navigationColumnStart: 100 * (model.index + 1)

                sourceComponent: modelData.delegate
            }
        }
    }

    ScoreItemMenuButton {
        id: contextMenu

        // Drawn on top of the row instead of taking a spot in the RowLayout, so hover never shifts the columns
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: root.itemInset
        width: 20
        height: 20
        z: 1

        isCreateNew: root.score.isCreateNew ?? false
        isNoResultsFound: root.score.isNoResultsFound ?? false
        showRemoveFromRecentFiles: root.showRemoveFromRecentFiles

        visible: root.mouseArea.containsMouse
                 || mouseArea.containsMouse
                 || root.navigation.active
                 || navigation.active
                 || isMenuOpenedByButton

        navigation.panel: root.navigation.panel
        navigation.row: root.navigation.row
        navigation.column: 100 * (root.columns.length + 1) + 1

        onOpenRequested: root.clicked(null)
        onRevealInFileBrowserRequested: root.revealInFileBrowserRequested(root.score.path ?? "")
        onRemoveFromRecentFilesRequested: root.removeFromRecentFilesRequested(root.score.path ?? "")
        onAddToPlaylistRequested: root.addToPlaylistRequested(root.score.path ?? "")
    }

    SeparatorLine {
        id: bottomBorder
        anchors.bottom: parent.bottom
    }
}
