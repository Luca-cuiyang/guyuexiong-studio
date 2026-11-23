/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 练习报告历史模型
 */
#include "PracticeReportModel.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDate>
#include <QSet>

#include "settings.h"

using namespace mu::appshell;
using namespace muse;

namespace {
static const Settings::Key PRACTICE_REPORTS_KEY("dbstudio", "practice/reports");
}

PracticeReportModel::PracticeReportModel(QObject* parent)
    : QObject(parent)
{
}

QVariantList PracticeReportModel::reports() const
{
    return m_reports;
}

int PracticeReportModel::currentStreak() const
{
    return m_currentStreak;
}

bool PracticeReportModel::practicedToday() const
{
    return m_practicedToday;
}

int PracticeReportModel::totalPracticeDays() const
{
    return m_totalPracticeDays;
}

QVariantList PracticeReportModel::recentDays() const
{
    return m_recentDays;
}

void PracticeReportModel::load()
{
    m_reports.clear();
    m_currentStreak = 0;
    m_practicedToday = false;
    m_totalPracticeDays = 0;
    m_recentDays.clear();

    const QString raw = settings()->value(PRACTICE_REPORTS_KEY).toQString();
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (!doc.isArray()) {
        emit reportsChanged();
        emit streakChanged();
        return;
    }

    QSet<QString> practicedDays;
    const QJsonArray array = doc.array();
    for (const QJsonValue& value : array) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonObject obj = value.toObject();
        QVariantMap report;
        report["title"] = obj["title"].toString();
        report["accuracy"] = obj["accuracy"].toDouble();
        report["perfect"] = obj["perfect"].toInt();
        report["early"] = obj["early"].toInt();
        report["late"] = obj["late"].toInt();
        report["missed"] = obj["missed"].toInt();
        report["extra"] = obj["extra"].toInt();
        report["date"] = obj["date"].toString();
        report["instrument"] = obj["instrument"].toInt();
        report["starRating"] = obj["starRating"].toInt();
        report["maxCombo"] = obj["maxCombo"].toInt();
        m_reports.append(report);

        practicedDays.insert(report["date"].toString().left(10));
    }

    m_totalPracticeDays = practicedDays.size();

    const QDate today = QDate::currentDate();
    m_practicedToday = practicedDays.contains(today.toString("yyyy-MM-dd"));

    QDate cursor = m_practicedToday ? today : today.addDays(-1);
    while (practicedDays.contains(cursor.toString("yyyy-MM-dd"))) {
        ++m_currentStreak;
        cursor = cursor.addDays(-1);
    }

    auto dayLabel = [](const QDate& date) -> QString {
        switch (date.dayOfWeek()) {
        case 1: return QStringLiteral("一");
        case 2: return QStringLiteral("二");
        case 3: return QStringLiteral("三");
        case 4: return QStringLiteral("四");
        case 5: return QStringLiteral("五");
        case 6: return QStringLiteral("六");
        default: return QStringLiteral("日");
        }
    };

    for (int i = 6; i >= 0; --i) {
        const QDate date = today.addDays(-i);
        QVariantMap day;
        day["label"] = dayLabel(date);
        day["practiced"] = practicedDays.contains(date.toString("yyyy-MM-dd"));
        day["isToday"] = (i == 0);
        m_recentDays.append(day);
    }

    emit reportsChanged();
    emit streakChanged();
}
