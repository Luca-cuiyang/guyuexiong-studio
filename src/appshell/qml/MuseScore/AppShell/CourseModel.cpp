/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 后台课程中心数据模型
 */
#include "CourseModel.h"

#include <QDir>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

#include <memory>

#include "settings.h"

using namespace mu::appshell;
using namespace muse;

namespace {
static const Settings::Key COURSE_COVERS_KEY("appshell", "dbstudio/courses/covers");

QString safeFileName(const QString& name)
{
    QString result = QFileInfo(name).fileName().trimmed();
    result.replace(QRegularExpression(QStringLiteral(R"([\\/:*?"<>|\x00-\x1f])")),
                   QStringLiteral("-"));
    while (result.startsWith(QLatin1Char('.'))) {
        result.remove(0, 1);
    }
    return result.isEmpty() ? QStringLiteral("file") : result;
}

QString sha256ForFile(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    while (!file.atEnd()) {
        const QByteArray chunk = file.read(1024 * 1024);
        if (chunk.isEmpty() && file.error() != QFileDevice::NoError) {
            return QString();
        }
        hash.addData(chunk);
    }
    return QString::fromLatin1(hash.result().toHex());
}

bool cachedFileMatches(const QString& path, qint64 expectedSize, const QString& expectedSha256)
{
    const QFileInfo file(path);
    if (!file.isFile() || (expectedSize > 0 && file.size() != expectedSize)) {
        return false;
    }
    return expectedSha256.isEmpty() || sha256ForFile(path) == expectedSha256;
}

QUrl resolveServiceUrl(const QString& rawUrl, const QString& apiBaseUrl)
{
    QUrl url(rawUrl);
    if (url.isRelative() && !rawUrl.startsWith(QStringLiteral("//"))) {
        QString path = rawUrl;
        if (!path.startsWith(QLatin1Char('/'))) {
            path.prepend(QLatin1Char('/'));
        }
        url = QUrl(apiBaseUrl).resolved(QUrl(path));
    }
    return url;
}
}

CourseModel::CourseModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
    m_networkManager = new QNetworkAccessManager(this);
    authorization()->stateChanged().onNotify(this, [this]() {
        if (!authorization()->isPhoneLoggedIn()) {
            m_loaded = false;
            m_courses.clear();
            clearContentCache();
            setError(QString());
            emit coursesChanged();
            return;
        }

        m_loaded = false;
        load();
    });
}

CourseModel::~CourseModel() = default;

QVariantList CourseModel::courses() const
{
    return m_courses;
}

QStringList CourseModel::instrumentNames() const
{
    return {
        QStringLiteral("架子鼓"),
        QStringLiteral("非洲鼓"),
        QStringLiteral("吉他弹唱"),
        QStringLiteral("少儿乐队"),
        QStringLiteral("声乐课程")
    };
}

bool CourseModel::loading() const
{
    return m_loading;
}

bool CourseModel::preparingLesson() const
{
    return m_preparingLesson;
}

QString CourseModel::error() const
{
    return m_error;
}

void CourseModel::setLoading(bool value)
{
    if (m_loading == value) {
        return;
    }
    m_loading = value;
    emit loadingChanged();
}

void CourseModel::setPreparingLesson(bool value)
{
    if (m_preparingLesson == value) {
        return;
    }
    m_preparingLesson = value;
    emit preparingLessonChanged();
}

void CourseModel::setError(const QString& value)
{
    if (m_error == value) {
        return;
    }
    m_error = value;
    emit errorChanged();
}

void CourseModel::load()
{
    if (m_loaded || m_loading) {
        return;
    }
    if (!authorization()->isPhoneLoggedIn()) {
        setError(QStringLiteral("请先登录鼓乐熊Studio 账号。"));
        return;
    }

    setLoading(true);
    setError(QString());
    authorization()->accountGet(
        QStringLiteral("/api/customer/courses?productCode=db-studio&subjectCode=drums"))
    .onResolve(this, [this](const RetVal<QVariantMap>& result) {
        setLoading(false);
        if (!result.ret) {
            setError(QString::fromStdString(result.ret.text()));
            return;
        }
        parseCourses(result.val);
        m_loaded = true;
    });
}

