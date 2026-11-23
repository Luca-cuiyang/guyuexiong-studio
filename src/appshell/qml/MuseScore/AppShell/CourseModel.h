/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 后台课程中心数据模型
 */
#ifndef DBSTUDIO_COURSEMODEL_H
#define DBSTUDIO_COURSEMODEL_H

#include <QJsonObject>
#include <QElapsedTimer>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

#include "cloud/dbscoreauthorization/idbscoreauthorizationservice.h"
#include "async/asyncable.h"
#include "interactive/iinteractive.h"
#include "modularity/ioc.h"

class QNetworkAccessManager;

namespace mu::appshell {
class CourseModel : public QObject, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(QVariantList courses READ courses NOTIFY coursesChanged)
    Q_PROPERTY(QStringList instrumentNames READ instrumentNames CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool preparingLesson READ preparingLesson NOTIFY preparingLessonChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

    QML_ELEMENT

    muse::ContextInject<muse::IInteractive> interactive = { this };
    muse::GlobalInject<muse::cloud::IDbScoreAuthorizationService> authorization;

public:
    explicit CourseModel(QObject* parent = nullptr);
    ~CourseModel() override;

    QVariantList courses() const;
    QStringList instrumentNames() const;
    bool loading() const;
    bool preparingLesson() const;
    QString error() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void prepareLesson(const QVariantMap& lesson);
    Q_INVOKABLE void setCourseCover(const QString& courseId);

signals:
    void coursesChanged();
    void loadingChanged();
    void preparingLessonChanged();
    void errorChanged();
    void lessonReady(const QVariantMap& lesson);
    void lessonPrepareFailed(const QString& message);
    void contentChanged(const QString& folder);

private:
    void setLoading(bool value);
    void setPreparingLesson(bool value);
    void setError(const QString& value);
    void parseCourses(const QVariantMap& response);
    void finishLesson(const QVariantMap& source, const QVariantMap& manifest);
    void downloadFiles(const QVariantList& files, int index, const QString& folder, int attempt = 0);
    void completePreparedLesson(const QString& folder);
    QJsonObject loadCourseCovers() const;
    void saveCourseCovers(const QJsonObject& covers) const;
    QString cacheRoot() const;
    void clearContentCache();

    bool m_loaded = false;
    bool m_loading = false;
    bool m_preparingLesson = false;
    QString m_error;
    QVariantList m_courses;
    QVariantMap m_pendingLesson;
    QNetworkAccessManager* m_networkManager = nullptr;
    QElapsedTimer m_lastRefresh;
};
}

#endif // DBSTUDIO_COURSEMODEL_H
