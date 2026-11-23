/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 曲库筛选胶囊按钮（紧凑型，替代 FlatButton 的 132px 最小宽度）
 */
pragma ComponentBehavior: Bound

import QtQuick

import Muse.Ui
import Muse.UiComponents

Rectangle {
    id: root

    property string text: ""
    property bool checked: false
    property real chipHeight: 32
    property font chipFont: ui.theme.bodyFont
    property color checkedColor: ui.theme.accentColor
    property color checkedTextColor: "#FFFFFF"
    property color uncheckedColor: ui.theme.backgroundPrimaryColor
    property color uncheckedTextColor: ui.theme.fontPrimaryColor

    signal activated()

    width: Math.max(chipHeight, label.implicitWidth + 26)
    height: chipHeight
    radius: chipHeight / 2
    activeFocusOnTab: true

    color: root.checked ? root.checkedColor : root.uncheckedColor
    border.width: root.activeFocus ? 2 : 1
    border.color: root.checked || root.activeFocus ? ui.theme.accentColor : ui.theme.strokeColor

    Accessible.role: Accessible.Button
    Accessible.name: root.text

    StyledTextLabel {
        id: label
        anchors.centerIn: parent
        text: root.text
        font: root.chipFont
        color: root.checked ? root.checkedTextColor : root.uncheckedTextColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus()
            root.activated()
        }
    }

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    states: [
        State {
            name: "HOVERED"
            when: mouseArea.containsMouse && !root.checked

            PropertyChanges {
                target: root
                border.color: ui.theme.accentColor
            }
        }
    ]
}
