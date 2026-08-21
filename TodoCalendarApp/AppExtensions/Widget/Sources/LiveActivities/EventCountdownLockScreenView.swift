//
//  EventCountdownLockScreenView.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions


struct EventCountdownLockScreenView: View {

    private let model: EventCountdownActivityViewModel
    private let isStale: Bool

    init(model: EventCountdownActivityViewModel, isStale: Bool) {
        self.model = model
        self.isStale = isStale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                EventTagGlyphBadge(model: model, diameter: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.eventName)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)

                    EventCountdownTimeAndSubtitleText(model: model, font: .system(size: 13))
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                EventCountdownTimerText(
                    model: model, isStale: isStale,
                    liveFont: .system(size: 30, weight: .semibold),
                    staleFont: .system(size: 17)
                )
            }

            Divider()

            EventCountdownActionButtonRow(model: model)
        }
        .padding(16)
    }
}


// MARK: - 잠금화면·아일랜드 공유 조각

/// 만료 시 잠금화면·아일랜드 공통 문구로 교체하되, 영역별 폰트 크기는 각자 유지한다.
struct EventCountdownTimerText: View {

    private let model: EventCountdownActivityViewModel
    private let isStale: Bool
    private let liveFont: Font
    private let staleFont: Font

    init(model: EventCountdownActivityViewModel, isStale: Bool, liveFont: Font, staleFont: Font) {
        self.model = model
        self.isStale = isStale
        self.liveFont = liveFont
        self.staleFont = staleFont
    }

    var body: some View {
        let now = Date.now
        // eventDate가 지나면 timerInterval range가 역전돼 트랩한다 — isStale과 별개로 만료 처리.
        if isStale || model.eventDate <= now {
            Text("liveActivity::stale".localized())
                .font(staleFont)
                .foregroundStyle(.secondary)
        } else {
            Text(timerInterval: now...model.eventDate, countsDown: true)
                .font(liveFont)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
}

struct EventCountdownTimeAndSubtitleText: View {

    private let model: EventCountdownActivityViewModel
    private let font: Font

    init(model: EventCountdownActivityViewModel, font: Font) {
        self.model = model
        self.font = font
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(model.eventTimeText)

            if let subtitle = model.subtitle {
                Text(verbatim: "|")

                Text(subtitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(font)
        .foregroundStyle(.secondary)
    }
}

struct EventCountdownActionButtonRow: View {

    private let model: EventCountdownActivityViewModel
    init(model: EventCountdownActivityViewModel) {
        self.model = model
    }

    var body: some View {
        HStack(spacing: 8) {
            if let todoId = model.todoId {
                Toggle(
                    isOn: false,
                    intent: CompleteTodoAndEndLiveActivityIntent(todoId: todoId)
                ) {
                    Text("common.done".localized())
                        .frame(maxWidth: .infinity)
                }
                .toggleStyle(.button)
            }

            Button(intent: EndLiveActivityIntent()) {
                Text("liveActivity::action::end".localized())
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
    }
}
