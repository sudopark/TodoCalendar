//
//  WidgetGalleryItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


// MARK: - WidgetPreviewCanvas

public enum WidgetPreviewCanvas: String, Sendable {

    case systemSmall
    case systemMedium
    case systemLarge
    case accessoryInline
    case accessoryRectangular
    case accessoryCircular

    public var isLockScreen: Bool {
        switch self {
        case .systemSmall, .systemMedium, .systemLarge: return false
        case .accessoryInline, .accessoryRectangular, .accessoryCircular: return true
        }
    }

    public var sizeLabel: String {
        switch self {
        case .systemSmall: return "widget.size::small".localized()
        case .systemMedium: return "widget.size::medium".localized()
        case .systemLarge: return "widget.size::large".localized()
        case .accessoryInline: return "widget.size::inline".localized()
        case .accessoryRectangular: return "widget.size::rectangular".localized()
        case .accessoryCircular: return "widget.size::circular".localized()
        }
    }
}


// MARK: - WidgetVariant + gallery presentation

extension WidgetVariant {

    public var canvas: WidgetPreviewCanvas {
        switch self {
        case .eventListSmall, .monthSmall, .todaySummarySmall, .foremostSmall,
             .ddaySmall, .aiCommandSmall:
            return .systemSmall
        case .todayAndNextMedium, .eventListMedium, .foremostMedium, .ddayMedium,
             .oneWeekEvents, .twoWeekEvents, .doubleMonthMedium, .eventAndMonthMedium,
             .eventAndForemostMedium, .todayAndMonthMedium:
            return .systemMedium
        case .eventListLarge, .threeWeekEvents, .fourWeekEvents,
             .currentMonthEvents, .lastMonthEvents, .nextMonthEvents:
            return .systemLarge
        case .foremostInline, .ddayInline, .nextEventInline:
            return .accessoryInline
        case .ddayRectangular, .nextEventRectangular, .nextRemainRectangular:
            return .accessoryRectangular
        case .ddayCircular, .aiCommandCircular:
            return .accessoryCircular
        }
    }

    /// 목록 칩에 들어가는 짧은 이름. 대부분 사이즈고, 주 단위만 기간이다.
    public var label: String {
        switch self {
        case .oneWeekEvents: return "widget.weeks.thisWeek".localized()
        case .twoWeekEvents: return "widget.weeks.twoWeek".localized()
        case .threeWeekEvents: return "widget.weeks.threeWeek".localized()
        case .fourWeekEvents: return "widget.weeks.fourWeek".localized()
        case .currentMonthEvents: return "widget.weeks.thisMonth".localized()
        case .lastMonthEvents: return "widget.weeks.lastMonth".localized()
        case .nextMonthEvents: return "widget.weeks.nextMonth".localized()
        case .todayAndNextMedium, .eventListSmall, .eventListMedium, .eventListLarge,
             .monthSmall, .todaySummarySmall, .foremostInline, .foremostSmall,
             .foremostMedium, .ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular,
             .ddayInline, .aiCommandCircular, .aiCommandSmall, .nextEventInline,
             .nextEventRectangular, .nextRemainRectangular, .doubleMonthMedium,
             .eventAndMonthMedium, .eventAndForemostMedium, .todayAndMonthMedium:
            return self.canvas.sizeLabel
        }
    }

    /// 2뎁스 미리보기 아래 이름. 잠금화면 변형은 어디에 놓이는지까지 알린다.
    public var detailLabel: String {
        guard self.canvas.isLockScreen else { return self.label }
        return "widget.gallery::lockScreen::label".localized(with: self.label)
    }
}


// MARK: - WidgetGalleryItem

public enum WidgetGalleryItem: String, Sendable, Identifiable, CaseIterable {

    case todayAndNext
    case eventList
    case month
    case todaySummary
    case foremost
    case dday
    case weekEvents
    case aiCommand
    case nextEvent
    case nextRemain
    case doubleMonth
    case eventAndMonth
    case eventAndForemost
    case todayAndMonth

    public var id: String { return self.rawValue }

    public var name: String {
        switch self {
        case .todayAndNext: return "widget.next.title::future".localized()
        case .eventList: return "widget.events::name".localized()
        case .month: return "widget.events.calendar".localized()
        case .todaySummary: return "widget.events.today".localized()
        case .foremost: return "widget.events.foremost".localized()
        case .dday: return "widget.dday::name".localized()
        case .weekEvents: return "widget.weeks::group".localized()
        case .aiCommand: return "widget.aiCommand::title".localized()
        case .nextEvent: return "widget.next.title".localized()
        case .nextRemain: return "widget.next.title::remains".localized()
        case .doubleMonth: return "widget.doubleMonth::name".localized()
        case .eventAndMonth: return "widget.eventAndMonth::name".localized()
        case .eventAndForemost: return "widget.eventAndForesmot::name".localized()
        case .todayAndMonth: return "widget.todayAndMonth::name".localized()
        }
    }

    public var variants: [WidgetVariant] {
        switch self {
        case .todayAndNext: return [.todayAndNextMedium]
        case .eventList: return [.eventListSmall, .eventListMedium, .eventListLarge]
        case .month: return [.monthSmall]
        case .todaySummary: return [.todaySummarySmall]
        case .foremost: return [.foremostInline, .foremostSmall, .foremostMedium]
        case .dday:
            return [.ddaySmall, .ddayMedium, .ddayCircular, .ddayRectangular, .ddayInline]
        case .weekEvents:
            return [
                .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
                .currentMonthEvents, .lastMonthEvents, .nextMonthEvents
            ]
        case .aiCommand: return [.aiCommandCircular, .aiCommandSmall]
        case .nextEvent: return [.nextEventInline, .nextEventRectangular]
        case .nextRemain: return [.nextRemainRectangular]
        case .doubleMonth: return [.doubleMonthMedium]
        case .eventAndMonth: return [.eventAndMonthMedium]
        case .eventAndForemost: return [.eventAndForemostMedium]
        case .todayAndMonth: return [.todayAndMonthMedium]
        }
    }
}
