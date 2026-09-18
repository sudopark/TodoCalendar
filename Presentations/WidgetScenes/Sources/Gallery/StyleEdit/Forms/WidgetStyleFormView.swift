//
//  WidgetStyleFormView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain


// MARK: - variant style form

extension WidgetVariant {

    @MainActor
    @ViewBuilder
    func styleFormView(
        setting: any WidgetStyleSetting,
        onChange: @escaping (any WidgetStyleSetting) -> Void
    ) -> some View {
        switch self {
        case .todaySummarySmall:
            if let today = setting as? TodayStyleSetting {
                WidgetStyleToggleFormView<TodayStyleItem>(setting: today, onChange: onChange)
            }
        case .monthSmall:
            if let month = setting as? MonthStyleSetting {
                WidgetStyleToggleFormView<MonthStyleItem>(setting: month, onChange: onChange)
            }
        case .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
             .currentMonthEvents, .lastMonthEvents, .nextMonthEvents:
            if let weekEvents = setting as? WeekEventsStyleSetting {
                WidgetStyleToggleFormView<WeekEventsStyleItem>(
                    setting: weekEvents, onChange: onChange
                )
            }
        case .todayAndNextMedium, .eventListSmall, .eventListMedium, .eventListLarge,
             .foremostInline, .foremostSmall, .foremostMedium,
             .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline,
             .aiCommandCircular, .aiCommandSmall, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular, .doubleMonthMedium,
             .eventAndMonthMedium, .eventAndForemostMedium, .todayAndMonthMedium:
            EmptyView()
        }
    }
}
