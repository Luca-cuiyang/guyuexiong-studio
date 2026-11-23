/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 播放记录模型
 */
#include "PlaylistModel.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

#include "project/inotationproject.h"
#include "settings.h"

using namespace mu::appshell;
using namespace muse;

namespace {
static const Settings::Key PLAYLIST_KEY("dbstudio", "player/playlist");

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
}

PlaylistModel::PlaylistModel(QObject* parent)
    : QAbstractListModel(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
}

void PlaylistModel::load()
{
    if (m_loaded) {
        return;
    }

    const QString stored = settings()->value(PLAYLIST_KEY).toQString();
    const QJsonArray entries = QJsonDocument::fromJson(stored.toUtf8()).array();
    for (const QJsonValue& value : entries) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonObject obj = value.toObject();
        const QString path = obj.value("path").toString();
        if (isProtectedUserLocation(path)) {
            continue;
        }
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile()
                || info.suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0) {
            continue;
        }

        QVariantMap item;
        item[QStringLiteral("path")] = path;
        item[QStringLiteral("title")] = obj.value("title").toString(info.completeBaseName());
        m_items.push_back(item);
    }
    if (!m_items.empty()) {
        m_currentIndex = 0;
    }

    m_loaded = true;
    emit countChanged();

    // Keep the play record in sync with the opened project without starting
    // playback. The user starts playback explicitly from the toolbar or Space.
    auto syncCurrentProject = [this]() {
        const project::INotationProjectPtr project = context()->currentProject();
        if (!project) {
            return;
        }

        const QString path = project->path().toQString();
        if (QFileInfo(path).suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0) {
            return;
        }

        add(path, project->displayName());
        setCurrentPath(path);
    };

    context()->currentProjectChanged().onNotify(this, syncCurrentProject);
    syncCurrentProject();
}

int PlaylistModel::count() const
{
    return static_cast<int>(m_items.size());
}

void PlaylistModel::add(const QString& path, const QString& title)
{
    if (path.isEmpty() || isProtectedUserLocation(path)) {
        return;
    }

    for (int i = 0; i < static_cast<int>(m_items.size()); ++i) {
        if (m_items[i][QStringLiteral("path")].toString() == path) {
            if (!title.isEmpty()
                    && m_items[i][QStringLiteral("title")].toString() != title) {
                m_items[i][QStringLiteral("title")] = title;
                const QModelIndex changedIndex = index(i, 0);
                emit dataChanged(changedIndex, changedIndex, { TitleRole });
            }
            return;
        }
    }

    beginInsertRows(QModelIndex(), static_cast<int>(m_items.size()), static_cast<int>(m_items.size()));

    QVariantMap item;
    item[QStringLiteral("path")] = path;
    item[QStringLiteral("title")] = title.isEmpty() ? QFileInfo(path).completeBaseName() : title;
    m_items.push_back(item);

    endInsertRows();

    if (m_currentIndex < 0) {
        setCurrentIndex(0);
    }

    emit countChanged();
    save();
}

void PlaylistModel::addFromUser(const QString& path, const QString& title)
{
    if (path.isEmpty()) {
        return;
    }

    bool alreadyAdded = false;
    for (const QVariantMap& item : m_items) {
        if (item[QStringLiteral("path")].toString() == path) {
            alreadyAdded = true;
            break;
        }
    }

    add(path, title);
    if (alreadyAdded) {
        toastService()->showInfo(std::string("播放记录"), std::string("这条记录已经在播放记录中"));
    } else {
        toastService()->showSuccess(std::string("播放记录"), std::string("已加入播放记录"));
    }
}

void PlaylistModel::removeAt(int index)
{
    if (index < 0 || index >= static_cast<int>(m_items.size())) {
        return;
    }

    beginRemoveRows(QModelIndex(), index, index);
    m_items.erase(m_items.begin() + index);
    endRemoveRows();

    if (m_items.empty()) {
        m_currentIndex = -1;
    } else if (m_currentIndex == index) {
        m_currentIndex = qBound(0, index, static_cast<int>(m_items.size()) - 1);
    } else if (index < m_currentIndex) {
        --m_currentIndex;
    }
    setCurrentIndex(m_currentIndex);

    emit countChanged();
    save();
}

void PlaylistModel::clear()
{
    beginResetModel();
    m_items.clear();
    m_currentIndex = -1;
    endResetModel();

    emit countChanged();
    save();
}

void PlaylistModel::playAt(int index)
{
    if (index < 0 || index >= static_cast<int>(m_items.size())) {
        return;
    }

    setCurrentIndex(index);
    openCurrent();
}

void PlaylistModel::setCurrentPath(const QString& path)
{
    for (int i = 0; i < static_cast<int>(m_items.size()); ++i) {
        if (m_items[i][QStringLiteral("path")].toString() == path) {
            setCurrentIndex(i);
            return;
        }
    }
}

void PlaylistModel::setCurrentIndex(int index)
{
    m_currentIndex = m_items.empty() ? -1 : qBound(0, index, static_cast<int>(m_items.size()) - 1);
    if (!m_items.empty()) {
        emit dataChanged(this->index(0, 0), this->index(static_cast<int>(m_items.size()) - 1, 0), { IsCurrentRole });
    }
}

void PlaylistModel::openCurrent()
{
    if (m_currentIndex < 0 || m_currentIndex >= static_cast<int>(m_items.size())) {
        return;
    }

    const QVariantMap& item = m_items[m_currentIndex];
    const QString path = item[QStringLiteral("path")].toString();
    const QString title = item[QStringLiteral("title")].toString();
    const QFileInfo info(path);
    if (!info.exists() || !info.isFile()
            || info.suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0) {
        toastService()->showError(std::string("无法打开播放记录"),
                                  std::string("谱面文件不存在或已被移动"));
        return;
    }

    dispatcher()->dispatch("file-open",
                           muse::actions::ActionData::make_arg2<QUrl, QString>(QUrl::fromLocalFile(path), title));
}

void PlaylistModel::save() const
{
    QJsonArray entries;
    for (const QVariantMap& item : m_items) {
        QJsonObject obj;
        obj["path"] = item[QStringLiteral("path")].toString();
        obj["title"] = item[QStringLiteral("title")].toString();
        entries.append(obj);
    }

    const QString json = QString::fromUtf8(QJsonDocument(entries).toJson(QJsonDocument::Compact));
    settings()->setSharedValue(PLAYLIST_KEY, Val(json.toStdString()));
}

int PlaylistModel::rowCount(const QModelIndex&) const
{
    return static_cast<int>(m_items.size());
}

QVariant PlaylistModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= static_cast<int>(m_items.size())) {
        return QVariant();
    }

    const QVariantMap& item = m_items[index.row()];

    switch (role) {
    case TitleRole: return item[QStringLiteral("title")];
    case IsCurrentRole: return index.row() == m_currentIndex;
    default: return QVariant();
    }
}

QHash<int, QByteArray> PlaylistModel::roleNames() const
{
    return {
        { TitleRole, "title" },
        { IsCurrentRole, "isCurrent" },
    };
}
