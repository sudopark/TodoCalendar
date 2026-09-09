//
//  ComposedWidgetViewModels.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct DoubleMonthWidgetViewModel {

    public var current: MonthWidgetViewModel
    public var next: MonthWidgetViewModel

    public init(current: MonthWidgetViewModel, next: MonthWidgetViewModel) {
        self.current = current
        self.next = next
    }
}


public struct EventAndForemostWidgetViewModel {

    public var event: EventListWidgetViewModel
    public var foremost: ForemostEventWidgetViewModel

    public init(event: EventListWidgetViewModel, foremost: ForemostEventWidgetViewModel) {
        self.event = event
        self.foremost = foremost
    }
}


public struct EventAndMonthWidgetViewModel {

    public var event: EventListWidgetViewModel
    public var month: MonthWidgetViewModel

    public init(event: EventListWidgetViewModel, month: MonthWidgetViewModel) {
        self.event = event
        self.month = month
    }
}


public struct TodayAndMonthWidgetViewModel {

    public var today: TodayWidgetViewModel
    public var month: MonthWidgetViewModel

    public init(today: TodayWidgetViewModel, month: MonthWidgetViewModel) {
        self.today = today
        self.month = month
    }
}



// MARK: - ComposedWidgetSampleFactory

/// Month 샘플이 throws 라 Month 를 담는 셋만 Optional 을 낸다.
public struct ComposedWidgetSampleFactory: Sendable {
    
    public init() { }
    
    public func doubleMonth() -> DoubleMonthWidgetViewModel? {
        guard let current = try? MonthWidgetViewModel.makeSample(),
              let next = try? MonthWidgetViewModel.makeSampleNextMonth()
        else { return nil }
        return .init(current: current, next: next)
    }
    
    public func eventAndForemost() -> EventAndForemostWidgetViewModel {
        return .init(event: .sample(size: .medium), foremost: .sample())
    }
    
    public func eventAndMonth() -> EventAndMonthWidgetViewModel? {
        guard let month = try? MonthWidgetViewModel.makeSample() else { return nil }
        return .init(event: .sample(size: .medium), month: month)
    }
    
    public func todayAndMonth() -> TodayAndMonthWidgetViewModel? {
        guard let month = try? MonthWidgetViewModel.makeSample() else { return nil }
        return .init(today: .sample(), month: month)
    }
}
