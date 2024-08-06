//
//  EventAndMonthWidget.swift
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


// MARK: - EventAndMonthWidgetView

struct EventAndMonthWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let entry: ResultTimelineEntry<EventAndMonthWidgetViewModel>
    init(entry: ResultTimelineEntry<EventAndMonthWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            HStack(spacing: 12) {
                EventListView(model: model.event)
                SingleMonthView(model: model.month)
            }
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - EventAndMonthWidget

struct EventAndMonthWidget: Widget {
    
    let kind = "EventAndMonthWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventAndMonthWidgetTimelineProvider()) { entry in
            EventAndMonthWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("TODO: My Widget")
        .description("TODO: This is an example widget.")
    }
}


// MARK: - preview

struct EventAndMonthWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let model = EventAndMonthWidgetViewModel(
            event: EventListWidgetViewModel.sample(maxItemCount: 3),
            month: try! MonthWidgetViewModel.makeSample()
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        return EventAndMonthWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .containerBackground(.background, for: .widget)
    }
}
