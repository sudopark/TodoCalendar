//
//  EventListWidget.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
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


// MARK: - TodoToggleButton

struct TodoToggleButton: View {
    let todo: TodoEventCellViewModel
    let colorSet: ColorSet
    var size: CGFloat = 18
    var customColor: Color?
    
    var body: some View {
        Toggle(
            "", isOn: false,
            intent: TodoToggleIntent(id: todo.eventIdentifier, isForemost: false)
        )
        .toggleStyle(TodoToggleStyle(colorSet: colorSet, size: size, customColor: customColor))
    }
}


// MARK: - EventListWidgetView

struct EventListWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    private let entry: ResultTimelineEntry<EventListWidgetViewModel>
    init(entry: ResultTimelineEntry<EventListWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model):
            let colorSet = model.widgetSetting.background.colorSet(colorScheme == .light)
            EventListView(model: model) { todo in
                AnyView(TodoToggleButton(todo: todo, colorSet: colorSet))
            }
        case .failure(let error):
            FailView(errorModel: error)
        }
    }
}


// MARK: - EventListWidget

struct EventListWidget: Widget {
    
    nonisolated static let kind: String = "EventList"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: EventTypeSelectIntent.self,
            provider: EventListWidgetTimeLineProvider()
        ) { entry in
            EventListWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("widget.events::name".localized())
        .description("widget.common::explain".localized())
    }
}


// MARK: - preview

struct EventListWidgetPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        
        let size: WidgetFamily = .systemMedium
        let sample = EventListWidgetViewModel.sample(size: .init(size))
        let entry = ResultTimelineEntry(date: Date(), result: .success(sample))
        
        return EventListWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: size))
            .containerBackground(.background, for: .widget)
    }
}
