//
//  TodoCalendarWidgetBundle.swift
//  TodoCalendarWidget
//
//  Created by sudo.park on 5/18/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct TodoCalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonthWidget()
        EventListWidget()
        TodayWidget()
        OneWeekEventsWidget()
        TwoWeekEventsWidget()
        ThreeWeekEventsWidget()
        FourWeekEventsWidget()
        CurrentMonthEventsWidget()
        LastMonthEventsWidget()
        NextMonthEventsWidget()
    }
}
