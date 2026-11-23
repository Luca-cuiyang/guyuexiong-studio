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
#include "playbacktoolbarmodel.h"

#include "global/containers.h"
#include "types/translatablestring.h"

#include "ui/view/musicalsymbolcodes.h"
#include "playback/playbackcommands.h"

#include "async/notifylist.h"
#include "notation/imasternotation.h"
#include "notation/inotationparts.h"
#include "notation/inotationplayback.h"
#include "engraving/dom/instrument.h"
#include "project/inotationproject.h"
#include "project/iprojectaudiosettings.h"

#include "ui/toolconfig.h"

using namespace mu::playback;
using namespace mu::engraving;
using namespace muse;
using namespace muse::actions;
using namespace muse::ui;
using namespace muse::uicomponents;
using namespace muse::audio;

static const QString PLAY_TOGGLE_ID("play-toggle");
static const QString DRUMS_MUTE_ID("drums-mute");
static const QString ACCOMPANIMENT_MUTE_ID("accompaniment-mute");

static const ToolConfig& defaultPlaybackToolConfig()
{
    static ToolConfig config;
    if (!config.isValid()) {
        config.items = {
            { REWIND_COMMAND, true },
            { "play-toggle", true }, // virtual code
            { METRONOME_TOGGLE_COMMAND, true },
            { "drums-mute", true }, // virtual code
            { "accompaniment-mute", true }, // virtual code
            { muse::rcommand::Command("command://app/fullscreen"), true },
        };
    }
    return config;
}

PlaybackToolBarModel::PlaybackToolBarModel(QObject* parent)
    : AbstractMenuModel(parent)
{
}

void PlaybackToolBarModel::load()
{
    AbstractMenuModel::load();
    updateActions();

    setupConnections();
}

void PlaybackToolBarModel::setupConnections()
{
    playbackController()->isPlayAllowedChanged().onReceive(this, [this](bool) {
        emit isPlayAllowedChanged();
    });

    globalContext()->playbackState()->playbackStatusChanged().onReceive(this, [this](audio::PlaybackStatus) {
        updatePlayItem();
        emit isPlayingChanged();
    });

    globalContext()->playbackState()->playbackPositionChanged().onReceive(this, [this](secs_t secs) {
        updatePlayPosition(secs);
    });

    playbackController()->totalPlayTimeChanged().onNotify(this, [this]() {
        emit maxPlayTimeChanged();
        secs_t pos = globalContext()->playbackState()->playbackPosition();
        updatePlayPosition(pos);
    });

    playbackController()->currentTempoChanged().onNotify(this, [this]() {
        emit tempoChanged();
    });

    playbackController()->loopBoundariesChanged().onNotify(this, [this]() {
        emit loopBoundaryStateChanged();
    });

    notationConfiguration()->isPlayRepeatsChanged().onNotify(this, [this]() {
        emit playRepeatsEnabledChanged();
    });
}

void PlaybackToolBarModel::updateActions()
{
    MenuItemList result;

    //! NOTE At the moment no customization ability
    ToolConfig config = defaultPlaybackToolConfig();
    for (const ToolConfig::Item& item : config.items) {
        if (item.intent == PLAY_TOGGLE_ID) {
            result << makePlayItem();
        } else if (item.intent == DRUMS_MUTE_ID) {
            result << makeDrumsMuteItem();
        } else if (item.intent == ACCOMPANIMENT_MUTE_ID) {
            result << makeAccompanimentMuteItem();
        } else {
            result << makeMenuItem(rcommand::Command(item.intent));
        }
    }

    setItems(result);
}

bool PlaybackToolBarModel::isPlayAllowed() const
{
    return playbackController()->isPlayAllowed();
}

bool PlaybackToolBarModel::isPlaying() const
{
    return globalContext()->playbackState()->isPlaying();
}

bool PlaybackToolBarModel::playRepeatsEnabled() const
{
    return notationConfiguration()->isPlayRepeatsEnabled();
}

bool PlaybackToolBarModel::loopInEnabled() const
{
    return playbackController()->isLoopBoundaryEnabled(LoopBoundaryType::LoopIn);
}

bool PlaybackToolBarModel::loopOutEnabled() const
{
    return playbackController()->isLoopBoundaryEnabled(LoopBoundaryType::LoopOut);
}

bool PlaybackToolBarModel::isToolbarFloating() const
{
    return m_isToolbarFloating;
}

