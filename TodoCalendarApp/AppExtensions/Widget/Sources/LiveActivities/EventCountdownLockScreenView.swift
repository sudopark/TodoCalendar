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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                EventCountdownSymbolBadge(diameter: 20)

                // 이름 쪽만 무한 확장을 허용한다 — HStack이 덜 유연한 카운트다운에 고유 폭을 먼저 준다.
                EventCountdownEventNameText(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)

                EventCountdownTimerText(
                    model: model, isStale: isStale,
                    liveFont: .system(size: 24, weight: .semibold),
                    staleFont: .system(size: 15)
                )
                // 폭이 모자라면 Text(timerInterval:)은 말줄임이 아니라 자릿수를 --로 대체한다 — 최대 표기 "23:59:59" 폭을 바닥으로 깐다.
                .frame(minWidth: 104, alignment: .trailing)
            }

            EventCountdownTimeAndSubtitleText(model: model, font: .system(size: 12))

            EventCountdownProgressBar(model: model)

            Divider()

            EventCountdownActionButtonRow(model: model)
        }
        .padding(16)
        .widgetURL(model.deepLink)
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

struct EventCountdownProgressBar: View {

    private let model: EventCountdownActivityViewModel
    init(model: EventCountdownActivityViewModel) {
        self.model = model
    }

    var body: some View {
        // 만료 후에는 timerInterval range가 역전돼 트랩하므로 바 자체를 그리지 않는다.
        if model.eventDate > .now, model.startDate < model.eventDate {
            ProgressView(timerInterval: model.startDate...model.eventDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(model.tagColor)
        }
    }
}

struct EventCountdownEventNameText: View {

    private let model: EventCountdownActivityViewModel
    init(model: EventCountdownActivityViewModel) {
        self.model = model
    }

    var body: some View {
        Text(model.eventName)
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
    }
}

struct EventCountdownTitleBlock: View {

    private let model: EventCountdownActivityViewModel
    init(model: EventCountdownActivityViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            EventCountdownEventNameText(model: model)

            EventCountdownTimeAndSubtitleText(model: model, font: .system(size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(spacing: 6) {
            Circle()
                .fill(model.tagColor)
                .frame(width: 7, height: 7)

            Text(model.eventTimeText)

            if let subtitle = model.subtitle {
                Text(verbatim: "·")

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
        .controlSize(.small)
    }
}
