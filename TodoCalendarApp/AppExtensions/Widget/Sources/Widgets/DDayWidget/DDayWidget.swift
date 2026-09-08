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
import WidgetScenes


// MARK: - EntryView

struct DDayWidgetEntryView: View {

    private let entry: ResultTimelineEntry<DDayWidgetViewModel>

    @Environment(\.widgetFamily) var family: WidgetFamily

    init(entry: ResultTimelineEntry<DDayWidgetViewModel>) {
        self.entry = entry
    }

    var body: some View {
        switch self.entry.result {
        // accessory 케이스는 포괄 `.success`보다 앞에 둔다 — 뒤에 두면 소형 뷰가 잠금화면에 나온다
        case .success(let model) where family == .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                DDayCircularWidgetView(model: model)
            }
            .widgetURL(model.link)

        case .success(let model) where family == .accessoryRectangular:
            DDayRectangularWidgetView(model: model)
                .widgetURL(model.link)

        case .success(let model) where family == .accessoryInline:
            DDayInlineWidgetView(model: model)
                .widgetURL(model.link)

        case .success(let model) where family == .systemMedium:
            DDayMediumWidgetView(model: model)
                .widgetURL(model.link)

        case .success(let model):
            DDaySmallWidgetView(model: model)
                .widgetURL(model.link)

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
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
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

            DDayWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))

            DDayWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))

            DDayWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
        }
    }
}
