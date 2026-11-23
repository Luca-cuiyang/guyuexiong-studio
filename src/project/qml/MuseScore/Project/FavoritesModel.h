/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 收藏模型
 */
#ifndef DBSTUDIO_FAVORITESMODEL_H
#define DBSTUDIO_FAVORITESMODEL_H

#include <QObject>
#include <QSet>
#include <QVariantList>
#include <qqmlintegration.h>

#include "modularity/ioc.h"

#include "actions/iactionsdispatcher.h"
#include "toast/itoastservice.h"

namespace mu::project {
class FavoritesModel : public QObject, public muse::Contextable
{
    Q_OBJECT

    Q_PROPERTY(QVariantList favorites READ favorites NOTIFY favoritesChanged)

    QML_ELEMENT

    muse::ContextInject<muse::actions::IActionsDispatcher> dispatcher = { this };
    muse::GlobalInject<muse::toast::IToastService> toastService;

public:
    explicit FavoritesModel(QObject* parent = nullptr);

    QVariantList favorites() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void toggleFavorite(const QString& id, const QString& title, const QString& type,
                                    const QString& filePath, int instrument);
    Q_INVOKABLE void openFavorite(const QString& filePath, const QString& title);

signals:
    void favoritesChanged();

private:
    void saveFavorites() const;

    bool m_loaded = false;
    QVariantList m_favorites;
    QSet<QString> m_favoriteIds;
};
}

#endif // DBSTUDIO_FAVORITESMODEL_H
