/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 曲库数据模型（一个 .db 对应一首歌曲）
 */
#ifndef DBSTUDIO_SONGMODEL_H
#define DBSTUDIO_SONGMODEL_H

#include <QObject>
#include <QElapsedTimer>
#include <QJsonObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

#include "cloud/dbscoreauthorization/idbscoreauthorizationservice.h"
#include "async/asyncable.h"
#include "modularity/ioc.h"

#include "actions/iactionsdispatcher.h"
#include "interactive/iinteractive.h"
#include "toast/itoastservice.h"

class QNetworkAccessManager;

namespace mu::project {
class SongModel : public QObject, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(QVariantList songs READ songs NOTIFY songsChanged)
    Q_PROPERTY(QStringList levelNames READ levelNames CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool preparing READ preparing NOTIFY preparingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

    QML_ELEMENT

    muse::ContextInject<muse::actions::IActionsDispatcher> dispatcher = { this };
    muse::ContextInject<muse::IInteractive> interactive = { this };
    muse::GlobalInject<muse::cloud::IDbScoreAuthorizationService> authorization;
    muse::GlobalInject<muse::toast::IToastService> toastService;

public:
    explicit SongModel(QObject* parent = nullptr);
    ~SongModel() override;

    QVariantList songs() const;
    QStringList levelNames() const;
    bool loading() const;
    bool preparing() const;
    QString error() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void prepareSong(const QVariantMap& song);
    Q_INVOKABLE bool openScore(const QString& filePath, const QString& title);
    Q_INVOKABLE QVariantList listFiles(const QString& folder) const;
    Q_INVOKABLE void openFileExternally(const QString& path) const;
    Q_INVOKABLE int importFilesToFolder(const QString& folder);

signals:
    void songsChanged();
    void loadingChanged();
    void preparingChanged();
    void errorChanged();
    void songReady(const QVariantMap& song);
    void songPrepareFailed(const QString& message);
    void contentChanged(const QString& folder);

private:
    QVariantList loadImportedSongs() const;
    void setLoading(bool value);
    void setPreparing(bool value);
    void setError(const QString& value);
    void appendRemoteSongs(const QVariantMap& response);
    void finishSong(const QVariantMap& source, const QVariantMap& manifest);
    void completePreparedSong(const QString& folder);
    void downloadFiles(const QVariantList& files, int index, const QString& folder, int attempt = 0);
    QString cacheRoot() const;
    void clearContentCache();

    bool m_loaded = false;
    bool m_loading = false;
    bool m_preparing = false;
    QString m_error;
    QVariantList m_songs;
    QVariantList m_importedSongs;
    QVariantMap m_pendingSong;
    QNetworkAccessManager* m_networkManager = nullptr;
    QElapsedTimer m_lastRefresh;
};
}

#endif // DBSTUDIO_SONGMODEL_H