void PlaybackToolBarModel::setIsToolbarFloating(bool floating)
{
    if (floating == m_isToolbarFloating) {
        return;
    }

    m_isToolbarFloating = floating;
    emit isToolbarFloatingChanged(floating);
}

QTime PlaybackToolBarModel::maxPlayTime() const
{
    return timeFromSeconds(totalPlayTime());
}

QTime PlaybackToolBarModel::playTime() const
{
    return timeFromSeconds(m_playbackPositionSecs);
}

void PlaybackToolBarModel::setPlayTime(const QTime& time)
{
    rewind(timeToSeconds(time));
}

qreal PlaybackToolBarModel::playPosition() const
{
    const secs_t totalSecs = totalPlayTime();
    if (totalSecs.is_zero()) {
        return 0.0;
    }

    const qreal position = static_cast<qreal>(m_playbackPositionSecs) / static_cast<qreal>(totalSecs);
    return position;
}

void PlaybackToolBarModel::setPlayPosition(qreal position)
{
    rewind(totalPlayTime() * position);
}

secs_t PlaybackToolBarModel::totalPlayTime() const
{
    return playbackController()->totalPlayTime();
}

MeasureBeat PlaybackToolBarModel::measureBeat() const
{
    const project::INotationProjectPtr project = globalContext()->currentProject();
    if (project && project->masterNotation() && project->masterNotation()->playback()) {
        const notation::INotationPlaybackPtr playback = project->masterNotation()->playback();
        return playback->beat(playback->secToTick(m_playbackPositionSecs));
    }

    return playbackController()->currentBeat();
}

muse::uicomponents::MenuItem* PlaybackToolBarModel::makePlayItem()
{
    rcommand::Command command = globalContext()->playbackState()->isPlaying() ? PAUSE_COMMAND : PLAY_COMMAND;
    MenuItem* item = makeMenuItem(command);
    item->setId(PLAY_TOGGLE_ID);
    return item;
}

void PlaybackToolBarModel::updatePlayItem()
{
    MenuItem& item = findItem(PLAY_TOGGLE_ID);
    if (item.isValid()) {
        rcommand::Command command = globalContext()->playbackState()->isPlaying() ? PAUSE_COMMAND : PLAY_COMMAND;
        item.setCommandInfo(commandsRegister()->commandInfo(command));
        item.setId(PLAY_TOGGLE_ID);
    }
}

MenuItem* PlaybackToolBarModel::makeDrumsMuteItem()
{
    MenuItem* item = new MenuItem(this);
    item->setId(DRUMS_MUTE_ID);
    item->setTitle(TranslatableString("playback", "鼓声"));
    item->setDescription(TranslatableString("playback", "切换鼓声静音（跟练）"));
    item->setCheckable(true);
    item->setChecked(m_drumsMuted);
    return item;
}

void PlaybackToolBarModel::updateDrumsMuteItem()
{
    MenuItem& item = findItem(DRUMS_MUTE_ID);
    if (item.isValid()) {
        item.setChecked(m_drumsMuted);
    }
}

MenuItem* PlaybackToolBarModel::makeAccompanimentMuteItem()
{
    MenuItem* item = new MenuItem(this);
    item->setId(ACCOMPANIMENT_MUTE_ID);
    item->setTitle(TranslatableString("playback", "伴奏"));
    item->setDescription(TranslatableString("playback", "切换伴奏静音"));
    item->setCheckable(true);
    item->setChecked(m_accompanimentMuted);
    return item;
}

void PlaybackToolBarModel::updateAccompanimentMuteItem()
{
    MenuItem& item = findItem(ACCOMPANIMENT_MUTE_ID);
    if (item.isValid()) {
        item.setChecked(m_accompanimentMuted);
    }
}

bool PlaybackToolBarModel::drumsMuted() const
{
    return m_drumsMuted;
}

bool PlaybackToolBarModel::accompanimentMuted() const
{
    return m_accompanimentMuted;
}

void PlaybackToolBarModel::setDrumsMuted(bool drumsMuted)
{
    if (m_drumsMuted == drumsMuted) {
        return;
    }

    m_drumsMuted = drumsMuted;
    applyDrumsMute(m_drumsMuted);
    updateDrumsMuteItem();
    emit drumsMutedChanged();
}

void PlaybackToolBarModel::toggleDrumsMute()
{
    setDrumsMuted(!m_drumsMuted);
}

