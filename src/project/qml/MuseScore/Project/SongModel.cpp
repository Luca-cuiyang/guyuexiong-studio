/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 曲库数据模型（一个 .db 对应一首歌曲）
 */
#include "SongModel.h"

#include <QDesktopServices>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

#include <memory>

#include "settings.h"

using namespace mu::project;
using namespace muse;

namespace {
static const Settings::Key IMPORTED_SONGS_KEY("dbstudio", "library/importedSongs");

const QStringList& songLevelNames()
{
    static const QStringList names {
        QStringLiteral("预备级"),
        QStringLiteral("一级"),
        QStringLiteral("二级"),
        QStringLiteral("三级"),
        QStringLiteral("四级"),
        QStringLiteral("五级"),
        QStringLiteral("六级"),
        QStringLiteral("七级"),
        QStringLiteral("八级"),
        QStringLiteral("九级"),
        QStringLiteral("十级"),
        QStringLiteral("十一&专业级"),
        QStringLiteral("比赛级")
    };
    return names;
}

int songLevelFromJson(const QJsonObject& obj)
{
    const QJsonValue value = obj.value("level");
    int level = -1;
    bool numeric = false;
    if (value.isDouble()) {
        level = value.toInt(-1);
        numeric = true;
    } else if (value.isString()) {
        level = value.toString().toInt(&numeric);
    }
    if (numeric && level >= 0 && level < songLevelNames().size()) {
        return level;
    }

    QString levelName = obj.value("levelName").toString().trimmed();
    if (levelName.isEmpty() && value.isString()) {
        levelName = value.toString().trimmed();
    }
    return levelName.isEmpty() ? -1 : songLevelNames().indexOf(levelName);
}

QVariantMap makeSong(const QString& id, const QString& title, int instrument, const QString& style,
                     const QString& coverColor, const QString& folder, const QString& scorePath,
                     const QString& scoreName, int level, const QStringList& collections)
{
    QVariantMap song;
    song["id"] = id;
    song["title"] = title;
    song["instrument"] = instrument;
    song["style"] = style;
    song["coverColor"] = coverColor;
    song["folder"] = folder;
    song["scorePath"] = scorePath;
    song["scoreName"] = scoreName;
    song["level"] = level;
    song["collections"] = collections;
    return song;
}

QString fileTypeForSuffix(const QString& suffix)
{
    static const QSet<QString> imageSuffixes = {
        "png", "jpg", "jpeg", "webp", "bmp", "gif", "heic", "tif", "tiff"
    };
    static const QSet<QString> audioSuffixes = {
        "mp3", "wav", "m4a", "aac", "ogg", "flac", "aiff", "aif"
    };
    static const QSet<QString> videoSuffixes = {
        "mp4", "mov", "m4v", "avi", "mkv", "webm"
    };
    static const QSet<QString> documentSuffixes = {
        "pdf", "doc", "docx", "txt", "rtf", "md"
    };
    static const QSet<QString> slidesSuffixes = {
        "ppt", "pptx", "key"
    };

    if (suffix == "db") {
        return QStringLiteral("score");
    }
    if (imageSuffixes.contains(suffix)) {
        return QStringLiteral("image");
    }
    if (audioSuffixes.contains(suffix)) {
        return QStringLiteral("audio");
    }
    if (videoSuffixes.contains(suffix)) {
        return QStringLiteral("video");
    }
    if (documentSuffixes.contains(suffix)) {
        return QStringLiteral("document");
    }
    if (slidesSuffixes.contains(suffix)) {
        return QStringLiteral("slides");
    }
    return QStringLiteral("other");
}

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

bool isProtectedUserLocation(const QString& path)
{
#if defined(Q_OS_MACOS) || defined(Q_OS_MAC)
    const QString candidate = QDir::cleanPath(path);
    const QList<QStandardPaths::StandardLocation> locations {
        QStandardPaths::DesktopLocation,
        QStandardPaths::DocumentsLocation,
        QStandardPaths::DownloadLocation
    };
    for (const QStandardPaths::StandardLocation location : locations) {
        const QString root = QDir::cleanPath(QStandardPaths::writableLocation(location));
        if (!root.isEmpty()
                && (candidate == root || candidate.startsWith(root + QLatin1Char('/')))) {
            return true;
        }
    }
#else
    UNUSED(path);
#endif
    return false;
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
}

SongModel::SongModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
    m_networkManager = new QNetworkAccessManager(this);
    authorization()->stateChanged().onNotify(this, [this]() {
        m_loaded = false;
        if (authorization()->isPhoneLoggedIn()) {
            load();
            return;
        }
        m_songs = m_importedSongs;
        clearContentCache();
        setError(QString());
        emit songsChanged();
    });
}

