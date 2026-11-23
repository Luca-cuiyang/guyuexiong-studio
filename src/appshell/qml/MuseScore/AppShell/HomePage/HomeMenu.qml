/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 左侧导航（科目 → 曲库/课程/专项/考级）
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents

Item {
    id: root

    property string currentPageName: ""
    property string expandedSubject: "drum"

    signal selected(string name)

    onCurrentPageNameChanged: {
        const idx = root.currentPageName.indexOf(".")
        if (idx > 0) {
            root.expandedSubject = root.currentPageName.substring(0, idx)
        }
    }

    function tint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function toggleSubject(subjectName) {
        root.expandedSubject = root.expandedSubject === subjectName ? "" : subjectName
    }

    // Shared metrics keep first-level and second-level navigation visually related.
    readonly property real sectionLabelHeight: 30
    readonly property real subjectRowHeight: 44
    readonly property real subRowHeight: 32
    readonly property real mineRowHeight: 36
    readonly property real rowRadius: 10
    readonly property real rowSidePadding: 12
    readonly property real iconBoxSize: 28
    readonly property real mineIconBoxSize: 24
    readonly property real iconSize: 15
    readonly property real chevronSize: 11

    implicitWidth: navColumn.implicitWidth
    implicitHeight: navColumn.implicitHeight

    readonly property var subjectItems: [
        { "name": "drum", "title": qsTrc("appshell", "架子鼓"), "iconCode": IconCode.PERCUSSION, "color": "#F57C00" },
        { "name": "djembe", "title": qsTrc("appshell", "非洲鼓"), "iconCode": IconCode.PERCUSSION, "color": "#E67E22" },
        { "name": "guitar", "title": qsTrc("appshell", "吉他弹唱"), "iconCode": IconCode.MUSIC_NOTES, "color": "#2980B9" },
        { "name": "band", "title": qsTrc("appshell", "少儿乐队"), "iconCode": IconCode.MUSIC_NOTES, "color": "#8E44AD" },
        { "name": "vocal", "title": qsTrc("appshell", "声乐课程"), "iconCode": IconCode.MICROPHONE, "color": "#E74C3C" }
    ]

    readonly property var subItems: [
        { "id": "library", "title": qsTrc("appshell", "曲库中心"), "iconCode": IconCode.MUSIC_NOTES },
        { "id": "courses", "title": qsTrc("appshell", "课程中心"), "iconCode": IconCode.LEARN },
        { "id": "special", "title": qsTrc("appshell", "专项训练"), "iconCode": IconCode.STAR },
        { "id": "exam", "title": qsTrc("appshell", "考级中心"), "iconCode": IconCode.GRADUATION_CAP }
    ]

    readonly property var mineItems: [
        { "name": "learning", "title": qsTrc("appshell", "我的教学"), "iconCode": IconCode.LEARN },
        { "name": "profile", "title": qsTrc("appshell", "教师中心"), "iconCode": IconCode.ACCOUNT }
    ]

    Column {
        id: navColumn
        width: parent.width
        spacing: 2

        // ── 分区：课程方向 ─────────────────────────────
        StyledTextLabel {
            width: parent.width
            height: root.sectionLabelHeight
            text: qsTrc("appshell", "课程方向")
            font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                        { pixelSize: 10, weight: Font.DemiBold, letterSpacing: 1.25 }))
            color: ui.theme.fontPrimaryColor
            opacity: 0.48
            leftPadding: 10
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: root.subjectItems

            delegate: Column {
                id: subjectColumn
                required property var modelData

                property string subjectName: modelData.name
                property bool isExpanded: root.expandedSubject === subjectName

                width: parent.width
                spacing: 0

                // Primary level: subject entry.
                Rectangle {
                    id: subjectHeader

                    width: parent.width
                    height: root.subjectRowHeight
                    radius: root.rowRadius
                    activeFocusOnTab: true
                    color: subjectColumn.isExpanded
                           ? root.tint(subjectColumn.modelData.color, 0.09)
                           : (subjectHeaderHover.containsMouse
                              ? ui.theme.backgroundSecondaryColor
                              : "transparent")
                    border.width: activeFocus ? 1 : 0
                    border.color: ui.theme.accentColor

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: subjectColumn.modelData.title

                    Rectangle {
                        visible: subjectColumn.isExpanded
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 1.5
                        color: subjectColumn.modelData.color
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.rowSidePadding
                        anchors.rightMargin: 10
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: root.iconBoxSize
                            Layout.preferredHeight: root.iconBoxSize
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            color: root.tint(subjectColumn.modelData.color,
                                             subjectColumn.isExpanded ? 0.18 : 0.10)

                            StyledIconLabel {
                                anchors.centerIn: parent
                                iconCode: subjectColumn.modelData.iconCode
                                font.pixelSize: root.iconSize
                                color: subjectColumn.modelData.color
                            }
                        }

                        StyledTextLabel {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: subjectColumn.modelData.title
                            font: Qt.font(Object.assign({}, subjectColumn.isExpanded
                                                        ? ui.theme.bodyBoldFont
                                                        : ui.theme.bodyFont,
                                                        { pixelSize: 13.5,
                                                          weight: subjectColumn.isExpanded
                                                                  ? Font.DemiBold
                                                                  : Font.Medium }))
                            color: ui.theme.fontPrimaryColor
                            elide: Text.ElideRight
                        }

                        StyledIconLabel {
                            Layout.preferredWidth: root.chevronSize
                            Layout.alignment: Qt.AlignVCenter
                            iconCode: IconCode.CHEVRON_RIGHT
                            font.pixelSize: root.chevronSize
                            opacity: subjectColumn.isExpanded ? 0.72 : 0.32
                            rotation: subjectColumn.isExpanded ? 90 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 120 }
                            }
                        }
                    }

                    MouseArea {
                        id: subjectHeaderHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            subjectHeader.forceActiveFocus()
                            root.toggleSubject(subjectColumn.subjectName)
                        }
                    }

                    Keys.onReturnPressed: root.toggleSubject(subjectColumn.subjectName)
                    Keys.onEnterPressed: root.toggleSubject(subjectColumn.subjectName)
                    Keys.onSpacePressed: root.toggleSubject(subjectColumn.subjectName)
                }

                // Secondary level: actions belonging to the current subject.
                Item {
                    visible: subjectColumn.isExpanded
                    width: parent.width
                    height: visible ? subList.height + 10 : 0

                    Rectangle {
                        x: 13
                        y: 4
                        width: 1
                        height: Math.max(0, subList.height - 8)
                        color: subjectColumn.modelData.color
                        opacity: 0.28
                    }

                    Column {
                        id: subList

                        x: 22
                        y: 4
                        width: parent.width - x
                        spacing: 2

                        Repeater {
                            model: root.subItems

                            delegate: Rectangle {
                                id: subItem
                                required property var modelData

                                width: parent.width
                                height: root.subRowHeight
                                radius: 8
                                activeFocusOnTab: subjectColumn.isExpanded

                                property string pageName: subjectColumn.subjectName + "." + modelData.id
                                property bool isCurrent: pageName === root.currentPageName

                                color: isCurrent
                                       ? root.tint(subjectColumn.modelData.color, 0.12)
                                       : (subHover.containsMouse
                                          ? ui.theme.backgroundSecondaryColor
                                          : "transparent")
                                border.width: activeFocus ? 1 : 0
                                border.color: ui.theme.accentColor

                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.title

                                Rectangle {
                                    visible: subItem.isCurrent
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: 14
                                    radius: 1
                                    color: subjectColumn.modelData.color
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 9
                                    spacing: 9

                                    StyledIconLabel {
                                        Layout.preferredWidth: 15
                                        Layout.alignment: Qt.AlignVCenter
                                        iconCode: subItem.modelData.iconCode
                                        font.pixelSize: 13
                                        color: subItem.isCurrent
                                               ? subjectColumn.modelData.color
                                               : ui.theme.fontPrimaryColor
                                        opacity: subItem.isCurrent ? 1 : 0.55
                                    }

                                    StyledTextLabel {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        text: subItem.modelData.title
                                        font: Qt.font(Object.assign({}, subItem.isCurrent
                                                                    ? ui.theme.bodyBoldFont
                                                                    : ui.theme.bodyFont,
                                                                    { pixelSize: 12.5,
                                                                      weight: subItem.isCurrent
                                                                              ? Font.DemiBold
                                                                              : Font.Medium }))
                                        color: ui.theme.fontPrimaryColor
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: subHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        subItem.forceActiveFocus()
                                        root.selected(pageName)
                                    }
                                }

                                Keys.onReturnPressed: root.selected(pageName)
                                Keys.onEnterPressed: root.selected(pageName)
                                Keys.onSpacePressed: root.selected(pageName)
                            }
                        }
                    }
                }
            }
        }

        // ── 分区：我的 ────────────────────────────────
        Item {
            width: parent.width
            height: 22

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: ui.theme.strokeColor
                opacity: 0.45
            }
        }

        StyledTextLabel {
            width: parent.width
            height: root.sectionLabelHeight
            text: qsTrc("appshell", "我的")
            font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                        { pixelSize: 10, weight: Font.DemiBold, letterSpacing: 1.25 }))
            color: ui.theme.fontPrimaryColor
            opacity: 0.48
            leftPadding: 10
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: root.mineItems

            delegate: Rectangle {
                id: mineItem
                required property var modelData

                width: parent.width
                height: root.mineRowHeight
                radius: root.rowRadius
                activeFocusOnTab: true

                property bool isCurrent: modelData.name === root.currentPageName

                color: isCurrent
                       ? root.tint(ui.theme.accentColor, 0.10)
                       : (mineHover.containsMouse ? ui.theme.backgroundSecondaryColor : "transparent")
                border.width: activeFocus ? 1 : 0
                border.color: ui.theme.accentColor

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title

                Rectangle {
                    visible: mineItem.isCurrent
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 17
                    radius: 1.5
                    color: ui.theme.accentColor
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.rowSidePadding
                    anchors.rightMargin: 10
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: root.mineIconBoxSize
                        Layout.preferredHeight: root.mineIconBoxSize
                        Layout.alignment: Qt.AlignVCenter
                        radius: 7
                        color: root.tint(ui.theme.accentColor, mineItem.isCurrent ? 0.16 : 0.08)

                        StyledIconLabel {
                            anchors.centerIn: parent
                            iconCode: mineItem.modelData.iconCode
                            font.pixelSize: 13
                            color: ui.theme.accentColor
                        }
                    }

                    StyledTextLabel {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: modelData.title
                        font: Qt.font(Object.assign({}, mineItem.isCurrent
                                                    ? ui.theme.bodyBoldFont
                                                    : ui.theme.bodyFont,
                                                    { pixelSize: 12.5,
                                                      weight: mineItem.isCurrent
                                                              ? Font.DemiBold
                                                              : Font.Medium }))
                        color: ui.theme.fontPrimaryColor
                    }

                    StyledIconLabel {
                        Layout.preferredWidth: root.chevronSize
                        Layout.alignment: Qt.AlignVCenter
                        iconCode: IconCode.CHEVRON_RIGHT
                        font.pixelSize: root.chevronSize
                        color: ui.theme.fontPrimaryColor
                        opacity: mineItem.isCurrent ? 0.72 : 0.28
                    }
                }

                MouseArea {
                    id: mineHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mineItem.forceActiveFocus()
                        root.selected(modelData.name)
                    }
                }

                Keys.onReturnPressed: root.selected(modelData.name)
                Keys.onEnterPressed: root.selected(modelData.name)
                Keys.onSpacePressed: root.selected(modelData.name)
            }
        }
    }
}
