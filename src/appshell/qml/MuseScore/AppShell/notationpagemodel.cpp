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

#include "notationpagemodel.h"

#include <string>
#include <string_view>

#include "log.h"

#include "engraving/dom/articulation.h"
#include "engraving/dom/box.h"
#include "engraving/dom/mscore.h"
#include "engraving/dom/score.h"
#include "engraving/dom/textbase.h"
#include "engraving/style/styledef.h"

#include "notation/inotation.h"
#include "notation/inotationelements.h" // IWYU pragma: keep
#include "notation/inotationpainting.h"
#include "notation/inotationviewstate.h"

#include "internal/applicationuiactions.h"

using namespace mu::appshell;
using namespace mu::notation;
using namespace mu::engraving;

// Locked DB player layout contract. Player rendering must never inherit these
// geometry values from the source score.
static constexpr double PLAYER_A4_WIDTH_MM = 210.0;
static constexpr double PLAYER_A4_HEIGHT_MM = 297.0;
static constexpr double PLAYER_PAGE_MARGIN_MM = 5.0;
static constexpr double PLAYER_PRINTABLE_WIDTH_MM = PLAYER_A4_WIDTH_MM - 2.0 * PLAYER_PAGE_MARGIN_MM;
static constexpr double PLAYER_SPATIUM_MM = 1.75;
static constexpr double PLAYER_SYSTEM_DISTANCE_SP = 10.6;
static constexpr double PLAYER_TITLE_TO_SYSTEM_DISTANCE_SP = 8.0;
static constexpr double PLAYER_TITLE_FRAME_HEIGHT_SP = 3.5;
static constexpr double PLAYER_TEMPO_FONT_SIZE = 12.0;
static constexpr double PLAYER_MEASURE_NUMBER_FONT_SIZE = 6.0;
static constexpr double PLAYER_TITLE_FONT_SIZE_PT = 16.0;

static String normalizedPlayerText(const String& source)
{
    std::string text = source.toStdString();
    size_t position = 0;
    while ((position = text.find("<font", position)) != std::string::npos) {
        const size_t tagEnd = text.find('>', position + 5);
        if (tagEnd == std::string::npos) {
            break;
        }
        const std::string_view tag(text.data() + position, tagEnd - position + 1);
        const bool hasSize = tag.find("size=") != std::string_view::npos;
        const bool isSelfClosing = tag.size() >= 2
                                   && tag[tag.size() - 2] == '/'
                                   && tag.back() == '>';
        if (hasSize && isSelfClosing) {
            text.erase(position, tagEnd - position + 1);
        } else {
            position = tagEnd + 1;
        }
    }

    String result = String::fromStdString(text);
    result.replace(u"<br/>", u"\n");
    result.replace(u"<br />", u"\n");
    result.replace(u"<br>", u"\n");
    return result;
}

