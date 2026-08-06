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
        // #741 D-day 위젯 배포 보류 — 갤러리 노출을 끈다.
        // 여기만 FeatureFlag가 아닌 주석인 이유: @WidgetBundleBuilder는 런타임 조건(`if`)을
        // 받지 못한다(컴파일 실패). 앱 쪽 후보 등록 메뉴는 FeatureFlag.ddayWidget이 가린다.
        // 재개 시 이 줄과 그 플래그를 함께 되살릴 것.
//        DDayWidget()
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