SongModel::~SongModel() = default;

QVariantList SongModel::songs() const
{
    return m_songs;
}

QStringList SongModel::levelNames() const
{
    return songLevelNames();
}

bool SongModel::loading() const
{
    return m_loading;
}

bool SongModel::preparing() const
{
    return m_preparing;
}

QString SongModel::error() const
{
    return m_error;
}

void SongModel::setLoading(bool value)
{
    if (m_loading == value) {
        return;
    }
    m_loading = value;
    emit loadingChanged();
}

void SongModel::setPreparing(bool value)
{
    if (m_preparing == value) {
        return;
    }
    m_preparing = value;
    emit preparingChanged();
}

void SongModel::setError(const QString& value)
{
    if (m_error == value) {
        return;
    }
    m_error = value;
    emit errorChanged();
}

void SongModel::load()
{
    if (m_loaded || m_loading) {
        return;
    }

    if (m_importedSongs.isEmpty()) {
        m_importedSongs = loadImportedSongs();
    }
    if (m_songs.isEmpty()) {
        m_songs = m_importedSongs;
        emit songsChanged();
    }

    if (!authorization()->isPhoneLoggedIn()) {
        setError(QStringLiteral("请先登录鼓乐熊Studio 账号。"));
        return;
    }

    setLoading(true);
    setError(QString());
    authorization()->accountGet(
        QStringLiteral("/api/customer/library?productCode=db-studio&subjectCode=drums"))
    .onResolve(this, [this](const RetVal<QVariantMap>& result) {
        setLoading(false);
        if (!result.ret) {
            setError(QString::fromStdString(result.ret.text()));
            return;
        }
        appendRemoteSongs(result.val);
        m_loaded = true;
    });
}

void SongModel::refresh()
{
    if (m_loading
            || (m_lastRefresh.isValid() && m_lastRefresh.elapsed() < 2000)) {
        return;
    }
    m_lastRefresh.restart();
    m_loaded = false;
    m_importedSongs = loadImportedSongs();
    load();
}

void SongModel::appendRemoteSongs(const QVariantMap& response)
{
    QVariantList songs = m_importedSongs;
    QSet<QString> ids;
    for (const QVariant& value : songs) {
        ids.insert(value.toMap().value("id").toString());
    }
    for (const QVariant& value : response.value("songs").toList()) {
        const QVariantMap song = value.toMap();
        const QString id = song.value("id").toString();
        if (id.isEmpty() || ids.contains(id)) {
            continue;
        }
        ids.insert(id);
        songs.append(song);
    }
    m_songs = songs;
    emit songsChanged();
}

void SongModel::prepareSong(const QVariantMap& song)
{
    if (m_preparing) {
        return;
    }
    if (!song.value("scorePath").toString().isEmpty()
        && QFileInfo::exists(song.value("scorePath").toString())) {
        emit songReady(song);
        return;
    }

    const QString lessonID = song.value("lessonId").toString();
    if (lessonID.isEmpty()) {
        emit songReady(song);
        return;
    }
    if (!authorization()->isPhoneLoggedIn()) {
        const QString message = QStringLiteral("请先登录鼓乐熊Studio 账号。");
        setError(message);
        emit songPrepareFailed(message);
        return;
    }

    m_pendingSong = song;
    setPreparing(true);
    setError(QString());
    authorization()->accountGet(
        QStringLiteral("/api/customer/lessons/%1/manifest?productCode=db-studio").arg(lessonID))
    .onResolve(this, [this](const RetVal<QVariantMap>& result) {
        if (!result.ret) {
            const QString message = QString::fromStdString(result.ret.text());
            setPreparing(false);
            setError(message);
            emit songPrepareFailed(message);
            return;
        }
        finishSong(m_pendingSong, result.val);
    });
}

void SongModel::finishSong(const QVariantMap& source, const QVariantMap& manifest)
{
    const QVariantMap score = manifest.value("score").toMap();
    if (score.value("url").toString().isEmpty()) {
        const QString message = QStringLiteral("该曲目没有已发布的鼓谱。");
        setPreparing(false);
        setError(message);
        emit songPrepareFailed(message);
        return;
    }

    QString folder = cacheRoot() + QStringLiteral("/song-")
                     + source.value("lessonId").toString();
    const QString version = manifest.value("version").toString();
    if (!version.isEmpty()) {
        folder += QLatin1Char('-') + version;
    }
    if (!QDir().mkpath(folder)) {
        const QString message = QStringLiteral("无法创建曲目缓存目录。");
        setPreparing(false);
        setError(message);
        emit songPrepareFailed(message);
        return;
    }

    QVariantList files;
    files.append(score);
    for (const QVariant& asset : manifest.value("assets").toList()) {
        files.append(asset.toMap());
    }
    downloadFiles(files, 0, folder);
}

