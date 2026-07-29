//
//  DDayWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Prelude
import Optics
import Domain
import Extensions


// MARK: - DDayWidgetView

struct DDaySmallWidgetView: View {

    private let model: DDayWidgetViewModel
    init(model: DDayWidgetViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.eventTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text(model.ddayText)
                .font(.system(size: 32, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DDayMediumWidgetView: View {

    private let model: DDayWidgetViewModel
    init(model: DDayWidgetViewModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.eventTitle)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline) {
                Text(model.ddayText)
                    .font(.system(size: 36, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                Text(model.targetDateText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
        let entry = ResultTimelineEntry(date: Date(), result: .success(DDayWidgetViewModel.sample))

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
