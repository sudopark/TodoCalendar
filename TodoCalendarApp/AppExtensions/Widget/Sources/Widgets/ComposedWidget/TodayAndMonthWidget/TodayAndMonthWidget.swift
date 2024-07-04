//
//  TodayAndMonthWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarScenes


// MARK: - TodayAndMonthWidgetView

struct TodayAndMonthWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultLightColorSet()
    }
    
    private let entry: ResultTimelineEntry<TodayAndMonthWidgetViewModel>
    init(entry: ResultTimelineEntry<TodayAndMonthWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            HStack(spacing: 12) {
                TodaySummaryView(model: model.today)
                SingleMonthView(model: model.month)
            }
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - TodayAndMonthWidget

struct TodayAndMonthWidget: Widget {
    
    let kind = "TodayAndMonthWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayAndMonthWidgetTimelineProvider()) { entry in
            TodayAndMonthWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("TODO: My Widget")
        .description("TODO: This is an example widget.")
    }
}


// MARK: - preview

struct TodayAndMonthWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = TodayAndMonthWidgetViewModel(
            today: TodayWidgetViewModel.sample(),
            month: try! MonthWidgetViewModel.makeSample()
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        return TodayAndMonthWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .containerBackground(.background, for: .widget)
    }
}
