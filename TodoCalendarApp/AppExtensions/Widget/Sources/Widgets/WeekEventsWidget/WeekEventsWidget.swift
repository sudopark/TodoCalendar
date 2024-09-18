//
//  WeekEventsWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/30/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarScenes

// MARK: - WeekEventsWidgetView

struct WeekEventsWidgetView: View {
 
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let entry: ResultTimelineEntry<WeekEventsViewModel>
    init(
        entry: ResultTimelineEntry<WeekEventsViewModel>
    ) {
        self.entry = entry
    }
    
    var body: some View {
        VStack {
            switch entry.result {
            case .success(let model):
                WeekEventsView(model: model)
            case .failure(let error):
                FailView(errorModel: error)
            }
        }
    }
}


// MARK: - OneWeekEventsWidget

struct OneWeekEventsWidget: Widget {
    
    let kind: String = "OneWeekEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.weeks(count: 1))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.weeks.thisWeek".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - TwoWeekEventsWidget

struct TwoWeekEventsWidget: Widget {
    
    let kind: String = "TwoWeekEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.weeks(count: 2))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.weeks.twoWeek".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - ThreeWeekEventsWidget

struct ThreeWeekEventsWidget: Widget {
    
    let kind: String = "ThreeWeekEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.weeks(count: 3))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("widget.weeks.threeWeek".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - FourWeekEventsWidget

struct FourWeekEventsWidget: Widget {
    
    let kind: String = "FourWeekEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.weeks(count: 4))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("widget.weeks.fourWeek".localized())
        .description("widget.common::explain" .localized())
    }
}

// MARK: - LastMonthEventsWidget

struct LastMonthEventsWidget: Widget {
    
    let kind: String = "LastMonthEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.wholeMonth(.previous))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("widget.weeks.lastMonth".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - CurrentMonthEventsWidget

struct CurrentMonthEventsWidget: Widget {
    
    let kind: String = "CurrentMonthEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.wholeMonth(.current))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("widget.weeks.thisMonth".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - NextMonthEventsWidget

struct NextMonthEventsWidget: Widget {
    
    let kind: String = "NextMonthEventsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: WeekEventsWidgetTimelineProvider(.wholeMonth(.next))) { entry in
            
            WeekEventsWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("widget.weeks.nextMonth".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - Preview

struct WeekEventsWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let sample1 = WeekEventsViewModel.sample(.weeks(count: 1))
        let entry1 = ResultTimelineEntry(date: Date(), result: .success(sample1))
        
        let sample2 = WeekEventsViewModel.sample(.weeks(count: 2))
        let entry2 = ResultTimelineEntry(date: Date(), result: .success(sample2))
        
        let sample3 = WeekEventsViewModel.sample(.weeks(count: 3))
        let entry3 = ResultTimelineEntry(date: Date(), result: .success(sample3))
        
        let sample4 = WeekEventsViewModel.sample(.weeks(count: 4))
        let entry4 = ResultTimelineEntry(date: Date(), result: .success(sample4))
        
        let samplePrevMonth = WeekEventsViewModel.sample(.wholeMonth(.previous))
        let entryPrevious = ResultTimelineEntry(date: Date(), result: .success(samplePrevMonth))
        
        let sampleCurrentMonth = WeekEventsViewModel.sample(.wholeMonth(.current))
        let entryCurrent = ResultTimelineEntry(date: Date(), result: .success(sampleCurrentMonth))
        
        let sampleNextMonth = WeekEventsViewModel.sample(.wholeMonth(.next))
        let entryNext = ResultTimelineEntry(date: Date(), result: .success(sampleNextMonth))
        
        Group {
            WeekEventsWidgetView(entry: entry1)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(.background , for: .widget)
            
            WeekEventsWidgetView(entry: entry2)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(.background , for: .widget)
            
            WeekEventsWidgetView(entry: entry3)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .containerBackground(.background , for: .widget)
            
            WeekEventsWidgetView(entry: entry4)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .containerBackground(.background , for: .widget)
            
            WeekEventsWidgetView(entry: entryPrevious)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .containerBackground(.background , for: .widget)
            
            WeekEventsWidgetView(entry: entryCurrent)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .containerBackground(.background , for: .widget)
            
            WeekEventsWidgetView(entry: entryNext)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .containerBackground(.background , for: .widget)
        }
    }
}

