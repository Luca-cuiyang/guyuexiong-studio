/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 教师中心
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import Muse.Interactive
import DBScore.Preferences

FocusScope {
    id: root

    property int currentSkin: -1
    property int servicePage: -1
    property var accountModel: null
    property bool avatarUpdatePending: false
    property string avatarPreviewSource: ""
    property string avatarUpdateMessage: ""

    readonly property bool compactLayout: width < 700
    readonly property real pageMargin: compactLayout ? 20 : (width < 1200 ? 32 : 48)
    readonly property real contentWidth: Math.max(0, Math.min(width - 2 * pageMargin, 1280))
    readonly property real cardPadding: compactLayout ? 16 : 24
    readonly property int membershipColumns: contentWidth >= 1000 ? 5 : (contentWidth >= 640 ? 3 : 2)
    readonly property int themeColumns: contentWidth >= 1040 ? 4 : (contentWidth >= 540 ? 2 : 1)
    readonly property real serviceButtonWidth: contentWidth < 500
                                                       ? contentWidth
                                                       : (contentWidth < 760 ? (contentWidth - 8) / 2 : 220)
    readonly property real themeCardWidth: Math.min(
                                               280,
                                               (contentWidth - (themeColumns - 1) * 14) / themeColumns)

    readonly property var skins: [
        { "name": "活力橙 · 深蓝", "accent": "#EA580C", "background": "#0F1C33", "theme": "dark" },
        { "name": "天空蓝 · 冰白", "accent": "#0284C7", "background": "#F5F8FC", "theme": "light" },
        { "name": "音乐紫 · 电光青", "accent": "#7C3AED", "background": "#0E2A33", "theme": "dark" },
        { "name": "专业青绿 · 石墨黑", "accent": "#0D9488", "background": "#181A1D", "theme": "dark" }
    ]

    AppearancePreferencesModel {
        id: appearanceModel
    }

    FileDialog {
        id: avatarDialog

        title: qsTrc("appshell", "选择头像")
        nameFilters: [
            qsTrc("appshell", "图片 (*.jpg *.jpeg *.png *.webp)")
        ]

        onAccepted: {
            const selected = currentFile.toString()
            if (!selected) {
                root.avatarUpdateMessage = qsTrc("appshell", "未选择头像图片")
                return
            }

            root.avatarUpdatePending = true
            root.avatarPreviewSource = selected
            root.avatarUpdateMessage = qsTrc("appshell", "正在更新头像…")
            accountModel.clearTransientMessages()
            accountModel.updateAvatar(selected)
        }
    }

    Component.onCompleted: {
        if (accountModel) {
            accountModel.refresh()
        }
        appearanceModel.init()
        Qt.callLater(root.detectCurrentSkin)
    }

    function normalizedColor(value) {
        return String(value || "").toLowerCase()
    }

    function detectCurrentSkin() {
        const accent = normalizedColor(ui.theme.accentColor)
        const background = normalizedColor(appearanceModel.backgroundColor)
        let found = -1

        if (appearanceModel.backgroundUseColor) {
            for (let i = 0; i < root.skins.length; ++i) {
                const skin = root.skins[i]
                if (normalizedColor(skin.accent) === accent
                        && normalizedColor(skin.background) === background
                        && appearanceModel.currentThemeCode === skin.theme) {
                    found = i
                    break
                }
            }
        }

        root.currentSkin = found
    }

    Connections {
        target: appearanceModel

        function onThemesChanged() {
            Qt.callLater(root.detectCurrentSkin)
        }

        function onBackgroundColorChanged() {
            Qt.callLater(root.detectCurrentSkin)
        }

        function onBackgroundUseColorChanged() {
            Qt.callLater(root.detectCurrentSkin)
        }
    }

    Connections {
        target: accountModel

        function onLastErrorChanged() {
            if (root.avatarUpdatePending && accountModel.lastError.length > 0) {
                root.avatarUpdatePending = false
                root.avatarUpdateMessage = accountModel.lastError
            }
        }

        function onModelChanged() {
            if (root.avatarUpdatePending && !accountModel.busy
                    && accountModel.lastError.length === 0) {
                root.avatarUpdatePending = false
                root.avatarPreviewSource = ""
                root.avatarUpdateMessage = ""
            }
        }
    }

    function applySkin(skin) {
        appearanceModel.currentThemeCode = skin.theme
        appearanceModel.setNewColor(skin.accent, AppearancePreferencesModel.AccentColor)
        appearanceModel.backgroundUseColor = true
        appearanceModel.backgroundColor = skin.background
    }

    function openService(page) {
        accountModel.clearTransientMessages()
        root.servicePage = root.servicePage === page ? -1 : page

        if (root.servicePage === 1) {
            accountModel.loadOrders()
        }
    }

    function recentOrders() {
        return accountModel.ordersList.slice(0, 3)
    }

    Rectangle {
        anchors.fill: parent
        color: ui.theme.backgroundSecondaryColor
    }

    ScrollView {
        id: pageScroll

        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: root.contentWidth
            x: Math.max(0, (pageScroll.availableWidth - width) / 2)
            spacing: root.compactLayout ? 12 : 18

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "教师中心")
                font: ui.theme.titleBoldFont
                horizontalAlignment: Text.AlignLeft
            }

            StyledTextLabel {
                Layout.fillWidth: true
                visible: accountModel.lastError.length > 0
                text: accountModel.lastError
                color: ui.theme.accentColor
                font: ui.theme.bodyFont
                wrapMode: Text.WordWrap
            }

            // 账号信息
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: accountContent.implicitHeight + root.cardPadding * 2
                radius: 12
                color: ui.theme.backgroundPrimaryColor
                border.color: ui.theme.strokeColor

                GridLayout {
                    id: accountContent

                    anchors.fill: parent
                    anchors.margins: root.cardPadding
                    columns: root.compactLayout ? 1 : 3
                    columnSpacing: 20
                    rowSpacing: 14

                    ColumnLayout {
                        Layout.preferredWidth: 96
                        Layout.alignment: root.compactLayout ? Qt.AlignHCenter : Qt.AlignTop
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 82
                            Layout.preferredHeight: 82
                            Layout.alignment: Qt.AlignHCenter
                            radius: 41
                            color: ui.theme.accentColor
                            clip: true

                            Image {
                                id: avatarImage

                                anchors.fill: parent
                                source: root.avatarPreviewSource.length > 0
                                        ? root.avatarPreviewSource
                                        : accountModel.avatarUrl
                                visible: source.toString().length > 0
                                         && status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            StyledTextLabel {
                                anchors.centerIn: parent
                                visible: !accountModel.phoneLoggedIn
                                         || accountModel.avatarUrl.length === 0
                                         || avatarImage.status !== Image.Ready
                                text: accountModel.phoneLoggedIn ? accountModel.avatarLetter : "👤"
                                font: ui.theme.largeBodyBoldFont
                            }
                        }

                        FlatButton {
                            Layout.alignment: Qt.AlignHCenter
                            minWidth: 82
                            margins: 10
                            text: root.avatarUpdatePending
                                  ? qsTrc("appshell", "正在更新头像…")
                                  : qsTrc("appshell", "更换头像")
                            transparent: true
                            enabled: accountModel.phoneLoggedIn && !accountModel.busy
                            onClicked: avatarDialog.show()
                        }

                        StyledTextLabel {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 180
                            visible: root.avatarUpdateMessage.length > 0
                            text: root.avatarUpdateMessage
                            color: accountModel.lastError.length > 0
                                   ? ui.theme.accentColor
                                   : ui.theme.fontPrimaryColor
                            font: ui.theme.bodyFont
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: root.compactLayout ? 0 : 220
                        spacing: 5

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: accountModel.phoneLoggedIn
                                  ? (accountModel.phoneNickname.length > 0 ? accountModel.phoneNickname : accountModel.phoneMasked)
                                  : qsTrc("appshell", "未登录")
                            font: ui.theme.headerBoldFont
                            elide: Text.ElideRight
                        }

                        StyledTextLabel {
                            Layout.fillWidth: true
                            visible: accountModel.phoneLoggedIn
                            text: qsTrc("appshell", "手机号：%1").arg(accountModel.phoneNumber)
                            font: ui.theme.bodyFont
                            opacity: 0.65
                            elide: Text.ElideRight
                        }

                        StyledTextLabel {
                            Layout.fillWidth: true
                            visible: accountModel.phoneLoggedIn
                            text: qsTrc("appshell", "注册日期：%1").arg(accountModel.accountCreatedAtText)
                            font: ui.theme.bodyFont
                            opacity: 0.65
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: root.compactLayout ? root.contentWidth : 160
                        Layout.alignment: root.compactLayout ? Qt.AlignHCenter : Qt.AlignTop
                        spacing: 8

                        FlatButton {
                            Layout.fillWidth: true
                            visible: !accountModel.paidMembershipActive
                            text: qsTrc("appshell", "开通会员")
                            accentButton: true
                            onClicked: accountModel.openPurchasePage()
                        }

                        FlatButton {
                            Layout.fillWidth: true
                            visible: accountModel.paidMembershipActive
                            text: qsTrc("appshell", "会员续费")
                            onClicked: accountModel.openPurchasePage()
                        }

                        FlatButton {
                            Layout.fillWidth: true
                            visible: accountModel.phoneLoggedIn
                            text: qsTrc("appshell", "退出登录")
                            onClicked: accountModel.logout()
                        }
                    }
                }
            }

            // 会员详情
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: membershipContent.implicitHeight + root.cardPadding * 2
                radius: 12
                color: ui.theme.backgroundPrimaryColor
                border.color: ui.theme.strokeColor

                ColumnLayout {
                    id: membershipContent

                    anchors.fill: parent
                    anchors.margins: root.cardPadding
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "鼓乐熊Studio 会员")
                            font: ui.theme.headerBoldFont
                        }

                        StyledTextLabel {
                            Layout.fillWidth: false
                            text: accountModel.statusText
                            color: accountModel.hasProAccess
                                   ? "#2ECC71"
                                   : ui.theme.accentColor
                            font: ui.theme.bodyBoldFont
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        FlatButton {
                            text: qsTrc("appshell", "刷新")
                            transparent: true
                            enabled: !accountModel.busy
                            onClicked: accountModel.refresh()
                        }

                        FlatButton {
                            text: accountModel.paidMembershipActive
                                  ? qsTrc("appshell", "会员续费")
                                  : qsTrc("appshell", "开通会员")
                            accentButton: true
                            onClicked: accountModel.openPurchasePage()
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.membershipColumns
                        columnSpacing: 24
                        rowSpacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 100
                            spacing: 4
                            StyledTextLabel {
                                text: qsTrc("appshell", "会员类型")
                                font: ui.theme.bodyFont
                                opacity: 0.55
                            }
                            StyledTextLabel {
                                text: accountModel.membershipKindText
                                font: ui.theme.bodyBoldFont
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 100
                            spacing: 4
                            StyledTextLabel {
                                text: qsTrc("appshell", "会员方案")
                                font: ui.theme.bodyFont
                                opacity: 0.55
                            }
                            StyledTextLabel {
                                text: accountModel.membershipPlan.length > 0
                                      ? accountModel.membershipPlan
                                      : qsTrc("appshell", "未开通")
                                font: ui.theme.bodyBoldFont
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 100
                            spacing: 4
                            StyledTextLabel {
                                text: qsTrc("appshell", "开通日期")
                                font: ui.theme.bodyFont
                                opacity: 0.55
                            }
                            StyledTextLabel {
                                text: accountModel.membershipStartedAtText
                                font: ui.theme.bodyBoldFont
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 100
                            spacing: 4
                            StyledTextLabel {
                                text: qsTrc("appshell", "到期日期")
                                font: ui.theme.bodyFont
                                opacity: 0.55
                            }
                            StyledTextLabel {
                                text: accountModel.membershipExpiresAtText
                                font: ui.theme.bodyBoldFont
                                color: accountModel.hasProAccess
                                       ? "#2ECC71"
                                       : ui.theme.fontPrimaryColor
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 100
                            spacing: 4
                            StyledTextLabel {
                                text: qsTrc("appshell", "权益来源")
                                font: ui.theme.bodyFont
                                opacity: 0.55
                            }
                            StyledTextLabel {
                                text: accountModel.membershipSourceText
                                font: ui.theme.bodyBoldFont
                            }
                        }
                    }
                }
            }

            // 常用账户服务
            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "账户服务")
                font: ui.theme.headerBoldFont
                horizontalAlignment: Text.AlignLeft
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                FlatButton {
                    width: root.serviceButtonWidth
                    text: qsTrc("appshell", "订单记录")
                    accentButton: root.servicePage === 1
                    onClicked: root.openService(1)
                }

                FlatButton {
                    width: root.serviceButtonWidth
                    text: qsTrc("appshell", "软件分享")
                    accentButton: root.servicePage === 3
                    onClicked: root.openService(3)
                }

                FlatButton {
                    width: root.serviceButtonWidth
                    text: qsTrc("appshell", "联系客服")
                    accentButton: root.servicePage === 4
                    onClicked: root.openService(4)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.compactLayout ? 220 : 174
                visible: root.servicePage >= 0
                radius: 12
                color: ui.theme.backgroundPrimaryColor
                border.color: ui.theme.strokeColor

                // 最近订单
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    visible: root.servicePage === 1

                    RowLayout {
                        Layout.fillWidth: true

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "最近订单")
                            font: ui.theme.bodyBoldFont
                        }

                        FlatButton {
                            text: qsTrc("appshell", "刷新")
                            transparent: true
                            enabled: !accountModel.busy
                            onClicked: accountModel.loadOrders()
                        }
                    }

                    StyledTextLabel {
                        Layout.fillWidth: true
                        visible: accountModel.ordersList.length === 0
                        text: accountModel.busy
                              ? qsTrc("appshell", "正在加载订单…")
                              : qsTrc("appshell", "暂无订单记录")
                        font: ui.theme.bodyFont
                        opacity: 0.65
                    }

                    Repeater {
                        model: root.recentOrders()

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            spacing: 12

                            StyledTextLabel {
                                Layout.fillWidth: true
                                text: (modelData.product
                                       ? modelData.product + " · "
                                       : "")
                                      + (modelData.planName
                                         || modelData.orderNo
                                         || qsTrc("appshell", "会员订单"))
                                font: ui.theme.bodyFont
                                elide: Text.ElideRight
                            }

                            StyledTextLabel {
                                text: "¥" + ((modelData.amountCents || 0) / 100).toFixed(2)
                                font: ui.theme.bodyFont
                            }

                            StyledTextLabel {
                                Layout.preferredWidth: 76
                                text: modelData.sourceLabel
                                      || qsTrc("appshell", "历史订单")
                                font: ui.theme.bodyFont
                                opacity: 0.72
                            }

                            StyledTextLabel {
                                text: modelData.status === "paid"
                                      ? qsTrc("appshell", "已支付")
                                      : (modelData.status === "pending"
                                         ? qsTrc("appshell", "待支付")
                                         : modelData.status === "refunded"
                                           ? qsTrc("appshell", "已退款")
                                           : qsTrc("appshell", "已关闭"))
                                font: ui.theme.bodyFont
                                opacity: 0.65
                            }
                        }
                    }
                }

                // 软件分享
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    visible: root.servicePage === 3

                    StyledTextLabel {
                        Layout.fillWidth: true
                        text: qsTrc("appshell", "把鼓乐熊Studio 分享给更多老师和学生")
                        font: ui.theme.bodyBoldFont
                    }

                    StyledTextLabel {
                        Layout.fillWidth: true
                        text: "https://drumbear.cn/download"
                        font: ui.theme.bodyFont
                        opacity: 0.7
                    }

                    FlatButton {
                        text: qsTrc("appshell", "复制分享链接")
                        onClicked: accountModel.copyText("https://drumbear.cn/download")
                    }
                }

                // 客服
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 9
                    visible: root.servicePage === 4

                    StyledTextLabel {
                        Layout.fillWidth: true
                        text: qsTrc("appshell", "如需课程、账号或授权协助，请联系我们")
                        font: ui.theme.bodyBoldFont
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "客服微信：drumbear_ai")
                            font: ui.theme.bodyFont
                        }

                        FlatButton {
                            text: qsTrc("appshell", "复制")
                            transparent: true
                            onClicked: accountModel.copyText("drumbear_ai")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledTextLabel {
                            Layout.fillWidth: true
                            text: qsTrc("appshell", "客服邮箱：support@drumbear.cn")
                            font: ui.theme.bodyFont
                        }

                        FlatButton {
                            text: qsTrc("appshell", "复制")
                            transparent: true
                            onClicked: accountModel.copyText("support@drumbear.cn")
                        }
                    }
                }

                StyledTextLabel {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    visible: accountModel.lastError.length > 0
                    text: accountModel.lastError
                    color: ui.theme.accentColor
                    font: ui.theme.bodyFont
                    elide: Text.ElideRight
                    z: 2
                }
            }

            // 主题颜色
            RowLayout {
                Layout.fillWidth: true

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: qsTrc("appshell", "主题颜色")
                    font: ui.theme.headerBoldFont
                    horizontalAlignment: Text.AlignLeft
                }

                FlatButton {
                    text: qsTrc("appshell", "恢复默认外观")
                    transparent: true
                    onClicked: {
                        appearanceModel.resetAppearancePreferencesToDefault()
                        root.currentSkin = -1
                    }
                }
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: root.themeColumns
                spacing: 14

                Repeater {
                    model: root.skins

                    delegate: Rectangle {
                        id: skinCard
                        required property var modelData
                        required property int index

                        width: root.themeCardWidth
                        height: 104
                        radius: 12
                        activeFocusOnTab: true
                        color: ui.theme.backgroundPrimaryColor
                        border.color: root.currentSkin === index || activeFocus
                                      ? ui.theme.accentColor
                                      : ui.theme.strokeColor
                        border.width: root.currentSkin === index || activeFocus ? 2 : 1

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Rectangle {
                                width: parent.width
                                height: 42
                                radius: 8
                                clip: true

                                Rectangle {
                                    width: parent.width / 2
                                    height: parent.height
                                    color: modelData.accent
                                }

                                Rectangle {
                                    x: parent.width / 2
                                    width: parent.width / 2
                                    height: parent.height
                                    color: modelData.background
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 6

                                StyledTextLabel {
                                    width: parent.width - 20
                                    text: modelData.name
                                    font: ui.theme.bodyFont
                                    elide: Text.ElideRight
                                }

                                StyledIconLabel {
                                    visible: root.currentSkin === index
                                    iconCode: IconCode.TICK_RIGHT_ANGLE
                                    font.pixelSize: 16
                                    color: ui.theme.accentColor
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                skinCard.forceActiveFocus()
                                root.currentSkin = index
                                root.applySkin(modelData)
                            }
                        }

                        Keys.onReturnPressed: {
                            root.currentSkin = index
                            root.applySkin(modelData)
                        }
                        Keys.onEnterPressed: {
                            root.currentSkin = index
                            root.applySkin(modelData)
                        }
                        Keys.onSpacePressed: {
                            root.currentSkin = index
                            root.applySkin(modelData)
                        }
                    }
                }
            }
        }
    }
}
