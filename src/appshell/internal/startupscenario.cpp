/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "startupscenario.h"

#include <QCoreApplication>

#include "appshelltypes.h"
#include "translation.h"
#include "types/version.h"

#include "muse_framework_config.h"

#include "log.h"

using namespace mu::appshell;
using namespace muse;
using namespace muse::actions;

static const muse::UriQuery FIRST_LAUNCH_SETUP_URI("dbscore://firstLaunchSetup?floating=true");
static const muse::UriQuery WELCOME_DIALOG_URI("dbscore://welcomedialog");

static const Uri& startupPageUri(StartupModeType modeType)
{
    switch (modeType) {
    case StartupModeType::StartEmpty:
    case StartupModeType::StartWithNewScore:
    case StartupModeType::Recovery:
        return HOME_URI;
    case StartupModeType::StartWithScore:
    case StartupModeType::ContinueLastSession:
        return NOTATION_URI;
    }

    return HOME_URI;
}

void StartupScenario::setStartupType(const std::optional<std::string>& type)
{
    Q_UNUSED(type);
}

bool StartupScenario::isStartWithNewFileAsSecondaryInstance() const
{
    // DB Studio is a player. It never creates a score or opens the DB Score
    // instrument-selection dialog as a secondary startup action.
    return false;
}

const mu::project::ProjectFile& StartupScenario::startupScoreFile() const
{
    return m_startupScoreFile;
}

void StartupScenario::setStartupScoreFile(const std::optional<project::ProjectFile>& file)
{
    m_startupScoreFile = file ? file.value() : project::ProjectFile();
}

void StartupScenario::runOnSplashScreen()
{
    TRACEFUNC;

    if (!multiwindowsProvider()->isFirstWindow()) {
        registerAudioPlugins();
        return;
    }

    if (appUpdateScenario() && appUpdateScenario()->needCheckForUpdate()) {
        appUpdateScenario()->checkForUpdate(/*manual*/ false);
    }

    if (museSoundsUpdateScenario() && museSoundsUpdateScenario()->needCheckForUpdate()) {
        museSoundsUpdateScenario()->checkForUpdate(/*manual*/ false);
    }

    registerAudioPlugins();
}

void StartupScenario::registerAudioPlugins()
{
    if (!registerAudioPluginsScenario()) {
        return;
    }

    //! NOTE Registering plugins shows a window (dialog) before the main window is shown.
    //! After closing it, the application may in a state where there are no open windows,
    //! which leads to automatic exit from the application.
    //! (Thanks to the splashscreen, but this is not an obvious detail)
    qApp->setQuitLockEnabled(false);
    registerAudioPluginsScenario()->updatePluginsRegistry();
    qApp->setQuitLockEnabled(true);
}

void StartupScenario::runAfterSplashScreen()
{
    TRACEFUNC;

    if (m_startupCompleted) {
        return;
    }

    m_startupCompleted = true;

    //! NOTE: DB Score always starts on the configured startup page (default: Home).
    //! We intentionally do not auto-restore the previous session on launch, so the
    //! app consistently opens to the Home page after closing and reopening.
    StartupModeType modeType = resolveStartupModeType();

    const Uri& startupUri = startupPageUri(modeType);
    auto promise = interactive()->open(startupUri);
    promise.onResolve(this, [this, modeType](const Val&) {
        onStartupPageOpened(modeType);
    });
}

bool StartupScenario::startupCompleted() const
{
    return m_startupCompleted;
}

StartupModeType StartupScenario::resolveStartupModeType() const
{
    if (m_startupScoreFile.isValid()) {
        return StartupModeType::StartWithScore;
    }

    // DB Studio always starts at its own Home page when no score was passed on
    // the command line. Ignore inherited DB Score startup settings such as
    // "start-with-new", which would otherwise display the score creation wizard.
    return StartupModeType::StartEmpty;
}

void StartupScenario::onStartupPageOpened(StartupModeType modeType)
{
    TRACEFUNC;

    switch (modeType) {
    case StartupModeType::StartEmpty:
        break;
    case StartupModeType::StartWithNewScore:
        dispatcher()->dispatch("file-new");
        break;
    case StartupModeType::ContinueLastSession:
        dispatcher()->dispatch("continue-last-session");
        break;
    case StartupModeType::Recovery:
        restoreLastSession();
        break;
    case StartupModeType::StartWithScore: {
        project::ProjectFile file = m_startupScoreFile.isValid()
                                    ? m_startupScoreFile
                                    : project::ProjectFile(configuration()->startupScorePath());
        openScore(file);
    } break;
    }

    m_activeUpdateCheckCount = 0;

    if (museSoundsUpdateScenario() && museSoundsUpdateScenario()->checkInProgress()) {
        m_activeUpdateCheckCount++;
        museSoundsUpdateScenario()->checkInProgressChanged().onNotify(this, [this, modeType]() {
            museSoundsUpdateScenario()->checkInProgressChanged().disconnect(this);
            m_activeUpdateCheckCount--;
            showStartupDialogsIfNeed(modeType);
        }, Asyncable::Mode::SetReplace);
    }

    showStartupDialogsIfNeed(modeType);
}

void StartupScenario::showStartupDialogsIfNeed(StartupModeType modeType)
{
    TRACEFUNC;

    if (m_activeUpdateCheckCount != 0) {
        return;
    }

    //! DB Studio is a read-only player: it must open straight to the Home page
    //! (曲库 / 课程中心) without the MuseScore onboarding dialogs.
    Q_UNUSED(modeType);
    return;
}

bool StartupScenario::shouldShowWelcomeDialog(StartupModeType modeType) const
{
    if (!configuration()->welcomeDialogShowOnStartup()) {
        return false;
    }

    if (!multiwindowsProvider()->isFirstWindow()) {
        return false;
    }

    if (museSoundsUpdateScenario() && museSoundsUpdateScenario()->hasUpdate()) {
        return false;
    }

    const Uri& startupUri = startupPageUri(modeType);
    return interactive()->currentUri().val == startupUri;
}

void StartupScenario::checkAndShowMuseSamplerUpdateIfNeed()
{
    if (museSamplerCheckForUpdateScenario() && !museSamplerCheckForUpdateScenario()->alreadyChecked()) {
        museSamplerCheckForUpdateScenario()->checkAndShowUpdateIfNeed();
    }
}

void StartupScenario::openScore(const project::ProjectFile& file)
{
    dispatcher()->dispatch("file-open", ActionData::make_arg2<QUrl, QString>(file.url, file.displayNameOverride));
}

void StartupScenario::restoreLastSession()
{
    auto promise = interactive()->question(muse::trc("appshell", "The previous session quit unexpectedly."),
                                           muse::trc("appshell", "Do you want to restore the session?"),
                                           { IInteractive::Button::No, IInteractive::Button::Yes });

    promise.onResolve(this, [this](const IInteractive::Result& res) {
        if (res.isButton(IInteractive::Button::Yes)) {
            sessionsManager()->restore();
        } else {
            removeProjectsUnsavedChanges(configuration()->sessionProjectsPaths());
            sessionsManager()->reset();
            checkAndShowMuseSamplerUpdateIfNeed();
        }
    });
}

void StartupScenario::removeProjectsUnsavedChanges(const io::paths_t& projectsPaths)
{
    for (const muse::io::path_t& path : projectsPaths) {
        projectAutoSaver()->removeProjectUnsavedChanges(path);
    }
}
