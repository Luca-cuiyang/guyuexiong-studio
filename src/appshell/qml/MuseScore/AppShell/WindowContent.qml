/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 窗口内容（纯 QML，无 Dock 框架）
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Interactive
import Muse.Ui
import Muse.UiComponents
import Muse.Update
import Muse.Cloud as Cloud
import DBScore.AppShell

import "./HomePage"
import "./NotationPage"

Item {
    id: root

    property int sendCooldown: 0
    property string loginError: ""
    property string currentPage: "home" // home | player
    property string homeSection: "drum.library"
    property bool playerLoaded: false

    function showPlayer() {
        playerLoaded = true
        currentPage = "player"
    }

    function isValidPhone(value) {
        return /^1\d{10}$/.test(value.trim())
    }

    function isValidCode(value) {
        return /^\d{6}$/.test(value.trim())
    }

    function requestLoginCode() {
        const phone = loginPhoneField.text.trim()
        if (!root.isValidPhone(phone)) {
            root.loginError = qsTrc("appshell", "请输入正确的 11 位手机号")
            return
        }
        root.loginError = ""
        accountModelService.sendCode(phone)
    }

    function submitLogin() {
        const phone = loginPhoneField.text.trim()
        const code = loginCodeField.text.trim()
        if (!root.isValidPhone(phone)) {
            root.loginError = qsTrc("appshell", "请输入正确的 11 位手机号")
            return
        }
        if (!root.isValidCode(code)) {
            root.loginError = qsTrc("appshell", "请输入收到的验证码")
            return
        }
        root.loginError = ""
        accountModelService.loginByPhone(phone, code)
    }

    Cloud.DbScoreAccountModel {
        id: accountModelService
    }

    Cloud.PaymentDialog {
        id: paymentDialog

        visible: false
        qrSource: accountModelService.paymentQrSource
        planName: accountModelService.paymentPlanName
        amountText: accountModelService.paymentAmountText
        orderNumber: accountModelService.paymentOrderNumber
        statusText: accountModelService.paymentStatusText
        checking: accountModelService.paymentChecking
        creating: accountModelService.paymentCreating

        onCheckRequested: accountModelService.checkPaymentNow()
        onClosed: accountModelService.closePaymentDialog()
    }

    Connections {
        target: accountModelService

        function onSendCodeMessageChanged() {
            if (accountModelService.sendCodeMessage.length > 0) {
                root.sendCooldown = 60
            }
        }

        function onPaymentVisibleChanged() {
            if (accountModelService.paymentVisible) {
                paymentDialog.open()
            } else {
                paymentDialog.close()
            }
        }
    }

    PlaylistModel {
        id: playlistModel

        Component.onCompleted: {
            playlistModel.load()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.sendCooldown > 0
        onTriggered: {
            if (root.sendCooldown > 0) {
                root.sendCooldown -= 1
            }
        }
    }

    InteractiveProvider {
        id: interactiveProvider
        topParent: root

        onRequestedDockPage: function(uri, params) {
            const target = String(uri)
            if (target.indexOf("dbscore://notation") === 0) {
                root.showPlayer()
            } else {
                if (target === "dbscore://account") {
                    root.homeSection = "profile"
                    homePage.section = "profile"
                } else if (target.indexOf("dbscore://home") === 0
                           && params && params.section) {
                    root.homeSection = String(params.section)
                    homePage.section = root.homeSection
                }
                root.currentPage = "home"
            }

            Qt.callLater(interactiveProvider.onPageOpened)
        }
    }

    HomePage {
        id: homePage

        anchors.fill: parent
        visible: root.currentPage === "home"
        enabled: visible
        initialSection: root.homeSection
        playlistModel: playlistModel
        accountModel: accountModelService

        onSectionChanged: {
            root.homeSection = section
        }

        onPlayerRequested: {
            root.showPlayer()
        }
    }

    Loader {
        anchors.fill: parent
        z: 10
        // Keep the player instance after its first use. Returning to the library
        // should not destroy and rebuild the notation engine.
        active: root.playerLoaded
        visible: root.currentPage === "player"
        enabled: visible
        sourceComponent: playerComp
    }

    Component {
        id: playerComp

        NotationPage {
            playlistModel: playlistModel
        }
    }

    Loader {
        id: updateBannerLoader

        active: root.currentPage === "home" && accountModelService.phoneLoggedIn
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(720, root.width - 48)
        z: 900
        sourceComponent: updateBannerComponent
    }

    Component {
        id: updateBannerComponent

        UpdateBanner {}
    }

    // 登录墙：未登录时覆盖整个窗口，必须先登录/注册
    Rectangle {
        visible: !accountModelService.phoneLoggedIn
        anchors.fill: parent
        z: 1000
        color: ui.theme.backgroundPrimaryColor

        Rectangle {
            width: 420
            height: 320
            anchors.centerIn: parent
            radius: 16
            color: ui.theme.backgroundSecondaryColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 14

                StyledTextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTrc("appshell", "登录 / 注册")
                    font: ui.theme.titleBoldFont
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: qsTrc("appshell", "登录后获得 3 天免费试用，未注册手机号将自动注册")
                    font: ui.theme.bodyFont
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledTextLabel {
                        text: qsTrc("appshell", "手机号")
                        font: ui.theme.bodyFont
                    }
                    TextField {
                        id: loginPhoneField
                        Layout.fillWidth: true
                        placeholderText: qsTrc("appshell", "请输入手机号")
                        inputMethodHints: Qt.ImhDigitsOnly
                        onTextEdited: root.loginError = ""
                        onAccepted: loginCodeField.forceActiveFocus()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledTextLabel {
                        text: qsTrc("appshell", "验证码")
                        font: ui.theme.bodyFont
                    }
                    TextField {
                        id: loginCodeField
                        Layout.fillWidth: true
                        placeholderText: qsTrc("appshell", "6位验证码")
                        inputMethodHints: Qt.ImhDigitsOnly
                        onTextEdited: root.loginError = ""
                        onAccepted: root.submitLogin()
                    }
                    FlatButton {
                        text: root.sendCooldown > 0
                              ? (root.sendCooldown + qsTrc("appshell", " 秒后重发"))
                              : qsTrc("appshell", "获取验证码")
                        enabled: !accountModelService.busy && root.sendCooldown === 0
                        onClicked: root.requestLoginCode()
                    }
                }

                StyledTextLabel {
                    visible: root.loginError.length > 0
                             || accountModelService.lastError.length > 0
                             || accountModelService.sendCodeMessage.length > 0
                    Layout.fillWidth: true
                    text: root.loginError.length > 0
                          ? root.loginError
                          : (accountModelService.lastError.length > 0
                             ? accountModelService.lastError
                             : accountModelService.sendCodeMessage)
                    color: accountModelService.sendCodeMessage.length > 0
                           && root.loginError.length === 0
                           && accountModelService.lastError.length === 0
                           ? "#2ECC71"
                           : ui.theme.accentColor
                    font: ui.theme.bodyFont
                    wrapMode: Text.WordWrap
                }

                FlatButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: qsTrc("appshell", "登录 / 注册")
                    accentButton: true
                    enabled: !accountModelService.busy
                    onClicked: root.submitLogin()
                }
            }
        }
    }

    // 会员墙：已登录但未开通会员（含试用）时覆盖整个窗口，必须先开通会员
    Rectangle {
        visible: accountModelService.phoneLoggedIn && !accountModelService.hasProAccess
        anchors.fill: parent
        z: 1001
        color: ui.theme.backgroundPrimaryColor

        Rectangle {
            width: 440
            height: 340
            anchors.centerIn: parent
            radius: 16
            color: ui.theme.backgroundSecondaryColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 14

                StyledTextLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTrc("appshell", "开通会员")
                    font: ui.theme.titleBoldFont
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: qsTrc("appshell", "鼓乐熊Studio 需要开通会员后才能播放曲库与课程。登录即享 3 天免费试用。")
                    font: ui.theme.bodyFont
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                StyledTextLabel {
                    visible: accountModelService.statusText.length > 0
                    Layout.fillWidth: true
                    text: accountModelService.statusText
                    color: ui.theme.accentColor
                    font: ui.theme.bodyFont
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                FlatButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    text: qsTrc("appshell", "开通会员 %1")
                          .arg(accountModelService.renewalPriceText)
                    accentButton: true
                    enabled: !accountModelService.busy
                    onClicked: accountModelService.openPurchasePage()
                }

                FlatButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTrc("appshell", "已开通？刷新状态")
                    transparent: true
                    enabled: !accountModelService.busy
                    onClicked: accountModelService.refresh()
                }

                FlatButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTrc("appshell", "退出登录")
                    transparent: true
                    enabled: !accountModelService.busy
                    onClicked: accountModelService.logout()
                }
            }
        }
    }
}