static void applyPlayerScorePageLayout(Score* score)
{
    if (!score) {
        return;
    }

    MStyle& style = score->style();
    const double pageMarginInch = PLAYER_PAGE_MARGIN_MM / INCH;

    // Apply the complete player-owned page geometry in memory.
    style.set(Sid::spatium, PLAYER_SPATIUM_MM * DPMM);
    style.set(Sid::pageWidth, PLAYER_A4_WIDTH_MM / INCH);
    style.set(Sid::pageHeight, PLAYER_A4_HEIGHT_MM / INCH);
    style.set(Sid::pagePrintableWidth, PLAYER_PRINTABLE_WIDTH_MM / INCH);
    style.set(Sid::pageEvenLeftMargin, pageMarginInch);
    style.set(Sid::pageOddLeftMargin, pageMarginInch);
    style.set(Sid::pageEvenTopMargin, pageMarginInch);
    style.set(Sid::pageEvenBottomMargin, pageMarginInch);
    style.set(Sid::pageOddTopMargin, pageMarginInch);
    style.set(Sid::pageOddBottomMargin, pageMarginInch);
    style.set(Sid::pageTwosided, false);

    // Player-owned vertical layout.
    style.set(Sid::enableVerticalSpread, false);
    style.set(Sid::staffUpperBorder, Spatium(6.2));
    style.set(Sid::staffLowerBorder, Spatium(6.2));
    style.set(Sid::staffLineWidth, Spatium(0.125)); // 4 px at the 4K player reference size
    style.set(Sid::barWidth, Spatium(0.1875)); // 6 px at the 4K player reference size
    style.set(Sid::minSystemDistance, Spatium(PLAYER_SYSTEM_DISTANCE_SP));
    style.set(Sid::maxSystemDistance, Spatium(PLAYER_SYSTEM_DISTANCE_SP));
    style.set(Sid::systemFrameDistance, Spatium(0.0));
    style.set(Sid::frameSystemDistance, Spatium(PLAYER_TITLE_TO_SYSTEM_DISTANCE_SP));
    style.set(Sid::enableIndentationOnFirstSystem, false);

    // Imported course files can carry arbitrary text sizes (30.69, 27.28 and
    // larger) in both their style table and inline formatting. Reset every text
    // font size to the built-in engraving defaults, then lock the player's two
    // core label sizes. This is in-memory compensation only.
    for (size_t i = 0; i < size_t(Sid::STYLES); ++i) {
        const Sid sid = static_cast<Sid>(i);
        const String name = String::fromAscii(MStyle::valueName(sid));
        if (name.endsWith(u"FontSize")) {
            style.set(sid, StyleDef::styleValues[i].defaultValue);
        }
    }
    style.set(Sid::tempoFontSize, PLAYER_TEMPO_FONT_SIZE);
    style.set(Sid::tempoFontSpatiumDependent, true);
    style.set(Sid::measureNumberFontSize, PLAYER_MEASURE_NUMBER_FONT_SIZE);
    style.set(Sid::measureNumberFontSpatiumDependent, false);

    // The continuous playback canvas must not contain print headers, footers,
    // page numbers or page borders.
    style.set(Sid::showHeader, false);
    style.set(Sid::showFooter, false);
    style.set(Sid::showPageNumber, false);
    style.set(Sid::showPageNumberOne, false);
    style.set(Sid::lyricsOddPosition, AlignH::HCENTER);
    style.set(Sid::lyricsEvenPosition, AlignH::HCENTER);

    // A saved inline size overrides the style table. Remove only the inline size
    // directives while preserving text content, symbols, bold/italic and all
    // other formatting, then let each text element follow its fixed role style.
    score->scanElements([](EngravingItem* item) {
        // In drum notation the greater-than accent is a performance marker
        // above the staff. Several imported books store it as accent-below.
        // Override only its display anchor; playback semantics remain intact.
        if (item->isArticulation()) {
            Articulation* articulation = toArticulation(item);
            if (articulation->isAccent()) {
                articulation->setPropertyFlags(Pid::ARTICULATION_ANCHOR, PropertyFlags::UNSTYLED);
                articulation->setAnchor(ArticulationAnchor::TOP);
            }
            return;
        }

        if (!item->isTextBase()) {
            return;
        }

        TextBase* text = toTextBase(item);
        const String xmlText = text->xmlText();
        const String normalizedText = normalizedPlayerText(xmlText);
        if (normalizedText != xmlText) {
            text->setXmlText(normalizedText);
        }
        text->setPropertyFlags(Pid::FONT_SIZE, PropertyFlags::STYLED);

        // Fingerings such as R/L are attached to individual notes. Ignore any
        // stale manual shift from the source page and center each annotation on
        // its current chord/rest after the player reflows the score.
        if (text->isLyrics()) {
            text->setOffset(PointF());
            text->setPosition(AlignH::HCENTER);
        }
    });

    // Keep the title text, whitespace and any authored line breaks exactly as
    // saved. Only its rendered font size is normalized for the player canvas.
    style.set(Sid::titleFontSize, PLAYER_TITLE_FONT_SIZE_PT);
    style.set(Sid::titleFontSpatiumDependent, false);

    // MStyle::set() only changes the style table. Refresh every STYLED property
    // so existing elements, including generated measure numbers, use it.
    score->styleChanged();
    MeasureBase* firstBox = score->first();
    if (firstBox && firstBox->isVBox()) {
        Box* titleBox = toBox(firstBox);
        titleBox->setAutoSizeEnabled(false);
        titleBox->setBoxHeight(Spatium(PLAYER_TITLE_FRAME_HEIGHT_SP));
    }
    // Complete the layout before the player is painted. Deferring this causes the
    // first frame to combine old element positions with the new player spacing,
    // which makes above-note lyrics such as R/L collide with the title.
    score->doLayout();
}

NotationPageModel::NotationPageModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
}

bool NotationPageModel::playerViewLocked() const
{
    return m_playerViewLocked;
}

void NotationPageModel::setPlayerViewLocked(bool locked)
{
    if (m_playerViewLocked == locked) {
        return;
    }

    m_playerViewLocked = locked;
    if (m_playerViewLocked) {
        if (m_inited) {
            onNotationChanged();
        } else {
            init();
        }
    }
    emit playerViewLockedChanged();
}

void NotationPageModel::goBack()
{
    commandDispatcher()->dispatch(muse::rcommand::Command("command://playback/stop"));
    (void)interactive()->open("dbscore://home");
}

void NotationPageModel::init()
{
    TRACEFUNC;

    if (m_inited) {
        return;
    }

    globalContext()->currentNotationChanged().onNotify(this, [this]() {
        onNotationChanged();
    });

    onNotationChanged();

    m_inited = true;
}

QString NotationPageModel::playbackToolBarName() const
{
    return PLAYBACK_TOOLBAR_NAME;
}

QString NotationPageModel::undoRedoToolBarName() const
{
    return UNDO_REDO_TOOLBAR_NAME;
}

void NotationPageModel::onNotationChanged()
{
    INotationPtr notation = globalContext()->currentNotation();
    if (!notation) {
        if (m_lockedNotation) {
            m_lockedNotation->viewModeChanged().disconnect(this);
            m_lockedNotation = nullptr;
        }
        return;
    }

    if (m_lockedNotation != notation) {
        if (m_lockedNotation) {
            m_lockedNotation->viewModeChanged().disconnect(this);
        }
        m_lockedNotation = notation;
        notation->viewModeChanged().onNotify(this, [this]() {
            if (m_playerViewLocked && !m_enforcingPlayerViewMode) {
                enforcePlayerViewMode();
            }
        }, Asyncable::Mode::SetReplace);
    }

    if (m_playerViewLocked) {
        Score* score = notation->elements()->msScore();
        applyPlayerScorePageLayout(score);
        enforcePlayerViewMode();
        emit notationReady();
    }

}

void NotationPageModel::enforcePlayerViewMode()
{
    if (!m_playerViewLocked || m_enforcingPlayerViewMode) {
        return;
    }

    INotationPtr notation = globalContext()->currentNotation();
    if (!notation || notation->viewMode() == ViewMode::SYSTEM) {
        return;
    }

    m_enforcingPlayerViewMode = true;
    notation->viewState()->setViewMode(ViewMode::SYSTEM);
    notation->painting()->setViewMode(ViewMode::SYSTEM);
    m_enforcingPlayerViewMode = false;
}

