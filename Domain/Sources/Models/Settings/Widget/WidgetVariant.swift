//
//  WidgetVariant.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - WidgetVariant

public enum WidgetVariant: String, Sendable, Identifiable, CaseIterable {

    case todayAndNextMedium
    case eventListSmall
    case eventListMedium
    case eventListLarge
    case monthSmall
    case todaySummarySmall
    case foremostInline
    case foremostSmall
    case foremostMedium
    case ddaySmall
    case ddayMedium
    case ddayCircular
    case ddayRectangular
    case ddayInline
    case oneWeekEvents
    case twoWeekEvents
    case threeWeekEvents
    case fourWeekEvents
    case currentMonthEvents
    case lastMonthEvents
    case nextMonthEvents
    case aiCommandCircular
    case aiCommandSmall
    case nextEventInline
    case nextEventRectangular
    case nextRemainRectangular
    case doubleMonthMedium
    case eventAndMonthMedium
    case eventAndForemostMedium
    case todayAndMonthMedium

    public var id: String { return self.rawValue }

    public var kind: String {
        switch self {
        case .todayAndNextMedium: return "TodayAndNextWidget"
        case .eventListSmall, .eventListMedium, .eventListLarge: return "EventList"
        case .monthSmall: return "MonthWidget"
        case .todaySummarySmall: return "TodaySummary"
        case .foremostInline, .foremostSmall, .foremostMedium: return "ForemostEventWidget"
        case .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline:
            return "DDayWidget"
        case .oneWeekEvents: return "OneWeekEventsWidget"
        case .twoWeekEvents: return "TwoWeekEventsWidget"
        case .threeWeekEvents: return "ThreeWeekEventsWidget"
        case .fourWeekEvents: return "FourWeekEventsWidget"
        case .currentMonthEvents: return "CurrentMonthEventsWidget"
        case .lastMonthEvents: return "LastMonthEventsWidget"
        case .nextMonthEvents: return "NextMonthEventsWidget"
        case .aiCommandCircular, .aiCommandSmall: return "AICommandShortcutWidget"
        case .nextEventInline, .nextEventRectangular: return "NextEventWidget"
        case .nextRemainRectangular: return "NextRemainEventWidget"
        case .doubleMonthMedium: return "DoubleMonthWidget"
        case .eventAndMonthMedium: return "EventAndMonthWidget"
        case .eventAndForemostMedium: return "EventAndForemostWidget"
        case .todayAndMonthMedium: return "TodayAndMonthWidget"
        }
    }

    /// 꾸미기 설정을 갖는 변형만 true. 나머지는 스타일 저장 대상이 아니다.
    public var isCustomizable: Bool {
        switch self {
        case .todaySummarySmall:
            return true
        case .todayAndNextMedium, .eventListSmall, .eventListMedium, .eventListLarge,
             .monthSmall, .foremostInline, .foremostSmall, .foremostMedium,
             .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline,
             .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
             .currentMonthEvents, .lastMonthEvents, .nextMonthEvents,
             .aiCommandCircular, .aiCommandSmall, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular, .doubleMonthMedium,
             .eventAndMonthMedium, .eventAndForemostMedium, .todayAndMonthMedium:
            return false
        }
    }
}
