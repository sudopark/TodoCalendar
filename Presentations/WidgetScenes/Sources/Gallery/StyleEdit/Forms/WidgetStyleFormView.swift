//
//  WidgetStyleFormView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions


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
        case .todayAndNextMedium:
            if let todayAndNext = setting as? TodayAndNextStyleSetting {
                WidgetStyleToggleFormView<TodayAndNextStyleItem>(
                    setting: todayAndNext, onChange: onChange
                )
            }
        case .foremostSmall, .foremostMedium:
            if let foremost = setting as? ForemostStyleSetting {
                WidgetStyleToggleFormView<ForemostStyleItem>(
                    setting: foremost, onChange: onChange
                )
            }
        case .aiCommandSmall:
            if let aiCommand = setting as? AICommandStyleSetting {
                WidgetStyleToggleFormView<AICommandStyleItem>(
                    setting: aiCommand, onChange: onChange
                )
            }
        case .doubleMonthMedium:
            if let composed = setting as? DoubleMonthStyleSetting {
                WidgetStyleToggleFormView<MonthStyleItem>(
                    title: "widget.events.calendar".localized(),
                    setting: composed.month,
                    onChange: { onChange(composed.replacingPart($0)) }
                )
            }
        case .eventAndMonthMedium:
            if let composed = setting as? EventAndMonthStyleSetting {
                WidgetStyleToggleFormView<MonthStyleItem>(
                    title: "widget.events.calendar".localized(),
                    setting: composed.month,
                    onChange: { onChange(composed.replacingPart($0)) }
                )
            }
        case .eventAndForemostMedium:
            if let composed = setting as? EventAndForemostStyleSetting {
                WidgetStyleToggleFormView<ForemostStyleItem>(
                    title: "widget.events.foremost".localized(),
                    setting: composed.foremost,
                    onChange: { onChange(composed.replacingPart($0)) }
                )
            }
        case .todayAndMonthMedium:
            if let composed = setting as? TodayAndMonthStyleSetting {
                WidgetStyleToggleFormView<TodayStyleItem>(
                    title: "widget.events.today".localized(),
                    setting: composed.today,
                    onChange: { onChange(composed.replacingPart($0)) }
                )
                WidgetStyleToggleFormView<MonthStyleItem>(
                    title: "widget.events.calendar".localized(),
                    setting: composed.month,
                    onChange: { onChange(composed.replacingPart($0)) }
                )
            }
        // EventList 는 끄고 켤 항목이 없다 — 편집 화면엔 이름·배경색 섹션만 선다.
        case .eventListSmall, .eventListMedium, .eventListLarge,
             .foremostInline,
             .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline,
             .aiCommandCircular, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular:
            EmptyView()
        }
    }
}