void CourseModel::refresh()
{
    if (m_loading
            || (m_lastRefresh.isValid() && m_lastRefresh.elapsed() < 2000)) {
        return;
    }
    m_lastRefresh.restart();
    m_loaded = false;
    load();
}

void CourseModel::parseCourses(const QVariantMap& response)
{
    const QJsonArray source = QJsonArray::fromVariantList(response.value("courses").toList());
    const QJsonObject covers = loadCourseCovers();
    QVariantList courses;
    courses.reserve(source.size());

    for (const QJsonValue& value : source) {
        QVariantMap course = value.toObject().toVariantMap();
        const QString courseID = course.value("id").toString();
        const QString coverPath = covers.value(courseID).toString();
        if (!coverPath.isEmpty() && QFileInfo::exists(coverPath)) {
            course["coverPath"] = coverPath;
            course["coverUrl"] = QUrl::fromLocalFile(coverPath).toString();
        } else {
            const QString remoteCoverUrl = course.value("coverUrl").toString();
            if (!remoteCoverUrl.isEmpty()) {
                course["coverUrl"] = resolveServiceUrl(
                    remoteCoverUrl,
                    authorization()->apiBaseUrl()).toString();
            }
        }
        courses.append(course);
    }

    m_courses = courses;
    emit coursesChanged();
}

void CourseModel::prepareLesson(const QVariantMap& lesson)
{
    const QString lessonID = lesson.value("id").toString();
    if (lessonID.isEmpty() || m_preparingLesson) {
        return;
    }

    if (!authorization()->isPhoneLoggedIn()) {
        const QString message = QStringLiteral("请先登录鼓乐熊Studio 账号。");
        setError(message);
        emit lessonPrepareFailed(message);
        return;
    }

    m_pendingLesson = lesson;
    setPreparingLesson(true);
    setError(QString());
    authorization()->accountGet(
        QStringLiteral("/api/customer/lessons/%1/manifest?productCode=db-studio").arg(lessonID))
    .onResolve(this, [this](const RetVal<QVariantMap>& result) {
        if (!result.ret) {
            const QString message = QString::fromStdString(result.ret.text());
            setPreparingLesson(false);
            setError(message);
            emit lessonPrepareFailed(message);
            return;
        }
        finishLesson(m_pendingLesson, result.val);
    });
}

void CourseModel::finishLesson(const QVariantMap& source, const QVariantMap& manifest)
{
    const QVariantMap score = manifest.value("score").toMap();
    if (score.value("url").toString().isEmpty()) {
        const QString message = QStringLiteral("该课件没有已发布的鼓谱。");
        setPreparingLesson(false);
        setError(message);
        emit lessonPrepareFailed(message);
        return;
    }

    QString folder = cacheRoot() + QStringLiteral("/lesson-")
                     + source.value("id").toString();
    const QString version = manifest.value("version").toString();
    if (!version.isEmpty()) {
        folder += QLatin1Char('-') + version;
    }
    if (!QDir().mkpath(folder)) {
        const QString message = QStringLiteral("无法创建课件缓存目录。");
        setPreparingLesson(false);
        setError(message);
        emit lessonPrepareFailed(message);
        return;
    }

    QVariantList files;
    files.append(score);
    const QVariantList assets = manifest.value("assets").toList();
    for (const QVariant& asset : assets) {
        files.append(asset.toMap());
    }
    downloadFiles(files, 0, folder);
}

