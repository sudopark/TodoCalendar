//
//  MonthWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 5/25/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Domain
import Extensions
import CalendarPresentation
import WidgetScenes


// MARK: - MonthWidgetView

struct MonthWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme

    private let entry: ResultTimelineEntry<MonthWidgetViewModel>
    init(entry: ResultTimelineEntry<MonthWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            SingleMonthView(model: model)
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - MonthWidget

struct MonthWidget: Widget {
    
    let kind: String = "MonthWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: self.kind, provider: MonthWidgetTimelineProvider()) { entry in
            MonthWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("widget.events.calendar".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct MonthWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let components = self.makeDummyComponent()
        let model = MonthWidgetViewModel(
            Date(),
            .sunday,
            TimeZone(abbreviation: "KST")!,
            components,
            "2024-9-4"
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
//        let entry = ResultTimelineEntry<MonthWidgetViewModel>(date: Date(), result: .failure(
//            .init(error: RuntimeError("failed"), message: "Fail to load widget")
//        ))
        return MonthWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .containerBackground(.background, for: .widget)
    }
    
    private static func makeDummyComponent() -> CalendarComponent {
        let weekAndDays: [[(Int, Int)]] = [
            [(8, 27), (8, 28), (8, 29), (8, 30), (8, 31), (9, 1), (9, 2)],
            [(9, 3), (9, 4), (9, 5), (9, 6), (9, 7), (9, 8), (9, 9)],
            [(9, 10), (9, 11), (9, 12), (9, 13), (9, 14), (9, 15), (9, 16)],
            [(9, 17), (9, 18), (9, 19), (9, 20), (9, 21), (9, 22), (9, 23)],
            [(9, 24), (9, 25), (9, 26), (9, 27), (9, 28), (9, 29), (9, 30)]
        ]
        let weeks = weekAndDays.map { pairs -> CalendarComponent.Week in
            let days = pairs.enumerated().map { offset, pair -> CalendarComponent.Day in
                var day =  CalendarComponent.Day(year: 2024, month: pair.0, day: pair.1, weekDay: offset+1)
                if day.identifier == "2024-9-11" || day.identifier == "2024-9-12" || day.identifier == "2024-9-13" {
                    day.holidays = [.init(uuid: "hd", dateString: day.identifier, name: "some")]
                }
                return day
            }
            return CalendarComponent.Week(days: days)
        }
        return CalendarComponent(
            year: 2024, month: 9, weeks: weeks
        )
    }
}
