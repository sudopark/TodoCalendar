//
//  EventAndForemostWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 4/13/25.
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


// MARK: - EventAndForemostWidgetView

struct EventAndForemostWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    private let entry: ResultTimelineEntry<EventAndForemostWidgetViewModel>
    init(entry: ResultTimelineEntry<EventAndForemostWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            let eventColorSet = model.event.widgetSetting.background.colorSet(colorScheme == .light)
            let foremostColorSet = model.foremost.widgetSetting.background.colorSet(colorScheme == .light)
            EventAndForemostWidgetContentView(
                model: model,
                todoToggle: { todo in
                    AnyView(TodoToggleButton(todo: todo, colorSet: eventColorSet))
                },
                foremostTodoToggle: { todo in
                    AnyView(ForemostTodoToggleButton(todo: todo, colorSet: foremostColorSet))
                }
            )
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - EventAndForemostWidget

struct EventAndForemostWidget: Widget {
    
    nonisolated static let kind: String = "EventAndForemostWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: EventAndForemostWidget.kind, provider: EventAndForemostWidgetViewTimelineProvider()) { entry in
            
            EventAndForemostWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("widget.eventAndForesmot::name".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct EventAndForemostWidgetView_previewProvider: PreviewProvider {
    
    static var previews: some View {
        let model = EventAndForemostWidgetViewModel(
            event: EventListWidgetViewModel.sample(size: .small),
            foremost: ForemostEventWidgetViewModel.sample()
            |> \.eventModel .~ nil
        )
        let entry = ResultTimelineEntry(date: Date(), result: .success(model))
        return EventAndForemostWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .containerBackground(.background, for: .widget)
    }
}