void CourseModel::downloadFiles(
    const QVariantList& files,
    int index,
    const QString& folder,
    int attempt)
{
    if (index >= files.size()) {
        emit contentChanged(folder);
        return;
    }

    const QVariantMap file = files.at(index).toMap();
    const QString filename = safeFileName(file.value("filename").toString());
    const QString targetPath = folder + QLatin1Char('/') + filename;
    const qint64 expectedSize = file.value("size").toLongLong();
    const QString expectedSha256 = file.value("sha256").toString().toLower();
    if (cachedFileMatches(targetPath, expectedSize, expectedSha256)) {
        if (index == 0) {
            m_pendingLesson["scoreFilename"] = filename;
            completePreparedLesson(folder);
        }
        downloadFiles(files, index + 1, folder);
        return;
    }

    QUrl fileUrl(file.value("url").toString());
    if (fileUrl.isRelative()) {
        QString relativePath = file.value("url").toString();
        if (!relativePath.startsWith(QLatin1Char('/'))) {
            relativePath.prepend(QLatin1Char('/'));
        }
        fileUrl = QUrl(authorization()->apiBaseUrl()).resolved(QUrl(relativePath));
    }
    if (!fileUrl.isValid()
            || (fileUrl.scheme() != QStringLiteral("https")
                && fileUrl.scheme() != QStringLiteral("http"))) {
        const QString message = QStringLiteral("课件素材地址无效：%1").arg(filename);
        if (index == 0) {
            setPreparingLesson(false);
            setError(message);
            emit lessonPrepareFailed(message);
        } else {
            setError(message);
            downloadFiles(files, index + 1, folder);
        }
        return;
    }

    QNetworkRequest request(fileUrl);
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("User-Agent", "DBStudio/5.0.1");
    request.setRawHeader("Accept-Encoding", "identity");
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                         QNetworkRequest::AlwaysNetwork);
    QNetworkReply* reply = m_networkManager->get(request);
    auto output = std::make_shared<QSaveFile>(targetPath);
    if (!output->open(QIODevice::WriteOnly)) {
        reply->abort();
        reply->deleteLater();
        const QString message = QStringLiteral("无法写入课件缓存：%1").arg(filename);
        if (index == 0) {
            setPreparingLesson(false);
            setError(message);
            emit lessonPrepareFailed(message);
        } else {
            setError(message);
            downloadFiles(files, index + 1, folder);
        }
        return;
    }

    connect(reply, &QNetworkReply::readyRead, this, [reply, output]() {
        if (output->write(reply->readAll()) < 0) {
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, output, files, index, folder, filename, targetPath, expectedSize,
             expectedSha256, attempt]() {
        output->write(reply->readAll());
        const int httpStatus =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString networkError = reply->errorString();
        const bool validResponse =
            reply->error() == QNetworkReply::NoError
            && (httpStatus == 0 || httpStatus == 200);
        const bool sizeMismatch =
            validResponse && expectedSize > 0 && output->size() != expectedSize;
        bool saved = validResponse && !sizeMismatch && output->commit();
        bool hashMismatch = false;
        if (saved && !expectedSha256.isEmpty()) {
            hashMismatch = sha256ForFile(targetPath) != expectedSha256;
            saved = !hashMismatch;
        }
        reply->deleteLater();

        if (!saved) {
            output->cancelWriting();
            QFile::remove(output->fileName());
            const bool retryable = attempt < 2
                                   && (sizeMismatch
                                       || hashMismatch
                                       || httpStatus == 0
                                       || httpStatus == 408
                                       || httpStatus == 425
                                       || httpStatus == 429
                                       || httpStatus >= 500);
            if (retryable) {
                QTimer::singleShot(500 * (attempt + 1), this,
                                   [this, files, index, folder, attempt]() {
                    downloadFiles(files, index, folder, attempt + 1);
                });
                return;
            }

            const QString detail = httpStatus > 0
                                   ? QStringLiteral("（HTTP %1）").arg(httpStatus)
                                   : QStringLiteral("（%1）").arg(networkError);
            const QString message =
                QStringLiteral("课件素材下载失败：%1%2").arg(filename, detail);
            if (index == 0) {
                setPreparingLesson(false);
                setError(message);
                emit lessonPrepareFailed(message);
            } else {
                setError(message);
                downloadFiles(files, index + 1, folder, 0);
            }
            return;
        }
        if (index == 0) {
            m_pendingLesson["scoreFilename"] = filename;
            completePreparedLesson(folder);
        } else {
            emit contentChanged(folder);
        }
        downloadFiles(files, index + 1, folder, 0);
    });
}

