//
//  ComposedWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CalendarPresentation


// MARK: - DoubleMonthWidgetContentView

public struct DoubleMonthWidgetContentView: View {
    
    private let model: DoubleMonthWidgetViewModel
    
    public init(model: DoubleMonthWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        HStack {
            SingleMonthView(model: model.current)
            SingleMonthView(model: model.next)
        }
    }
}


// MARK: - TodayAndMonthWidgetContentView

public struct TodayAndMonthWidgetContentView: View {
    
    private let model: TodayAndMonthWidgetViewModel
    
    public init(model: TodayAndMonthWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            TodaySummaryView(model: model.today)
            SingleMonthView(model: model.month)
        }
    }
}


// MARK: - EventAndMonthWidgetContentView

public struct EventAndMonthWidgetContentView: View {
    
    private let model: EventAndMonthWidgetViewModel
    private let todoToggle: (TodoEventCellViewModel) -> AnyView
    
    public init(
        model: EventAndMonthWidgetViewModel,
        todoToggle: @escaping (TodoEventCellViewModel) -> AnyView
    ) {
        self.model = model
        self.todoToggle = todoToggle
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            EventListView(model: model.event, todoToggle: todoToggle)
            SingleMonthView(model: model.month)
        }
    }
}


// MARK: - EventAndForemostWidgetContentView

public struct EventAndForemostWidgetContentView: View {
    
    private let model: EventAndForemostWidgetViewModel
    private let todoToggle: (TodoEventCellViewModel) -> AnyView
    private let foremostTodoToggle: (TodoEventCellViewModel) -> AnyView
    
    public init(
        model: EventAndForemostWidgetViewModel,
        todoToggle: @escaping (TodoEventCellViewModel) -> AnyView,
        foremostTodoToggle: @escaping (TodoEventCellViewModel) -> AnyView
    ) {
        self.model = model
        self.todoToggle = todoToggle
        self.foremostTodoToggle = foremostTodoToggle
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            EventListView(model: model.event, todoToggle: todoToggle)
            SystemSizeForemostEventView(
                model: model.foremost,
                isSmallSize: true,
                todoToggle: foremostTodoToggle
            )
        }
    }
}
