//
//  TodayWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import WidgetScenes


// MARK: - TodayWidgetView

struct TodayWidgetView: View {
    
    private let entry: ResultTimelineEntry<TodayWidgetViewModel>
    init(entry: ResultTimelineEntry<TodayWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            TodaySummaryView(model: model)
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - TodayWidget

struct TodayWidget: Widget {
    
    let kind: String = "TodaySummary"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWidgetTimelineProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("widget.events.today".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct TodayWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = TodayWidgetViewModel.sample()
//        |> \.timeZoneText .~ "GMT+9"
//        |> \.holidayName .~ "Christmas"
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        return TodayWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .containerBackground(.background, for: .widget)
    }
}
