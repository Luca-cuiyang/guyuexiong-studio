/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 课程中心（书架 + Part 横向切换书本详情）
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import DBScore.Project

FocusScope {
    id: root

    property int instrument: 0
    property string section: "courses" // courses | special | exam
    property var courseModel: null
    property var songModel: null
    property var favoritesModel: null
    property var selectedCourse: null
    property var selectedLesson: null
    property string selectedCourseId: ""
    property var lastPracticeModel: null
    property var playlistModel: null
    property int selectedPart: 0
    property string preparingLessonTitle: ""
    property string prepareError: ""

    signal playerRequested()

    // 书本尺寸令牌
    readonly property int booksPerRow: 6
    readonly property real bookSpacing: 10

    // 书架宽度按一行 6 本计算，窗口变宽时书会等比变大
    function bookCardWidth(availableWidth) {
        const width = (availableWidth - (root.booksPerRow - 1) * root.bookSpacing - 2) / root.booksPerRow
        return Math.max(104, width)
    }

    onSectionChanged: {
        root.selectedCourse = null
        root.selectedLesson = null
    }

    onInstrumentChanged: {
        root.selectedCourse = null
        root.selectedLesson = null
    }

    Component.onCompleted: {
        if (root.courseModel) {
            root.courseModel.load()
        }
        if (root.songModel) {
            root.songModel.load()
        }
        if (root.favoritesModel) {
            root.favoritesModel.load()
        }
    }

    readonly property var directionIcons: [IconCode.PERCUSSION, IconCode.PERCUSSION,
                                             IconCode.MUSIC_NOTES, IconCode.MUSIC_NOTES,
                                             IconCode.MICROPHONE]
    readonly property var directionColors: ["#F57C00", "#E67E22", "#2980B9", "#8E44AD", "#E74C3C"]

    NavigationSection {
        id: navSec
        name: "CourseCenter"
        enabled: root.enabled && root.visible
        order: 3
        onActiveChanged: {
            if (navSec.active) {
                root.forceActiveFocus()
            }
        }
    }

    // 课程中心直接展示 A/B/C 全部 18 本书；专项/考级仍按各自分类
    function shelfCourses() {
        const result = []
        for (let i = 0; i < courseModel.courses.length; ++i) {
            const course = courseModel.courses[i]
            if (course.instrument !== root.instrument) {
                continue
            }
            if (root.section === "courses") {
                if (course.difficulty >= 0 && course.difficulty <= 2) {
                    result.push(course)
                }
            } else {
                const difficulty = root.section === "special" ? 3 : 4
                if (course.difficulty === difficulty) {
                    result.push(course)
                }
            }
        }
        return result
    }

    function shelfSections() {
        const courses = root.shelfCourses()
        if (root.section !== "courses") {
            const isSpecial = root.section === "special"
            return [{
                "code": isSpecial ? qsTrc("appshell", "专") : qsTrc("appshell", "考"),
                "title": isSpecial ? qsTrc("appshell", "专项课程") : qsTrc("appshell", "考级课程"),
                "color": isSpecial ? "#16A085" : "#2980B9",
                "courses": courses
            }]
        }

        const definitions = [
            {
                "difficulty": 0,
                "code": "A",
                "title": qsTrc("appshell", "A-level【0-3级】"),
                "color": "#F57C00"
            },
            {
                "difficulty": 1,
                "code": "B",
                "title": qsTrc("appshell", "B-level【4-7级】"),
                "color": "#2980B9"
            },
            {
                "difficulty": 2,
                "code": "C",
                "title": qsTrc("appshell", "C-level【8-10级】"),
                "color": "#8E44AD"
            }
        ]

        const result = []
        for (const definition of definitions) {
            result.push({
                "code": definition.code,
                "title": definition.title,
                "color": definition.color,
                "courses": courses.filter(course => course.difficulty === definition.difficulty)
            })
        }
        return result
    }

    function currentPart() {
        const course = root.selectedCourse
        if (!course || !course.chapters || root.selectedPart < 0 || root.selectedPart >= course.chapters.length) {
            return null
        }
        return course.chapters[root.selectedPart]
    }

    function currentPartLessons() {
        const part = root.currentPart()
        return part ? part.lessons : []
    }

    function pad2(value) {
        return value < 10 ? "0" + value : "" + value
    }

    // 从标题里拆出书号与科目：A1册【军鼓课程】 → A1 / 军鼓课程
    function bookCode(course) {
        if (!course || !course.title) {
            return ""
        }
        const index = course.title.indexOf(qsTrc("appshell", "册"))
        return index > 0 ? course.title.substring(0, index) : course.title
    }

    function bookSubject(course) {
        if (!course || !course.title) {
            return ""
        }
        const match = course.title.match(/【(.*?)】/)
        return match ? match[1] : course.title
    }

    function lessonCount(course) {
        let total = 0
        if (course && course.chapters) {
            for (const chapter of course.chapters) {
                total += chapter.lessons.length
            }
        }
        return total
    }

    function partCount(course) {
        return course && course.chapters ? course.chapters.length : 0
    }

    // 每一节课对应一个素材文件夹：与课时 .db 同级，文件夹名取课时名
    function lessonFolderPath(lesson) {
        if (!lesson || !lesson.filePath) {
            return ""
        }
        const path = lesson.filePath
        const slash = path.lastIndexOf("/")
        const parent = slash > 0 ? path.substring(0, slash) : ""
        if (parent.length === 0) {
            return ""
        }
        const safeTitle = (lesson.title || qsTrc("appshell", "课件")).replace(/[\\/:*?"<>|]/g, "-")
        return parent + "/" + safeTitle
    }

    function openLessonFolder(lesson) {
        if (!lesson || !lesson.filePath) {
            if (!lesson || !lesson.id) {
                return
            }
            const course = root.selectedCourse
            root.selectedLesson = null
            root.prepareError = ""
            root.preparingLessonTitle = lesson.title || ""
            root.courseModel.prepareLesson({
                "id": lesson.id,
                "title": lesson.title,
                "style": course ? course.title : "",
                "coverColor": course ? course.coverColor : ui.theme.accentColor,
                "coverPath": course ? (course.coverPath || "") : "",
                "coverUrl": course ? (course.coverUrl || "") : ""
            })
            return
        }

        const course = root.selectedCourse
        root.selectedLesson = {
            "id": lesson.id,
            "title": lesson.title,
            "style": course ? course.title : "",
            "coverColor": course ? course.coverColor : ui.theme.accentColor,
            "coverPath": course ? (course.coverPath || "") : "",
            "coverUrl": course ? (course.coverUrl || "") : "",
            "folder": root.lessonFolderPath(lesson),
            "scorePath": lesson.filePath,
            "scoreName": qsTrc("appshell", "课程鼓谱")
        }
    }

    Connections {
        target: root.courseModel

        function onCoursesChanged() {
            root.refreshSelectedCourse()
        }

        function onLessonReady(lesson) {
            root.preparingLessonTitle = ""
            root.selectedLesson = lesson
        }

        function onLessonPrepareFailed(message) {
            root.preparingLessonTitle = ""
            root.prepareError = message
            prepareErrorTimer.restart()
        }
    }

    Timer {
        id: prepareErrorTimer
        interval: 5000
        onTriggered: root.prepareError = ""
    }

    // 封面更新后刷新当前打开的书本数据，避免详情页仍显示旧封面
    function refreshSelectedCourse() {
        if (!root.selectedCourse) {
            return
        }
        const id = root.selectedCourse.id
        for (let i = 0; i < courseModel.courses.length; ++i) {
            if (courseModel.courses[i].id === id) {
                root.selectedCourse = courseModel.courses[i]
                return
            }
        }
        root.selectedCourse = null
        root.selectedLesson = null
        root.selectedCourseId = ""
    }

    onSelectedCourseChanged: {
        if (!root.selectedCourse || !root.selectedCourse.chapters) {
            root.selectedCourseId = ""
            return
        }

        // 同一本书只是封面数据刷新，不重置当前 Part
        if (root.selectedCourse.id === root.selectedCourseId) {
            return
        }
        root.selectedCourseId = root.selectedCourse.id

        root.selectedPart = 0
    }

    Rectangle {
        anchors.fill: parent
        color: ui.theme.backgroundSecondaryColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        anchors.topMargin: 32
        anchors.bottomMargin: 24
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.selectedCourse === null && root.selectedLesson === null

            StyledTextLabel {
                Layout.fillWidth: true
                text: root.section === "special"
                      ? qsTrc("appshell", "专项训练")
                      : (root.section === "exam" ? qsTrc("appshell", "考级中心") : qsTrc("appshell", "课程中心"))
                font: Qt.font(Object.assign({}, ui.theme.titleBoldFont, { pixelSize: 24 }))
                horizontalAlignment: Text.AlignLeft
            }

            StyledTextLabel {
                Layout.fillWidth: true
                text: qsTrc("appshell", "选择一册课程，像翻书一样开始学习")
                font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 12 }))
                color: ui.theme.fontPrimaryColor
                opacity: 0.55
                horizontalAlignment: Text.AlignLeft
            }
        }

        // 课程内容
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── 书架 ─────────────────────────────
                ScrollView {
                    id: shelfScroll

                    anchors.fill: parent
                    visible: root.selectedCourse === null && root.selectedLesson === null
                    clip: true

                    Column {
                        width: shelfScroll.availableWidth
                        spacing: 26

                        Repeater {
                            model: root.shelfSections()

                            Column {
                                id: sectionColumn

                                required property var modelData

                                width: shelfScroll.availableWidth
                                spacing: 10

                                RowLayout {
                                    width: parent.width
                                    height: 38
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: 9
                                        color: sectionColumn.modelData.color

                                        StyledTextLabel {
                                            anchors.centerIn: parent
                                            text: sectionColumn.modelData.code
                                            font: Qt.font(Object.assign({}, ui.theme.headerBoldFont,
                                                                        { pixelSize: 15, weight: Font.DemiBold }))
                                            color: "#FFFFFF"
                                        }
                                    }

                                    StyledTextLabel {
                                        text: sectionColumn.modelData.title
                                        font: Qt.font(Object.assign({}, ui.theme.headerBoldFont,
                                                                    { pixelSize: 18 }))
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    StyledTextLabel {
                                        text: qsTrc("appshell", "%1 本").arg(sectionColumn.modelData.courses.length)
                                        font: Qt.font(Object.assign({}, ui.theme.bodyFont,
                                                                    { pixelSize: 11 }))
                                        color: sectionColumn.modelData.color
                                    }
                                }

                                Flow {
                                    width: parent.width
                                    spacing: root.bookSpacing

                                    Repeater {
                                        model: sectionColumn.modelData.courses

                                        CourseBookCard {
                                            availableWidth: shelfScroll.availableWidth
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 空状态 ───────────────────────────
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: ui.theme.backgroundPrimaryColor
                    border.width: 1
                    border.color: ui.theme.strokeColor
                    visible: root.selectedCourse === null
                             && root.selectedLesson === null
                             && root.shelfCourses().length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        StyledIconLabel {
                            Layout.alignment: Qt.AlignHCenter
                            iconCode: root.directionIcons[root.instrument]
                            font.pixelSize: 48
                            color: root.directionColors[root.instrument]
                        }

                        StyledTextLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTrc("appshell", "「%1」课程正在制作中，敬请期待")
                                  .arg(courseModel.instrumentNames[root.instrument])
                            font: ui.theme.headerBoldFont
                        }
                    }
                }

                // ── 书本详情（独立整页） ──────────────
                Item {
                    anchors.fill: parent
                    visible: root.selectedCourse !== null && root.selectedLesson === null

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 14

                        // 顶栏
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            FlatButton {
                                icon: IconCode.CHEVRON_LEFT
                                isNarrow: true
                                text: qsTrc("appshell", "返回书架")
                                transparent: true
                                onClicked: root.selectedCourse = null
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            FlatButton {
                                icon: IconCode.IMAGE_MOUNTAINS
                                isNarrow: true
                                text: qsTrc("appshell", "更换封面")
                                transparent: true
                                onClicked: {
                                    courseModel.setCourseCover(root.selectedCourse.id)
                                    root.refreshSelectedCourse()
                                }
                            }
                        }

                        // 书本信息
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 90
                                radius: 6
                                clip: true
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.16)

                                BookCover {
                                    anchors.fill: parent
                                    course: root.selectedCourse
                                    designWidth: 120
                                    showMeta: false
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: root.selectedCourse ? root.selectedCourse.title : ""
                                    font: Qt.font(Object.assign({}, ui.theme.titleBoldFont, { pixelSize: 24 }))
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                }

                                StyledTextLabel {
                                    Layout.fillWidth: true
                                    text: root.selectedCourse ? root.selectedCourse.description : ""
                                    font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 12 }))
                                    color: ui.theme.fontPrimaryColor
                                    opacity: 0.55
                                    horizontalAlignment: Text.AlignLeft
                                }

                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: ui.theme.strokeColor
                            opacity: 0.5
                        }

                        // Part 横向切换 + 当前 Part 课时
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            // Part 横向切换
                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                contentWidth: partChips.width
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Row {
                                    id: partChips
                                    spacing: 8

                                    Repeater {
                                        model: root.selectedCourse ? root.selectedCourse.chapters : []

                                        LibraryChip {
                                            required property var modelData
                                            required property int index

                                            text: modelData.title
                                            checked: root.selectedPart === index
                                            chipHeight: 32
                                            chipFont: ui.theme.bodyFont
                                            onActivated: root.selectedPart = index
                                        }
                                    }
                                }
                            }

                            // 当前 Part 课时
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: ui.theme.backgroundSecondaryColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        StyledTextLabel {
                                            Layout.fillWidth: true
                                            text: root.currentPart() ? root.currentPart().title : ""
                                            font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont, { pixelSize: 15 }))
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideRight
                                        }

                                    }

                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true

                                        ColumnLayout {
                                            width: parent.width
                                            spacing: 2

                                            Repeater {
                                                model: root.currentPartLessons()

                                                delegate: Rectangle {
                                                    id: lessonRow

                                                    required property var modelData
                                                    required property int index

                                                    Layout.fillWidth: true
                                                    height: 42
                                                    radius: 7
                                                    activeFocusOnTab: true
                                                    color: lessonHover.hovered
                                                           ? ui.theme.backgroundPrimaryColor
                                                           : "transparent"
                                                    border.width: activeFocus ? 1 : 0
                                                    border.color: ui.theme.accentColor

                                                    Accessible.role: Accessible.Button
                                                    Accessible.name: lessonRow.modelData.title

                                                    HoverHandler {
                                                        id: lessonHover
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            lessonRow.forceActiveFocus()
                                                            root.openLessonFolder(lessonRow.modelData)
                                                        }
                                                    }

                                                    Keys.onReturnPressed: root.openLessonFolder(lessonRow.modelData)
                                                    Keys.onEnterPressed: root.openLessonFolder(lessonRow.modelData)
                                                    Keys.onSpacePressed: root.openLessonFolder(lessonRow.modelData)

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 6
                                                        spacing: 8

                                                        StyledTextLabel {
                                                            Layout.preferredWidth: 24
                                                            text: root.pad2(lessonRow.index + 1)
                                                            font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 10 }))
                                                            color: ui.theme.fontPrimaryColor
                                                            opacity: 0.35
                                                            horizontalAlignment: Text.AlignRight
                                                        }

                                                        StyledIconLabel {
                                                            iconCode: IconCode.PLAY
                                                            font.pixelSize: 12
                                                            color: ui.theme.accentColor
                                                        }

                                                        StyledTextLabel {
                                                            Layout.fillWidth: true
                                                            text: lessonRow.modelData.title
                                                            font: Qt.font(Object.assign({}, ui.theme.bodyFont, { pixelSize: 12.5 }))
                                                            color: ui.theme.fontPrimaryColor
                                                            horizontalAlignment: Text.AlignLeft
                                                            elide: Text.ElideRight
                                                        }

                                                        FlatButton {
                                                            Layout.preferredWidth: 26
                                                            Layout.preferredHeight: 26
                                                            icon: IconCode.STAR
                                                            isNarrow: true
                                                            accentButton: {
                                                                for (let i = 0; i < favoritesModel.favorites.length; ++i) {
                                                                    if (favoritesModel.favorites[i].id === lessonRow.modelData.id) {
                                                                        return true
                                                                    }
                                                                }
                                                                return false
                                                            }
                                                            transparent: !accentButton
                                                            onClicked: favoritesModel.toggleFavorite(lessonRow.modelData.id,
                                                                                                      lessonRow.modelData.title,
                                                                                                      "lesson",
                                                                                                      lessonRow.modelData.filePath,
                                                                                                      root.selectedCourse
                                                                                                      ? root.selectedCourse.instrument
                                                                                                      : root.instrument)
                                                        }

                                                        FlatButton {
                                                            text: qsTrc("appshell", "打开")
                                                            accentButton: true
                                                            isNarrow: true
                                                            onClicked: root.openLessonFolder(lessonRow.modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 课时素材文件夹（与歌曲素材页一致） ──
                SongFolderView {
                    anchors.fill: parent
                    z: 5
                    visible: root.selectedLesson !== null
                    song: root.selectedLesson
                    songModel: root.songModel
                    courseModel: root.courseModel
                    lastPracticeModel: root.lastPracticeModel
                    playlistModel: root.playlistModel
                    instrument: root.instrument
                    backLabel: qsTrc("appshell", "返回书本")
                    onBackRequested: root.selectedLesson = null
                    onPlayerRequested: root.playerRequested()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 20
        visible: root.preparingLessonTitle.length > 0
        color: Qt.rgba(0, 0, 0, 0.28)

        Rectangle {
            width: 320
            height: 92
            anchors.centerIn: parent
            radius: 14
            color: ui.theme.backgroundPrimaryColor

            Column {
                anchors.centerIn: parent
                spacing: 8

                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    running: parent.parent.parent.visible
                }

                StyledTextLabel {
                    text: qsTrc("appshell", "正在准备 %1").arg(root.preparingLessonTitle)
                    font: ui.theme.bodyBoldFont
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        z: 21
        visible: root.prepareError.length > 0
        width: Math.min(parent.width - 80, errorText.implicitWidth + 36)
        height: 42
        radius: 10
        color: "#B3261E"

        StyledTextLabel {
            id: errorText
            anchors.centerIn: parent
            text: root.prepareError
            color: "#FFFFFF"
            font: ui.theme.bodyFont
        }
    }

    component CourseBookCard: Column {
        id: bookCard

        required property var modelData
        property real availableWidth: 0

        readonly property var courseData: modelData
        readonly property real cardWidth: root.bookCardWidth(availableWidth)

        width: cardWidth
        spacing: 8

        Rectangle {
            id: cover

            width: bookCard.cardWidth
            // Course covers are authored as 3840 × 2880 (4K, 4:3 landscape).
            height: bookCard.cardWidth * 3 / 4
            radius: 8
            clip: true
            activeFocusOnTab: true
            color: "transparent"
            border.width: 1
            border.color: coverHover.hovered || activeFocus
                          ? ui.theme.accentColor
                          : Qt.rgba(0, 0, 0, 0.18)

            Accessible.role: Accessible.Button
            Accessible.name: bookCard.courseData ? bookCard.courseData.title : ""

            HoverHandler {
                id: coverHover
            }

            BookCover {
                anchors.fill: parent
                course: bookCard.courseData
                designWidth: bookCard.cardWidth
                showMeta: true
            }

            FlatButton {
                z: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 8
                width: 26
                height: 26
                icon: IconCode.IMAGE_MOUNTAINS
                iconColor: "#FFFFFF"
                normalColor: Qt.rgba(0, 0, 0, 0.32)
                hoverHitColor: Qt.rgba(0, 0, 0, 0.55)
                backgroundRadius: 13
                toolTipTitle: qsTrc("appshell", "上传书本封面")
                onClicked: {
                    if (bookCard.courseData) {
                        courseModel.setCourseCover(bookCard.courseData.id)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    cover.forceActiveFocus()
                    root.selectedCourse = bookCard.courseData
                }
            }

            Keys.onReturnPressed: root.selectedCourse = bookCard.courseData
            Keys.onEnterPressed: root.selectedCourse = bookCard.courseData
            Keys.onSpacePressed: root.selectedCourse = bookCard.courseData
        }

        StyledTextLabel {
            width: bookCard.cardWidth
            text: bookCard.courseData ? bookCard.courseData.title : ""
            font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                        { pixelSize: Math.max(10, bookCard.cardWidth * 0.075) }))
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }
    }

    // 书本封面：有自定义封面时只渲染图片，完全不再叠加原生封面内容
    component BookCover: Item {
        id: bookCover

        property var course: null
        property real designWidth: 130
        property bool showMeta: true

        readonly property bool hasCustomCover: course && Boolean(course.coverUrl || course.coverPath)
        readonly property color baseColor: course && course.coverColor ? course.coverColor : ui.theme.accentColor
        readonly property int decodeWidth: Math.max(240, Math.ceil(designWidth * 2))

        Loader {
            anchors.fill: parent
            sourceComponent: bookCover.hasCustomCover ? customCoverComponent : generatedCoverComponent
        }

        Component {
            id: customCoverComponent

            Image {
                source: bookCover.course ? bookCover.course.coverUrl : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                sourceSize.width: bookCover.decodeWidth
                sourceSize.height: Math.round(bookCover.decodeWidth * 3 / 4)
            }
        }

        Component {
            id: generatedCoverComponent

            Item {
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.lighter(bookCover.baseColor, 1.18)
                        }
                        GradientStop {
                            position: 1.0
                            color: Qt.darker(bookCover.baseColor, 1.35)
                        }
                    }
                }

                Rectangle {
                    width: Math.max(4, bookCover.designWidth * 0.045)
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    color: Qt.rgba(0, 0, 0, 0.16)
                }

                Rectangle {
                    x: Math.max(4, bookCover.designWidth * 0.045)
                    width: 1
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: Qt.rgba(1, 1, 1, 0.14)
                }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Math.max(10, bookCover.designWidth * 0.11)
                    anchors.rightMargin: 8
                    anchors.topMargin: Math.max(8, bookCover.designWidth * 0.06)
                    anchors.bottomMargin: 10
                    spacing: 3

                    StyledTextLabel {
                        Layout.fillWidth: true
                        text: root.bookCode(bookCover.course)
                        font: Qt.font(Object.assign({}, ui.theme.titleBoldFont,
                                                    { pixelSize: Math.max(14, bookCover.designWidth * 0.145) }))
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledTextLabel {
                        Layout.fillWidth: true
                        text: root.bookSubject(bookCover.course)
                        font: Qt.font(Object.assign({}, ui.theme.bodyBoldFont,
                                                    { pixelSize: Math.max(10, bookCover.designWidth * 0.088) }))
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    StyledTextLabel {
                        Layout.fillWidth: true
                        visible: bookCover.showMeta
                        text: bookCover.course && bookCover.course.description
                              ? bookCover.course.description
                              : ""
                        font: Qt.font(Object.assign({}, ui.theme.bodyFont,
                                                    { pixelSize: Math.max(8, bookCover.designWidth * 0.062) }))
                        color: "#FFFFFF"
                        opacity: 0.65
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledTextLabel {
                        Layout.fillWidth: true
                        visible: bookCover.showMeta
                        text: qsTrc("appshell", "%1 个部分 · %2 课")
                              .arg(root.partCount(bookCover.course))
                              .arg(root.lessonCount(bookCover.course))
                        font: Qt.font(Object.assign({}, ui.theme.bodyFont,
                                                    { pixelSize: Math.max(8, bookCover.designWidth * 0.058) }))
                        color: "#FFFFFF"
                        opacity: 0.7
                        horizontalAlignment: Text.AlignLeft
                    }

                }
            }
        }
    }
}
