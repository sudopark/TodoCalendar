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
import CalendarPresentation
import WidgetScenes


// MARK: - TodayAndMonthWidgetView

struct TodayAndMonthWidgetView: View {
    
    private let entry: ResultTimelineEntry<TodayAndMonthWidgetViewModel>
    init(entry: ResultTimelineEntry<TodayAndMonthWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            TodayAndMonthWidgetContentView(model: model)
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
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.todayAndMonth::name".localized())
        .description("widget.common::explain".localized())
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
