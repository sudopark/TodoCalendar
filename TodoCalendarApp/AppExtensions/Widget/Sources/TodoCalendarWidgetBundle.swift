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
        BaseWidgetBundle().body
        ComposedWidgetBundle().body
        WeeksWidgetBundle().body
    }
}

struct BaseWidgetBundle: WidgetBundle {
    
    var body: some Widget {
        TodayAndNextWidget()
        MonthWidget()
        EventListWidget()
        TodayWidget()
        ForemostEventWidget()
        NextEventWidget()
        NextRemainEventWidget()
        AICommandShortcutWidget()
        EventCountdownLiveActivity()
        DDayWidget()
        if #available(iOS 18.0, *) {
            AICommandControlWidget()
        }
    }
}

struct ComposedWidgetBundle: WidgetBundle {
    
    var body: some Widget {
        DoubleMonthWidget()
        EventAndMonthWidget()
        EventAndForemostWidget()
        TodayAndMonthWidget()
    }
}

struct WeeksWidgetBundle: WidgetBundle {
    
    var body: some Widget {
        OneWeekEventsWidget()
        TwoWeekEventsWidget()
        ThreeWeekEventsWidget()
        FourWeekEventsWidget()
        CurrentMonthEventsWidget()
        LastMonthEventsWidget()
        NextMonthEventsWidget()
    }
}
