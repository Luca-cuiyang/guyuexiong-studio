/*
 * SPDX-License-Identifier: GPL-3.0-only
 * DB Studio - 继续学习数据模型
 */
#include "LastPracticeModel.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

#include "settings.h"

using namespace mu::appshell;
using namespace muse;

namespace {
static const Settings::Key LAST_PRACTICE_KEY("appshell", "dbstudio/lastPractice");

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
    (void)path;
#endif
    return false;
}
}

LastPracticeModel::LastPracticeModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
}

QString LastPracticeModel::title() const
{
    return m_title;
}

QString LastPracticeModel::filePath() const
{
    return m_filePath;
}

bool LastPracticeModel::hasLast() const
{
    if (isProtectedUserLocation(m_filePath)) {
        return false;
    }
    const QFileInfo fileInfo(m_filePath);
    return fileInfo.exists() && fileInfo.isFile()
           && fileInfo.suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) == 0;
}

void LastPracticeModel::load()
{
    const QString raw = settings()->value(LAST_PRACTICE_KEY).toQString();
    const QJsonObject obj = QJsonDocument::fromJson(raw.toUtf8()).object();

    m_title = obj["title"].toString();
    m_filePath = obj["filePath"].toString();
    if (isProtectedUserLocation(m_filePath)) {
        m_title.clear();
        m_filePath.clear();
    }

    emit lastPracticeChanged();
}

void LastPracticeModel::record(const QString& title, const QString& filePath, int instrument)
{
    if (filePath.isEmpty() || isProtectedUserLocation(filePath)) {
        return;
    }

    m_title = title;
    m_filePath = filePath;

    QJsonObject obj;
    obj["title"] = title;
    obj["filePath"] = filePath;
    obj["instrument"] = instrument;

    const QString json = QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
    settings()->setSharedValue(LAST_PRACTICE_KEY, Val(json.toStdString()));

    emit lastPracticeChanged();
}

void LastPracticeModel::continuePractice()
{
    if (m_filePath.isEmpty()) {
        return;
    }

    if (QFileInfo(m_filePath).suffix().compare(QStringLiteral("db"), Qt::CaseInsensitive) != 0) {
        toastService()->showError(std::string("无法继续练习"),
                                  std::string("鼓乐熊Studio 仅支持 DB Score 导出的 .db 文件"));
        return;
    }

    if (!QFileInfo::exists(m_filePath)) {
        toastService()->showError(std::string("无法继续练习"),
                                  std::string("上次练习的谱面文件不存在或已被移动"));
        return;
    }

    dispatcher()->dispatch("file-open",
                           muse::actions::ActionData::make_arg2<QUrl, QString>(QUrl::fromLocalFile(m_filePath), m_title));
}

