/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 练习报告历史模型
 */
#ifndef DBSTUDIO_PRACTICEREPORTMODEL_H
#define DBSTUDIO_PRACTICEREPORTMODEL_H

#include <QObject>
#include <QVariantList>
#include <qqmlintegration.h>

namespace mu::appshell {
class PracticeReportModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList reports READ reports NOTIFY reportsChanged)
    Q_PROPERTY(int currentStreak READ currentStreak NOTIFY streakChanged)
    Q_PROPERTY(bool practicedToday READ practicedToday NOTIFY streakChanged)
    Q_PROPERTY(int totalPracticeDays READ totalPracticeDays NOTIFY streakChanged)
    Q_PROPERTY(QVariantList recentDays READ recentDays NOTIFY streakChanged)

    QML_ELEMENT

public:
    explicit PracticeReportModel(QObject* parent = nullptr);

    QVariantList reports() const;
    int currentStreak() const;
    bool practicedToday() const;
    int totalPracticeDays() const;
    QVariantList recentDays() const;

    Q_INVOKABLE void load();

signals:
    void reportsChanged();
    void streakChanged();

private:
    QVariantList m_reports;
    int m_currentStreak = 0;
    bool m_practicedToday = false;
    int m_totalPracticeDays = 0;
    QVariantList m_recentDays;
};
}

#endif // DBSTUDIO_PRACTICEREPORTMODEL_H