void SongModel::completePreparedSong(const QString& folder)
{
    if (!m_preparing) {
        return;
    }

    const QVariantMap source = m_pendingSong;
    const QString scoreFilename = source.value("scoreFilename").toString();
    const QString scorePath = folder + QLatin1Char('/') + scoreFilename;
    if (scoreFilename.isEmpty() || !QFileInfo::exists(scorePath)) {
        const QString message = QStringLiteral("曲目鼓谱缓存失败。");
        setPreparing(false);
        setError(message);
        emit songPrepareFailed(message);
        return;
    }

    QVariantMap song = source;
    song["folder"] = folder;
    song["scorePath"] = scorePath;
    setPreparing(false);
    m_pendingSong.clear();
    emit songReady(song);
}

void SongModel::downloadFiles(
    const QVariantList& files,
    int index,
    const QString& folder,
    int attempt)
{
    if (index >= files.size()) {
        emit contentChanged(folder);
        return;
    }
    if (index == 0 && !m_preparing) {
        return;
    }

    const QVariantMap file = files.at(index).toMap();
    const QString filename = safeFileName(file.value("filename").toString());
    const QString targetPath = folder + QLatin1Char('/') + filename;
    const qint64 expectedSize = file.value("size").toLongLong();
    const QString expectedSha256 = file.value("sha256").toString().toLower();
    if (cachedFileMatches(targetPath, expectedSize, expectedSha256)) {
        if (index == 0) {
            m_pendingSong["scoreFilename"] = filename;
            completePreparedSong(folder);
        } else {
            emit contentChanged(folder);
        }
        downloadFiles(files, index + 1, folder, 0);
        return;
    }

    const QUrl fileUrl = resolveServiceUrl(
        file.value("url").toString(), authorization()->apiBaseUrl());
    if (!fileUrl.isValid()
            || (fileUrl.scheme() != QStringLiteral("https")
                && fileUrl.scheme() != QStringLiteral("http"))) {
        const QString message = QStringLiteral("曲目素材地址无效：%1").arg(filename);
        if (index == 0) {
            setPreparing(false);
            setError(message);
            emit songPrepareFailed(message);
        } else {
            setError(message);
            downloadFiles(files, index + 1, folder, 0);
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
        const QString message = QStringLiteral("无法写入曲目缓存：%1").arg(filename);
        if (index == 0) {
            setPreparing(false);
            setError(message);
            emit songPrepareFailed(message);
        } else {
            setError(message);
            downloadFiles(files, index + 1, folder, 0);
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
                QStringLiteral("曲目素材下载失败：%1%2").arg(filename, detail);
            if (index == 0) {
                setPreparing(false);
                setError(message);
                emit songPrepareFailed(message);
            } else {
                setError(message);
                downloadFiles(files, index + 1, folder, 0);
            }
            return;
        }
        if (index == 0) {
            m_pendingSong["scoreFilename"] = filename;
            completePreparedSong(folder);
        }
        downloadFiles(files, index + 1, folder, 0);
    });
}

QString SongModel::cacheRoot() const
{
    QString root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (root.isEmpty()) {
        root = QDir::homePath() + QStringLiteral("/Library/Application Support/DBScore/DBStudio5");
    }
    return root + QStringLiteral("/dbstudio/content");
}

void SongModel::clearContentCache()
{
    QDir(cacheRoot()).removeRecursively();
}

bool SongModel::openScore(const QString& filePath, const QString& title)
{
    if (filePath.isEmpty()) {
        return false;
    }

    if (QFileInfo(filePath).suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0) {
        toastService()->showError(std::string("无法打开鼓谱"),
                                  std::string("鼓乐熊Studio 仅支持 DB Score 导出的 .db 文件"));
        return false;
    }

    if (!QFileInfo::exists(filePath)) {
        toastService()->showError(std::string("无法打开鼓谱"),
                                  std::string("谱面文件不存在或已被移动"));
        return false;
    }

    dispatcher()->dispatch(
        "file-open",
        muse::actions::ActionData::make_arg2<QUrl, QString>(QUrl::fromLocalFile(filePath), title));
    return true;
}

