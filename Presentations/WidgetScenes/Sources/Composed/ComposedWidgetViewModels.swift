//
//  ComposedWidgetViewModels.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct DoubleMonthWidgetViewModel {

    public let current: MonthWidgetViewModel
    public let next: MonthWidgetViewModel

    public init(current: MonthWidgetViewModel, next: MonthWidgetViewModel) {
        self.current = current
        self.next = next
    }
}


public struct EventAndForemostWidgetViewModel {

    public let event: EventListWidgetViewModel
    public let foremost: ForemostEventWidgetViewModel

    public init(event: EventListWidgetViewModel, foremost: ForemostEventWidgetViewModel) {
        self.event = event
        self.foremost = foremost
    }
}


public struct EventAndMonthWidgetViewModel {

    public let event: EventListWidgetViewModel
    public let month: MonthWidgetViewModel

    public init(event: EventListWidgetViewModel, month: MonthWidgetViewModel) {
        self.event = event
        self.month = month
    }
}


public struct TodayAndMonthWidgetViewModel {

    public let today: TodayWidgetViewModel
    public let month: MonthWidgetViewModel

    public init(today: TodayWidgetViewModel, month: MonthWidgetViewModel) {
        self.today = today
        self.month = month
    }
}
