/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 播放记录模型
 */
#ifndef DBSTUDIO_PLAYLISTMODEL_H
#define DBSTUDIO_PLAYLISTMODEL_H

#include <QAbstractListModel>
#include <qqmlintegration.h>

#include "async/asyncable.h"
#include "modularity/ioc.h"

#include "actions/iactionsdispatcher.h"
#include "context/iglobalcontext.h"
#include "toast/itoastservice.h"

namespace mu::appshell {
class PlaylistModel : public QAbstractListModel, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    QML_ELEMENT

public:
    enum Roles {
        TitleRole = Qt::UserRole + 1,
        IsCurrentRole
    };

    explicit PlaylistModel(QObject* parent = nullptr);

    int count() const;
    Q_INVOKABLE void load();
    Q_INVOKABLE void add(const QString& path, const QString& title);
    Q_INVOKABLE void addFromUser(const QString& path, const QString& title);
    Q_INVOKABLE void removeAt(int index);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void playAt(int index);
    Q_INVOKABLE void setCurrentPath(const QString& path);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();

private:
    void openCurrent();
    void save() const;
    void setCurrentIndex(int index);

    muse::ContextInject<context::IGlobalContext> context = { this };
    muse::ContextInject<muse::actions::IActionsDispatcher> dispatcher = { this };
    muse::GlobalInject<muse::toast::IToastService> toastService;

    std::vector<QVariantMap> m_items;
    int m_currentIndex = -1;
    bool m_loaded = false;
};
}

#endif // DBSTUDIO_PLAYLISTMODEL_H