QVariantList SongModel::listFiles(const QString& folder) const
{
    QVariantList result;

    if (folder.isEmpty()) {
        return result;
    }

    const QDir dir(folder);
    if (!dir.exists()) {
        return result;
    }

    const QFileInfoList entries = dir.entryInfoList(QDir::Files | QDir::Readable | QDir::NoDotAndDotDot,
                                                    QDir::Name);

    for (const QFileInfo& info : entries) {
        if (info.fileName().startsWith('.')) {
            continue;
        }

        const QString suffix = info.suffix().toLower();
        QVariantMap entry;
        entry["name"] = info.fileName();
        entry["baseName"] = info.completeBaseName();
        entry["path"] = info.absoluteFilePath();
        entry["url"] = QUrl::fromLocalFile(info.absoluteFilePath()).toString();
        entry["suffix"] = suffix;
        entry["size"] = static_cast<qlonglong>(info.size());
        entry["type"] = fileTypeForSuffix(suffix);
        result.append(entry);
    }

    return result;
}

void SongModel::openFileExternally(const QString& path) const
{
    if (path.isEmpty()) {
        return;
    }

    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

int SongModel::importFilesToFolder(const QString& folder)
{
    if (folder.isEmpty()) {
        return 0;
    }

    const std::vector<std::string> filter {
        std::string("所有文件") + " (*)"
    };

    const muse::io::paths_t paths = interactive()->selectOpeningFilesSync(
        std::string("导入文件"), muse::io::path_t(), filter);

    if (paths.empty()) {
        return 0;
    }

    QDir dir(folder);
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        toastService()->showError(std::string("导入文件"), std::string("无法创建歌曲素材文件夹"));
        return 0;
    }

    int imported = 0;
    for (const muse::io::path_t& path : paths) {
        const QString sourcePath = path.toQString();
        const QFileInfo sourceInfo(sourcePath);
        if (!sourceInfo.exists() || !sourceInfo.isFile()) {
            continue;
        }

        const QString targetPath = dir.absoluteFilePath(sourceInfo.fileName());
        if (QFileInfo(sourcePath) == QFileInfo(targetPath)) {
            continue;
        }

        QString candidate = targetPath;
        int suffix = 2;
        while (QFileInfo::exists(candidate)) {
            const QString extension = sourceInfo.suffix();
            const QString numbered = extension.isEmpty()
                                     ? QStringLiteral("%1 (%2)").arg(sourceInfo.completeBaseName()).arg(suffix++)
                                     : QStringLiteral("%1 (%2).%3").arg(sourceInfo.completeBaseName()).arg(suffix++).arg(extension);
            candidate = dir.absoluteFilePath(numbered);
        }

        if (QFile::copy(sourcePath, candidate)) {
            ++imported;
        }
    }

    if (imported > 0) {
        toastService()->showSuccess(std::string("导入文件"),
                                    QStringLiteral("已导入 %1 个文件").arg(imported).toStdString());
    } else {
        toastService()->showInfo(std::string("导入文件"), std::string("没有导入新文件"));
    }

    return imported;
}

QVariantList SongModel::loadImportedSongs() const
{
    QVariantList result;

    const QString raw = settings()->value(IMPORTED_SONGS_KEY).toQString();
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (!doc.isArray()) {
        return result;
    }

    const QJsonArray array = doc.array();
    QSet<QString> seenPaths;
    for (const QJsonValue& value : array) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonObject obj = value.toObject();
        const QString title = obj["title"].toString();
        const QString filePath = obj["filePath"].toString();
        if (title.isEmpty() || filePath.isEmpty()
                || QFileInfo(filePath).suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0
                || isProtectedUserLocation(filePath)
                || !QFileInfo::exists(filePath)) {
            continue;
        }

        const QString canonicalPath = QFileInfo(filePath).canonicalFilePath();
        if (canonicalPath.isEmpty() || seenPaths.contains(canonicalPath)) {
            continue;
        }
        seenPaths.insert(canonicalPath);

        QStringList collections;
        const QJsonArray collectionArray = obj.value("collections").toArray();
        for (const QJsonValue& collection : collectionArray) {
            const QString name = collection.toString().trimmed();
            if (!name.isEmpty() && !collections.contains(name)) {
                collections.push_back(name);
            }
        }

        result << makeSong(QStringLiteral("imported-%1").arg(canonicalPath), title, 0,
                           QStringLiteral("本地导入"), QStringLiteral("#16A085"),
                           QFileInfo(canonicalPath).absolutePath(),
                           canonicalPath, QFileInfo(canonicalPath).completeBaseName(),
                           songLevelFromJson(obj), collections);
    }

    return result;
}

