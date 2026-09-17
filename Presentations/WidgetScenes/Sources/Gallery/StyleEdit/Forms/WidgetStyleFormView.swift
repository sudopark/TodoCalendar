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
                TodayStyleFormView(setting: today, onChange: onChange)
            }
        case .todayAndNextMedium, .eventListSmall, .eventListMedium, .eventListLarge,
             .monthSmall, .foremostInline, .foremostSmall, .foremostMedium,
             .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline,
             .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
             .currentMonthEvents, .lastMonthEvents, .nextMonthEvents,
             .aiCommandCircular, .aiCommandSmall, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular, .doubleMonthMedium,
             .eventAndMonthMedium, .eventAndForemostMedium, .todayAndMonthMedium:
            EmptyView()
        }
    }
}
