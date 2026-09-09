//
//  TodayAndNextWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 12/21/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation
import WidgetScenes


// MARK: - entry view

struct TodayAndNextWidgetEntryView: View {
    
    @Environment(\.colorScheme) var colorScheme

    private let entry: ResultTimelineEntry<TodayAndNextWidgetViewModel>
    init(entry: ResultTimelineEntry<TodayAndNextWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            let colorSet = model.widgetSetting.background.colorSet(colorScheme == .light)
            TodayAndNextWidgetView(model: model) { todo, color in
                AnyView(
                    TodoToggleButton(
                        todo: todo, colorSet: colorSet, size: 16, customColor: color
                    )
                )
            }
            
        case .failure(let errorModel):
            FailView(errorModel: errorModel)
        }
    }
}


// MARK: - widget

struct TodayAndNextWidget: Widget {
    
    nonisolated static let kind: String = "TodayAndNextWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: EventListComponentSelectIntent.self,
            provider: TodayAndNextWidgetTimeLineProvider()
        ) { entry in
            
            TodayAndNextWidgetEntryView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.next.title::future".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - preview

struct TodayAndNextWidgetView_Provider: PreviewProvider {
    
    static var previews: some View {
        
        var model = TodayAndNextWidgetViewModel.sample()
        var today = model.left.rows.first as? TodayAndNextWidgetViewModel.TodayModel
//        today?.holidays = ["삼일절"]
//        today?.timeZonetext = "UTC+9"
        model.left.rows[0] = today!
        
        // test uncompleted
        let uncompleted = TodayAndNextWidgetViewModel.UncompletedTodayTodoSummaryModel(
            [
                TodoCalendarEvent(TodoEvent(uuid: "t1", name: "todo1") |> \.eventTagId .~ .default, in: .current),
                TodoCalendarEvent(TodoEvent(uuid: "t2", name: "todo2") |> \.eventTagId .~ .default, in: .current)
            ]
        )
        model.left.rows.insert(uncompleted!, at: 1)
        
        // test holiday
        let holiday = HolidayEventCellViewModel(
            HolidayCalendarEvent(
                Holiday(uuid: "h", dateString: "2025-12-25", name: "크리스마스"),
                in: .current
            )!
        )
        model.left.rows.insert(TodayAndNextWidgetViewModel.EventModel(cvm: holiday), at: 2)
        
        // test multiple
//        var right = model.right
//        let multiple = TodayAndNextWidgetViewModel.MultipleEventsSummaryModel([
//            right.rows[2] as! TodayAndNextWidgetViewModel.EventModel,
//            right.rows[3] as! TodayAndNextWidgetViewModel.EventModel
//        ])
//        right.rows[right.rows.count-1] = multiple
//        model.right = right
        
        // test empty
//        model.left.rows = [model.left.rows.first!]
//        model.right.rows = []
        
        return TodayAndNextWidgetView(model: model) { todo, color in
            AnyView(
                TodoToggleButton(
                    todo: todo,
                    colorSet: model.widgetSetting.background.colorSet(true),
                    size: 16, customColor: color
                )
            )
        }
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .containerBackground(.background, for: .widget)
    }
}
