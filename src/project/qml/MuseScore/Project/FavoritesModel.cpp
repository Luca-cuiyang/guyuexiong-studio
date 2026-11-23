/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 收藏模型
 */
#include "FavoritesModel.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFileInfo>
#include <QUrl>

#include "settings.h"

using namespace mu::project;
using namespace muse;

namespace {
static const Settings::Key FAVORITES_KEY("dbstudio", "favorites");
}

FavoritesModel::FavoritesModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
}

QVariantList FavoritesModel::favorites() const
{
    return m_favorites;
}

void FavoritesModel::load()
{
    if (m_loaded) {
        return;
    }

    m_loaded = true;
    m_favorites.clear();
    m_favoriteIds.clear();

    const QString raw = settings()->value(FAVORITES_KEY).toQString();
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (!doc.isArray()) {
        emit favoritesChanged();
        return;
    }

    const QJsonArray array = doc.array();
    for (const QJsonValue& value : array) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonObject obj = value.toObject();
        const QString id = obj["id"].toString();
        if (id.isEmpty()) {
            continue;
        }

        QVariantMap favorite;
        favorite["id"] = id;
        favorite["title"] = obj["title"].toString();
        favorite["type"] = obj["type"].toString();
        favorite["filePath"] = obj["filePath"].toString();
        favorite["instrument"] = obj["instrument"].toInt();
        m_favorites.append(favorite);
        m_favoriteIds.insert(id);
    }

    emit favoritesChanged();
}

void FavoritesModel::toggleFavorite(const QString& id, const QString& title, const QString& type,
                                    const QString& filePath, int instrument)
{
    if (id.isEmpty()) {
        return;
    }

    if (m_favoriteIds.contains(id)) {
        m_favoriteIds.remove(id);
        for (int i = 0; i < m_favorites.size(); ++i) {
            if (m_favorites[i].toMap()["id"].toString() == id) {
                m_favorites.removeAt(i);
                break;
            }
        }
    } else {
        QVariantMap favorite;
        favorite["id"] = id;
        favorite["title"] = title;
        favorite["type"] = type;
        favorite["filePath"] = filePath;
        favorite["instrument"] = instrument;
        m_favorites.append(favorite);
        m_favoriteIds.insert(id);
    }

    saveFavorites();
    emit favoritesChanged();
}

void FavoritesModel::openFavorite(const QString& filePath, const QString& title)
{
    if (filePath.isEmpty()) {
        return;
    }

    if (QFileInfo(filePath).suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0) {
        toastService()->showError(std::string("无法打开收藏"),
                                  std::string("鼓乐熊Studio 仅支持 DB Score 导出的 .db 文件"));
        return;
    }

    if (!QFileInfo::exists(filePath)) {
        toastService()->showError(std::string("无法打开收藏"),
                                  std::string("收藏的谱面文件不存在或已被移动"));
        return;
    }

    dispatcher()->dispatch("file-open",
                           muse::actions::ActionData::make_arg2<QUrl, QString>(QUrl::fromLocalFile(filePath), title));
}

void FavoritesModel::saveFavorites() const
{
    QJsonArray array;
    for (const QVariant& item : m_favorites) {
        const QVariantMap map = item.toMap();
        QJsonObject obj;
        obj["id"] = map["id"].toString();
        obj["title"] = map["title"].toString();
        obj["type"] = map["type"].toString();
        obj["filePath"] = map["filePath"].toString();
        obj["instrument"] = map["instrument"].toInt();
        array.append(obj);
    }

    const QString json = QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact));
    settings()->setSharedValue(FAVORITES_KEY, Val(json.toStdString()));
}
