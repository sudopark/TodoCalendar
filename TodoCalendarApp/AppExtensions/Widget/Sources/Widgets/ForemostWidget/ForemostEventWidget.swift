//
//  ForemostEventWidget.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/19/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import AppIntents
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation
import WidgetScenes


// MARK: - ForemostTodoToggleButton

struct ForemostTodoToggleButton: View {
    let todo: TodoEventCellViewModel
    let colorSet: ColorSet
    
    var body: some View {
        Toggle(
            "", isOn: false,
            intent: TodoToggleIntent(id: todo.eventIdentifier, isForemost: true)
        )
        .toggleStyle(ForemostTodoToggleStyle(colorSet: colorSet))
    }
}


// MARK: - ForemostEventWidgetView

struct ForemostEventWidgetView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family: WidgetFamily
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let entry: ResultTimelineEntry<ForemostEventWidgetViewModel>
    init(entry: ResultTimelineEntry<ForemostEventWidgetViewModel>) {
        self.entry = entry
    }
    
    var body: some View {
        switch self.entry.result {
        case .success(let model) where family == .accessoryInline:
            InlineSizeForemostEventView(model: model)
                .widgetURL(model.eventModel?.widgetURL)
                .widgetAccentable()
        case .success(let model) where family == .systemSmall:
            self.systemSizeView(model, isSmallSize: true)
        case .success(let model):
            self.systemSizeView(model, isSmallSize: false)
        case .failure(let error):
            FailView(errorModel: error)
        }
    }

    private func systemSizeView(
        _ model: ForemostEventWidgetViewModel, isSmallSize: Bool
    ) -> some View {
        let colorSet = model.widgetSetting.background.colorSet(colorScheme == .light)
        return SystemSizeForemostEventView(model: model, isSmallSize: isSmallSize) { todo in
            AnyView(ForemostTodoToggleButton(todo: todo, colorSet: colorSet))
        }
    }
}

// MARK: - ForemostEventWidget

struct ForemostEventWidget: Widget {
    
    nonisolated static let kind: String = "ForemostEventWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ForemostEventWidget.kind, provider: ForemostEventWidgetTimelineProvider()) { entry in
            ForemostEventWidgetView(entry: entry)
                .containerBackground(entry.backgroundShape, for: .widget)
        }
        .supportedFamilies([.accessoryInline, .systemSmall, .systemMedium])
        .configurationDisplayName("widget.events.foremost".localized())
        .description("widget.common::explain".localized())
    }
}

// MARK: - preview

struct ForemostEventWidget_PreviewProvider: PreviewProvider {
    
    static var previews: some View {
        
        let sample = ForemostEventWidgetViewModel.sample()
//            |> \.eventModel .~ nil
        
        let entry = ResultTimelineEntry(date: Date(), result: .success(sample))

        Group {
            ForemostEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .containerBackground(.background, for: .widget)
            ForemostEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.background, for: .widget)
            ForemostEventWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(.background, for: .widget)
        }
    }
}
