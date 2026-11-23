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

#include "playbackcursor.h"

#include <algorithm>
#include <cmath>

#include "draw/painter.h"

#include "engraving/dom/measure.h"
#include "engraving/dom/score.h"
#include "engraving/dom/staff.h"
#include "engraving/dom/system.h"

#include "notation/inotation.h"
#include "notation/inotationelements.h" // IWYU pragma: keep

using namespace mu::engraving;
using namespace mu::notation;
using namespace muse;

static double systemBottomY(const Score* score, const System* system)
{
    if (!score || !system) {
        return 0.0;
    }

    double systemBottomY = 0.0;

    const size_t staffCount = std::min(score->nstaves(), system->staves().size());
    for (size_t i = 0; i < staffCount; ++i) {
        const SysStaff* ss = system->staff(i);
        const Staff* staff = score->staff(i);
        if (!ss || !staff || !ss->show() || !staff->show()) {
            continue;
        }

        systemBottomY = std::max(systemBottomY, ss->bbox().bottom());
    }

    return systemBottomY;
}

static RectF calculateRect(double x, const Score* score, const System* system, double systemBottomY,
                           double thickness, double length)
{
    const double spatium = score->style().spatium();
    const double fullTop = system->staffCanvasYpage(0) - 3.0 * spatium;
    const double fullHeight = systemBottomY + 6.0 * spatium;
    const double height = fullHeight * length;
    const double top = fullTop + (fullHeight - height) / 2.0;

    return RectF {
        x - spatium,
        top,
        thickness * spatium,
        height
    };
}

void PlaybackCursor::paint(muse::draw::Painter* painter)
{
    if (!m_visible) {
        return;
    }

    painter->fillRect(m_rect, effectiveColor());
}

void PlaybackCursor::setNotation(INotationPtr notation)
{
    m_notation = notation;
}

void PlaybackCursor::move(muse::midi::tick_t tick)
{
    m_rect = resolveCursorRectByTick(tick);
}

muse::RectF PlaybackCursor::resolveCursorRectByTick(int _tick) const
{
    const Score* score = m_notation ? m_notation->elements()->msScore() : nullptr;
    if (!score) {
        return RectF();
    }

    auto interpolateXByTicks = [](int tick, int startTick, int endTick,
                                  double segmentStartX, double segmentEndX) {
        const int durationTicks = endTick - startTick;
        return durationTicks > 0
               ? segmentStartX + (segmentEndX - segmentStartX) * double(tick - startTick) / double(durationTicks)
               : segmentStartX;
    };

    const Fraction tick = Fraction::fromTicks(_tick);
    const double thickness = configuration()->playbackCursorThickness();
    const double length = configuration()->playbackCursorLength();

    const Measure* measure = score->tick2measureMM(tick);
    if (!measure) {
        return RectF();
    }

    const System* system = measure->system();
    if (!system || !system->page() || system->staves().empty()) {
        return RectF();
    }

    const double bottomY = systemBottomY(score, system);

    for (const Segment* s = measure->first(SegmentType::ChordRest); s;) {
        const Fraction segmentStartTick = s->tick();
        const double segmentStartX = s->canvasPos().x();

        const Segment* nextSegment = s->next(SegmentType::ChordRest);
        while (nextSegment && !nextSegment->visible()) {
            nextSegment = nextSegment->next(SegmentType::ChordRest);
        }

        Fraction segmentEndTick;
        double segmentEndX = 0.0;

        if (nextSegment) {
            segmentEndTick = nextSegment->tick();
            segmentEndX = nextSegment->canvasPos().x();
        } else {
            segmentEndTick = measure->endTick();

            const Segment* endBar = measure->findSegment(SegmentType::EndBarLine, segmentEndTick);

            segmentEndX = endBar ? endBar->canvasPos().x()
                          : measure->canvasPos().x() + measure->width();
        }

        if (tick < segmentStartTick || tick >= segmentEndTick) {
            s = nextSegment;
            continue;
        }

        const double x = interpolateXByTicks(_tick, segmentStartTick.ticks(), segmentEndTick.ticks(),
                                             segmentStartX, segmentEndX);
        return calculateRect(x, score, system, bottomY, thickness, length);
    }

    return RectF();
}

bool PlaybackCursor::visible() const
{
    return m_visible;
}

void PlaybackCursor::setVisible(bool arg)
{
    m_visible = arg;
}

const muse::RectF& PlaybackCursor::rect() const
{
    return m_rect;
}

QColor PlaybackCursor::effectiveColor() const
{
    QColor cursorColor = color();
    if (!cursorColor.isValid()) {
        //! 兜底：读取失败/为空时使用默认橙色，绝不能让光标消失。
        cursorColor = QColor("#F57C00");
    }

    double opacity = configuration()->playbackCursorOpacity();
    if (!std::isfinite(opacity) || opacity <= 0.0 || opacity > 1.0) {
        //! 兜底：透明度异常时使用 100% 不透明。
        opacity = 1.0;
    }

    cursorColor.setAlphaF(opacity);
    return cursorColor;
}

QColor PlaybackCursor::color() const
{
    return configuration()->playbackCursorColor();
}