void CourseModel::completePreparedLesson(const QString& folder)
{
    if (!m_preparingLesson) {
        return;
    }

    const QVariantMap source = m_pendingLesson;
    const QString scoreFilename = source.value("scoreFilename").toString();
    const QString scorePath = folder + QLatin1Char('/') + scoreFilename;
    if (scoreFilename.isEmpty() || !QFileInfo::exists(scorePath)) {
        const QString message = QStringLiteral("课件鼓谱缓存失败。");
        setPreparingLesson(false);
        setError(message);
        emit lessonPrepareFailed(message);
        return;
    }

    QVariantMap lesson;
    lesson["id"] = QStringLiteral("course-") + source.value("id").toString();
    lesson["title"] = source.value("title");
    lesson["style"] = source.value("style");
    lesson["coverColor"] = source.value("coverColor");
    lesson["coverPath"] = source.value("coverPath");
    lesson["coverUrl"] = source.value("coverUrl");
    lesson["folder"] = folder;
    lesson["scorePath"] = scorePath;
    lesson["scoreName"] = QStringLiteral("课程鼓谱");

    setPreparingLesson(false);
    m_pendingLesson.clear();
    emit lessonReady(lesson);
}

QString CourseModel::cacheRoot() const
{
    QString root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (root.isEmpty()) {
        root = QDir::homePath() + QStringLiteral("/Library/Application Support/DBScore/DBStudio5");
    }
    return root + QStringLiteral("/dbstudio/content");
}

void CourseModel::clearContentCache()
{
    QDir(cacheRoot()).removeRecursively();
}

QJsonObject CourseModel::loadCourseCovers() const
{
    const QString raw = settings()->value(COURSE_COVERS_KEY).toQString();
    return QJsonDocument::fromJson(raw.toUtf8()).object();
}

void CourseModel::saveCourseCovers(const QJsonObject& covers) const
{
    const QString raw = QString::fromUtf8(QJsonDocument(covers).toJson(QJsonDocument::Compact));
    settings()->setSharedValue(COURSE_COVERS_KEY, Val(raw.toStdString()));
}

void CourseModel::setCourseCover(const QString& courseId)
{
    if (courseId.isEmpty()) {
        return;
    }

    const muse::io::paths_t paths = interactive()->selectOpeningFilesSync(
        "选择书本封面",
        muse::io::path_t(),
        { "图片 (*.png *.jpg *.jpeg *.webp *.bmp *.heic *.tif *.tiff)" });
    if (paths.empty()) {
        return;
    }

    const QString sourcePath = paths.front().toQString();
    const QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.isFile()) {
        return;
    }

    QDir coverDir(cacheRoot() + QStringLiteral("/covers"));
    if (!coverDir.mkpath(QStringLiteral("."))) {
        return;
    }

    const QString targetPath = coverDir.absoluteFilePath(
        courseId + QLatin1Char('.') + sourceInfo.suffix().toLower());
    const QString temporaryPath = targetPath + QStringLiteral(".tmp");
    QFile::remove(temporaryPath);
    if (!QFile::copy(sourcePath, temporaryPath)) {
        return;
    }
    if (QFileInfo::exists(targetPath)) {
        QFile::remove(targetPath);
    }
    if (!QFile::rename(temporaryPath, targetPath)) {
        QFile::remove(temporaryPath);
        return;
    }

    QJsonObject covers = loadCourseCovers();
    covers[courseId] = targetPath;
    saveCourseCovers(covers);
    for (QVariant& value : m_courses) {
        QVariantMap course = value.toMap();
        if (course.value("id").toString() != courseId) {
            continue;
        }
        course["coverPath"] = targetPath;
        course["coverUrl"] = QUrl::fromLocalFile(targetPath).toString();
        value = course;
        break;
    }
    emit coursesChanged();
}
