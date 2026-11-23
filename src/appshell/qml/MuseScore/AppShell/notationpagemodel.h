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

#pragma once

#include <qqmlintegration.h>

#include "async/asyncable.h"

#include "modularity/ioc.h"
#include "context/iglobalcontext.h"
#include "interactive/iinteractive.h"
#include "notation/inotation.h"
#include "rcommand/icommanddispatcher.h"

namespace mu::appshell {
class NotationPageModel : public QObject, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(bool playerViewLocked READ playerViewLocked WRITE setPlayerViewLocked NOTIFY playerViewLockedChanged)

    QML_ELEMENT

    muse::ContextInject<context::IGlobalContext> globalContext = { this };
    muse::ContextInject<muse::IInteractive> interactive = { this };
    muse::ContextInject<muse::rcommand::ICommandDispatcher> commandDispatcher = { this };
public:
    explicit NotationPageModel(QObject* parent = nullptr);

    bool playerViewLocked() const;
    void setPlayerViewLocked(bool locked);

    Q_INVOKABLE void goBack();
    Q_INVOKABLE QString playbackToolBarName() const;
    Q_INVOKABLE QString undoRedoToolBarName() const;

signals:
    void notationReady();
    void playerViewLockedChanged();

private:
    void init();
    void onNotationChanged();
    void enforcePlayerViewMode();

    bool m_inited = false;
    bool m_playerViewLocked = false;
    bool m_enforcingPlayerViewMode = false;
    notation::INotationPtr m_lockedNotation;
};
}
