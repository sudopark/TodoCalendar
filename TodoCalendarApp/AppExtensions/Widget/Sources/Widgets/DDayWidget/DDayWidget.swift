//
//  DDayWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Prelude
import Optics
import Domain
import Extensions


// MARK: - 공통 조각

private struct DDayTitleView: View {

    private let model: DDayWidgetViewModel
    private let fontSize: CGFloat
    private let lineLimit: Int

    init(model: DDayWidgetViewModel, fontSize: CGFloat, lineLimit: Int) {
        self.model = model
        self.fontSize = fontSize
        self.lineLimit = lineLimit
    }

    var body: some View {
        HStack(spacing: 3) {
            if model.isRepeating {
                Image(systemName: "repeat")
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(.secondary)
            }
            Text(model.eventTitle)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(lineLimit)
                .foregroundStyle(.primary)
        }
    }
}

private extension DDayWidgetViewModel {

    /// 소형 하단 한 줄 — "매주 월 · 3/15 오전 7:00". 빈 조각은 뺀다.
    var compactDetailText: String {
        return [self.repeatText, self.dateText, self.timeText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// 중형 우측 둘째 줄 — "오전 7:00 · 매주 월".
    var detailText: String {
        return [self.timeText, self.repeatText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}


// MARK: - 소형

struct DDaySmallWidgetView: View {

    private let model: DDayWidgetViewModel
    init(model: DDayWidgetViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DDayTitleView(model: model, fontSize: 13, lineLimit: 2)

            Spacer(minLength: 0)

            Text(model.ddayText)
                .font(.system(size: 32, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if !model.compactDetailText.isEmpty {
                Text(model.compactDetailText)
                    .font(.system(size: 11))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - 중형

struct DDayMediumWidgetView: View {

    private let model: DDayWidgetViewModel
    init(model: DDayWidgetViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DDayTitleView(model: model, fontSize: 15, lineLimit: 1)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline) {
                Text(model.ddayText)
                    .font(.system(size: 36, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if !model.dateText.isEmpty {
                        Text(model.dateText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }

                    if !model.detailText.isEmpty {
                        Text(model.detailText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - EntryView

struct DDayWidgetEntryView: View {

    private let entry: ResultTimelineEntry<DDayWidgetViewModel>

    @Environment(\.widgetFamily) var family: WidgetFamily

    init(entry: ResultTimelineEntry<DDayWidgetViewModel>) {
        self.entry = entry
    }

    var body: some View {
        switch self.entry.result {
        case .success(let model) where family == .systemMedium:
            DDayMediumWidgetView(model: model)

        case .success(let model):
            DDaySmallWidgetView(model: model)

        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - DDayWidget

struct DDayWidget: Widget {

    nonisolated static let kind: String = "DDayWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: DDayWidgetConfigurationIntent.self,
            provider: DDayWidgetTimeLineProvider()
        ) { entry in
            DDayWidgetEntryView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("widget.dday::name".localized())
        .description("widget.common::explain".localized())
    }
}


struct DDayWidgetView_Provider: PreviewProvider {

    static var previews: some View {
        let entry = ResultTimelineEntry(
            date: Date(), result: .success(DDayWidgetViewModel.sample)
        )

        return Group {
            DDayWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.background, for: .widget)

            DDayWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(.background, for: .widget)
        }
    }
}