void PlaybackToolBarModel::setAccompanimentMuted(bool accompanimentMuted)
{
    if (m_accompanimentMuted == accompanimentMuted) {
        return;
    }

    m_accompanimentMuted = accompanimentMuted;
    applyAccompanimentMute(m_accompanimentMuted);
    updateAccompanimentMuteItem();
    emit accompanimentMutedChanged();
}

void PlaybackToolBarModel::toggleAccompanimentMute()
{
    setAccompanimentMuted(!m_accompanimentMuted);
}

void PlaybackToolBarModel::enablePlayRepeats()
{
    if (!notationConfiguration()->isPlayRepeatsEnabled()) {
        playbackController()->togglePlayRepeats();
    }
    emit playRepeatsEnabledChanged();
}

void PlaybackToolBarModel::togglePlayRepeats()
{
    playbackController()->togglePlayRepeats();
    emit playRepeatsEnabledChanged();
}

void PlaybackToolBarModel::toggleLoopIn()
{
    playbackController()->toggleLoopBoundary(LoopBoundaryType::LoopIn);
    emit loopBoundaryStateChanged();
}

void PlaybackToolBarModel::toggleLoopOut()
{
    playbackController()->toggleLoopBoundary(LoopBoundaryType::LoopOut);
    emit loopBoundaryStateChanged();
}

void PlaybackToolBarModel::handleMenuItem(const QString& itemId)
{
    if (itemId == DRUMS_MUTE_ID) {
        toggleDrumsMute();
        return;
    }

    if (itemId == ACCOMPANIMENT_MUTE_ID) {
        toggleAccompanimentMute();
        return;
    }

    AbstractMenuModel::handleMenuItem(itemId);
}

void PlaybackToolBarModel::applyDrumsMute(bool muteDrums)
{
    notation::IMasterNotationPtr masterNotation = globalContext()->currentMasterNotation();
    if (!masterNotation) {
        return;
    }

    async::NotifyList<const Part*> partList = masterNotation->parts()->partList();
    for (const Part* part : partList) {
        if (!part || !part->instrument() || !part->instrument()->drumset()) {
            continue;
        }

        for (const InstrumentTrackId& trackId : part->instrumentTrackIdList()) {
            IPlaybackController::SoloMuteState state = playbackController()->trackSoloMuteState(trackId);
            state.mute = muteDrums;
            playbackController()->setTrackSoloMuteState(trackId, state);
        }
    }
}

void PlaybackToolBarModel::applyAccompanimentMute(bool muteAccompaniment)
{
    project::INotationProjectPtr project = globalContext()->currentProject();
    if (!project) {
        return;
    }

    project::IProjectAudioSettingsPtr audioSettings = project->audioSettings();
    if (!audioSettings) {
        return;
    }

    project::AudioTrackSettings settings = audioSettings->audioTrackSettings();
    bool changed = false;
    for (project::AudioClipSettings& clip : settings.clips) {
        if (clip.muted != muteAccompaniment) {
            clip.muted = muteAccompaniment;
            changed = true;
        }
    }

    if (changed) {
        audioSettings->setAudioTrackSettings(settings);
    }
}

void PlaybackToolBarModel::updatePlayPosition(secs_t secs)
{
    if (m_playbackPositionSecs == secs) {
        return;
    }

    m_playbackPositionSecs = secs;
    emit playPositionChanged();
}

void PlaybackToolBarModel::rewind(secs_t secs)
{
    if (m_playbackPositionSecs == secs || secs > totalPlayTime()) {
        return;
    }

    dispatchCommand(REWIND_COMMAND, { { "position", Val(secs) } });
}

void PlaybackToolBarModel::rewindToBeat(const MeasureBeat& beat)
{
    secs_t secs = playbackController()->beatToSecs(beat.measureIndex, static_cast<int>(beat.beat));
    rewind(secs);
}

int PlaybackToolBarModel::measureNumber() const
{
    return measureBeat().measureIndex + 1;
}

void PlaybackToolBarModel::setMeasureNumber(int measureNumber)
{
    int measureIndex = measureNumber - 1;
    MeasureBeat measureBeat = this->measureBeat();

    if (measureIndex == measureBeat.measureIndex) {
        return;
    }

    measureBeat.measureIndex = measureIndex;
    rewindToBeat(measureBeat);
}

int PlaybackToolBarModel::maxMeasureNumber() const
{
    return measureBeat().maxMeasureIndex + 1;
}

