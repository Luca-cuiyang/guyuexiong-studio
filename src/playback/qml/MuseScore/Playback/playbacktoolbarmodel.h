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

#include "rcommand/commandtypes.h"
#include "uicomponents/qml/Muse/UiComponents/abstractmenumodel.h"

#include "modularity/ioc.h"
#include "iplaybackcontroller.h"
#include "notation/inotationconfiguration.h"
#include "context/iglobalcontext.h"

namespace mu::playback {
class PlaybackToolBarModel : public muse::uicomponents::AbstractMenuModel
{
    Q_OBJECT

    Q_PROPERTY(bool isToolbarFloating READ isToolbarFloating WRITE setIsToolbarFloating NOTIFY isToolbarFloatingChanged)
    Q_PROPERTY(bool isPlayAllowed READ isPlayAllowed NOTIFY isPlayAllowedChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(bool playRepeatsEnabled READ playRepeatsEnabled NOTIFY playRepeatsEnabledChanged)
    Q_PROPERTY(bool loopInEnabled READ loopInEnabled NOTIFY loopBoundaryStateChanged)
    Q_PROPERTY(bool loopOutEnabled READ loopOutEnabled NOTIFY loopBoundaryStateChanged)

    Q_PROPERTY(QTime maxPlayTime READ maxPlayTime NOTIFY maxPlayTimeChanged)

    Q_PROPERTY(QTime playTime READ playTime WRITE setPlayTime NOTIFY playPositionChanged)
    Q_PROPERTY(qreal playPosition READ playPosition WRITE setPlayPosition NOTIFY playPositionChanged)
    Q_PROPERTY(int measureNumber READ measureNumber WRITE setMeasureNumber NOTIFY playPositionChanged)
    Q_PROPERTY(int maxMeasureNumber READ maxMeasureNumber NOTIFY playPositionChanged)
    Q_PROPERTY(int beatNumber READ beatNumber WRITE setBeatNumber NOTIFY playPositionChanged)
    Q_PROPERTY(int maxBeatNumber READ maxBeatNumber NOTIFY playPositionChanged)

    Q_PROPERTY(QVariant tempo READ tempo NOTIFY tempoChanged)
    Q_PROPERTY(int tempoBpm READ tempoBpm WRITE setTempoBpm NOTIFY tempoChanged)
    Q_PROPERTY(qreal tempoMultiplier READ tempoMultiplier WRITE setTempoMultiplier NOTIFY tempoChanged)
    Q_PROPERTY(QColor playbackCursorColor READ playbackCursorColor WRITE setPlaybackCursorColor NOTIFY playbackCursorStyleChanged)
    Q_PROPERTY(qreal playbackCursorThickness READ playbackCursorThickness WRITE setPlaybackCursorThickness NOTIFY playbackCursorStyleChanged)
    Q_PROPERTY(qreal playbackCursorOpacity READ playbackCursorOpacity WRITE setPlaybackCursorOpacity NOTIFY playbackCursorStyleChanged)
    Q_PROPERTY(qreal playbackCursorLength READ playbackCursorLength WRITE setPlaybackCursorLength NOTIFY playbackCursorStyleChanged)
    Q_PROPERTY(bool drumsMuted READ drumsMuted WRITE setDrumsMuted NOTIFY drumsMutedChanged)
    Q_PROPERTY(bool accompanimentMuted READ accompanimentMuted WRITE setAccompanimentMuted NOTIFY accompanimentMutedChanged)

    QML_ELEMENT

    muse::GlobalInject<notation::INotationConfiguration> notationConfiguration;
    muse::ContextInject<IPlaybackController> playbackController = { this };
    muse::ContextInject<context::IGlobalContext> globalContext = { this };

public:
    explicit PlaybackToolBarModel(QObject* parent = nullptr);

    bool isToolbarFloating() const;
    bool isPlayAllowed() const;
    bool isPlaying() const;
    bool playRepeatsEnabled() const;
    bool loopInEnabled() const;
    bool loopOutEnabled() const;

    QTime maxPlayTime() const;
    QTime playTime() const;
    qreal playPosition() const;

    int measureNumber() const;
    int maxMeasureNumber() const;
    int beatNumber() const;
    int maxBeatNumber() const;

    QVariant tempo() const;
    int tempoBpm() const;
    qreal tempoMultiplier() const;
    QColor playbackCursorColor() const;
    qreal playbackCursorThickness() const;
    qreal playbackCursorOpacity() const;
    qreal playbackCursorLength() const;
    bool drumsMuted() const;
    bool accompanimentMuted() const;

    Q_INVOKABLE void load() override;

public slots:
    void setIsToolbarFloating(bool floating);
    void setPlayPosition(qreal position);
    void setPlayTime(const QTime& time);
    void setMeasureNumber(int measureNumber);
    void setBeatNumber(int beatNumber);
    void setTempoBpm(int bpm);
    void setTempoMultiplier(qreal multiplier);
    void resetTempo();
    void setPlaybackCursorColor(const QColor& color);
    void setPlaybackCursorThickness(qreal thickness);
    void setPlaybackCursorOpacity(qreal opacity);
    void setPlaybackCursorLength(qreal length);
    void setDrumsMuted(bool drumsMuted);
    Q_INVOKABLE void toggleDrumsMute();
    void setAccompanimentMuted(bool accompanimentMuted);
    Q_INVOKABLE void toggleAccompanimentMute();
    Q_INVOKABLE void enablePlayRepeats();
    Q_INVOKABLE void togglePlayRepeats();
    Q_INVOKABLE void toggleLoopIn();
    Q_INVOKABLE void toggleLoopOut();
    Q_INVOKABLE void handleMenuItem(const QString& itemId) override;

signals:
    void isToolbarFloatingChanged(bool floating);
    void isPlayAllowedChanged();
    void isPlayingChanged();
    void playRepeatsEnabledChanged();
    void loopBoundaryStateChanged();
    void maxPlayTimeChanged();
    void playPositionChanged();
    void tempoChanged();
    void playbackCursorStyleChanged();
    void drumsMutedChanged();
    void accompanimentMutedChanged();

private:
    void setupConnections();

    void updateActions();

    muse::secs_t totalPlayTime() const;
    engraving::MeasureBeat measureBeat() const;

    muse::uicomponents::MenuItem* makePlayItem();
    void updatePlayItem();

    muse::uicomponents::MenuItem* makeDrumsMuteItem();
    void updateDrumsMuteItem();
    void applyDrumsMute(bool muteDrums);

    muse::uicomponents::MenuItem* makeAccompanimentMuteItem();
    void updateAccompanimentMuteItem();
    void applyAccompanimentMute(bool muteAccompaniment);
    void updatePlayPosition(muse::audio::secs_t secs);

    void rewind(muse::audio::secs_t secs);
    void rewindToBeat(const engraving::MeasureBeat& beat);

    bool m_isToolbarFloating = false;
    muse::secs_t m_playbackPositionSecs = 0.0;
    bool m_drumsMuted = false;
    bool m_accompanimentMuted = false;
};
}
