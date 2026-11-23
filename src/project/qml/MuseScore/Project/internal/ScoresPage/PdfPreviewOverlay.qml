/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - on-demand PDF preview
 */
import QtQuick
import QtQuick.Pdf

import Muse.Ui
import Muse.UiComponents

Rectangle {
    id: root

    property string pdfPath: ""
    property string pdfUrl: ""

    signal closeRequested()

    color: "#0B0B0C"

    PdfDocument {
        id: pdfDocument

        source: root.pdfUrl
    }

    PdfMultiPageView {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: pdfTopBar.bottom
        anchors.bottom: parent.bottom
        document: pdfDocument
    }

    Rectangle {
        id: pdfTopBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 48
        color: "#141417"
        z: 2

        StyledTextLabel {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: pdfClose.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.pdfPath
            font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 13 }))
            color: "#FFFFFF"
            opacity: 0.75
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideMiddle
        }

        Rectangle {
            id: pdfClose

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: pdfCloseMouse.containsMouse ? "#2A2A2E" : "transparent"

            StyledIconLabel {
                anchors.centerIn: parent
                iconCode: IconCode.CLOSE_X_ROUNDED
                font.pixelSize: 16
                color: "#FFFFFF"
                opacity: 0.8
            }

            MouseArea {
                id: pdfCloseMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }
}
