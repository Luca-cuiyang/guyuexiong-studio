/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 继续学习数据模型
 */
#ifndef DBSTUDIO_LASTPRACTICEMODEL_H
#define DBSTUDIO_LASTPRACTICEMODEL_H

#include <QObject>
#include <qqmlintegration.h>

#include "modularity/ioc.h"

#include "actions/iactionsdispatcher.h"
#include "toast/itoastservice.h"

namespace mu::appshell {
class LastPracticeModel : public QObject, public muse::Contextable
{
    Q_OBJECT

    Q_PROPERTY(QString title READ title NOTIFY lastPracticeChanged)
    Q_PROPERTY(QString filePath READ filePath NOTIFY lastPracticeChanged)
    Q_PROPERTY(bool hasLast READ hasLast NOTIFY lastPracticeChanged)

    QML_ELEMENT

    muse::ContextInject<muse::actions::IActionsDispatcher> dispatcher = { this };
    muse::GlobalInject<muse::toast::IToastService> toastService;

public:
    explicit LastPracticeModel(QObject* parent = nullptr);

    QString title() const;
    QString filePath() const;
    bool hasLast() const;

    Q_INVOKABLE void load();
    Q_INVOKABLE void record(const QString& title, const QString& filePath, int instrument);
    Q_INVOKABLE void continuePractice();

signals:
    void lastPracticeChanged();

private:
    QString m_title;
    QString m_filePath;
};
}

#endif // DBSTUDIO_LASTPRACTICEMODEL_H
