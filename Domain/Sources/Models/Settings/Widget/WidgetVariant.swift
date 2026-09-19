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
        return self.settingType != nil
    }

    /// 변형마다 담는 꾸미기 항목이 달라 payload 타입이 갈린다.
    public var settingType: (any WidgetStyleSetting.Type)? {
        switch self {
        case .todaySummarySmall:
            return TodayStyleSetting.self
        case .monthSmall:
            return MonthStyleSetting.self
        case .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
             .currentMonthEvents, .lastMonthEvents, .nextMonthEvents:
            return WeekEventsStyleSetting.self
        case .todayAndNextMedium:
            return TodayAndNextStyleSetting.self
        case .eventListSmall, .eventListMedium, .eventListLarge:
            return EventListStyleSetting.self
        case .foremostSmall, .foremostMedium:
            return ForemostStyleSetting.self
        case .aiCommandSmall:
            return AICommandStyleSetting.self
        case .foremostInline,
             .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline,
             .aiCommandCircular, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular, .doubleMonthMedium,
             .eventAndMonthMedium, .eventAndForemostMedium, .todayAndMonthMedium:
            return nil
        }
    }

    /// 스타일을 공유하는 변형군의 대표 변형 — 저장 좌표는 이 값으로 접힌다.
    public var styleVariant: WidgetVariant {
        switch self {
        case .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
             .currentMonthEvents, .lastMonthEvents, .nextMonthEvents:
            return .oneWeekEvents
        case .eventListSmall, .eventListMedium, .eventListLarge:
            return .eventListSmall
        case .foremostSmall, .foremostMedium:
            return .foremostSmall
        case .todayAndNextMedium, .monthSmall, .todaySummarySmall, .foremostInline,
             .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular,
             .ddayInline, .aiCommandCircular, .aiCommandSmall, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular, .doubleMonthMedium,
             .eventAndMonthMedium, .eventAndForemostMedium, .todayAndMonthMedium:
            return self
        }
    }

    /// 이 변형과 스타일을 공유하는 변형 전부 — 자기 자신을 포함한다.
    public var styleSharingVariants: [WidgetVariant] {
        return Self.allCases.filter { $0.styleVariant == self.styleVariant }
    }

    public var initialSetting: (any WidgetStyleSetting)? {
        return self.settingType.map { self.initial(of: $0) }
    }

    public func isOwnSetting(_ setting: any WidgetStyleSetting) -> Bool {
        return self.settingType.map { self.isInstance(setting, of: $0) } ?? false
    }

    private func initial<S: WidgetStyleSetting>(of type: S.Type) -> any WidgetStyleSetting {
        return S.initial
    }

    private func isInstance<S: WidgetStyleSetting>(
        _ setting: any WidgetStyleSetting, of type: S.Type
    ) -> Bool {
        return setting is S
    }
}