int PlaybackToolBarModel::beatNumber() const
{
    return static_cast<int>(measureBeat().beat) + 1;
}

void PlaybackToolBarModel::setBeatNumber(int beatNumber)
{
    int beatIndex = beatNumber - 1;
    MeasureBeat measureBeat = this->measureBeat();

    if (beatIndex == static_cast<int>(measureBeat.beat)) {
        return;
    }

    measureBeat.beat = beatIndex;
    rewindToBeat(measureBeat);
}

void PlaybackToolBarModel::setTempoMultiplier(qreal multiplier)
{
    // DB player：乐谱事件、节拍器和伴奏共用同一播放速率。
    multiplier = qBound<qreal>(0.01, multiplier, 10.0);

    // Let the controller refresh its cached tempo even when the rate is already 1.0.
    playbackController()->setTempoMultiplier(multiplier);
    emit tempoChanged();
}

void PlaybackToolBarModel::setTempoBpm(int bpm)
{
    const int currentBpm = tempoBpm();
    if (bpm <= 0 || currentBpm <= 0) {
        return;
    }

    const qreal nextMultiplier = tempoMultiplier() * qreal(bpm) / qreal(currentBpm);
    setTempoMultiplier(nextMultiplier);
}

void PlaybackToolBarModel::resetTempo()
{
    setTempoMultiplier(1.0);
}

int PlaybackToolBarModel::maxBeatNumber() const
{
    return measureBeat().maxBeatIndex + 1;
}

QVariant PlaybackToolBarModel::tempo() const
{
    static const std::unordered_map<DurationType, MusicalSymbolCodes::Code> DURATION_TO_ICON {
        { DurationType::V_WHOLE, MusicalSymbolCodes::Code::SEMIBREVE },
        { DurationType::V_HALF, MusicalSymbolCodes::Code::MINIM },
        { DurationType::V_QUARTER, MusicalSymbolCodes::Code::CROTCHET },
        { DurationType::V_EIGHTH, MusicalSymbolCodes::Code::QUAVER },
        { DurationType::V_16TH, MusicalSymbolCodes::Code::SEMIQUAVER },
    };

    const notation::Tempo& tempo = playbackController()->currentTempo();
    const MusicalSymbolCodes::Code noteIcon = muse::value(DURATION_TO_ICON, tempo.duration,
                                                          MusicalSymbolCodes::Code::CROTCHET);

    QVariantMap obj;
    obj["noteSymbol"] = musicalSymbolToString(noteIcon, tempo.withDot);
    obj["value"] = tempo.valueBpm;

    return obj;
}

int PlaybackToolBarModel::tempoBpm() const
{
    return tempo().toMap().value("value").toInt();
}

qreal PlaybackToolBarModel::tempoMultiplier() const
{
    return playbackController()->tempoMultiplier();
}

QColor PlaybackToolBarModel::playbackCursorColor() const
{
    return notationConfiguration()->playbackCursorColor();
}

qreal PlaybackToolBarModel::playbackCursorThickness() const
{
    return notationConfiguration()->playbackCursorThickness();
}

qreal PlaybackToolBarModel::playbackCursorOpacity() const
{
    return notationConfiguration()->playbackCursorOpacity();
}

qreal PlaybackToolBarModel::playbackCursorLength() const
{
    return notationConfiguration()->playbackCursorLength();
}

void PlaybackToolBarModel::setPlaybackCursorColor(const QColor& color)
{
    if (color == playbackCursorColor()) {
        return;
    }

    notationConfiguration()->setPlaybackCursorColor(color);
    emit playbackCursorStyleChanged();
}

void PlaybackToolBarModel::setPlaybackCursorThickness(qreal thickness)
{
    if (muse::RealIsEqual(thickness, playbackCursorThickness())) {
        return;
    }

    notationConfiguration()->setPlaybackCursorThickness(thickness);
    emit playbackCursorStyleChanged();
}

void PlaybackToolBarModel::setPlaybackCursorOpacity(qreal opacity)
{
    if (muse::RealIsEqual(opacity, playbackCursorOpacity())) {
        return;
    }

    notationConfiguration()->setPlaybackCursorOpacity(opacity);
    emit playbackCursorStyleChanged();
}

void PlaybackToolBarModel::setPlaybackCursorLength(qreal length)
{
    if (muse::RealIsEqual(length, playbackCursorLength())) {
        return;
    }

    notationConfiguration()->setPlaybackCursorLength(length);
    emit playbackCursorStyleChanged();
}
