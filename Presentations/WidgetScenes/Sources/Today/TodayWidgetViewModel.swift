//
//  TodayWidgetViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


// MARK: - TodayEventCountLines

/// 하단 개수 영역이 총합·항목별 두 줄 중 몇 줄을 채우는지 — 비는 줄만큼 날짜·월이 커진다.
public enum TodayEventCountLines: Sendable {
    case both
    case one
    case empty
}


// MARK: - TodayWidgetViewModel

public struct TodayWidgetViewModel {
    
    private enum Constant {
        static let sampleTimeZoneText: String = "GMT+9"
    }
    
    public let id: CalendarDay
    public let weekDayText: String
    public let day: Int
    public var holidayName: String?
    public var isHoliday: Bool { self.holidayName != nil }
    public let monthAndYearText: String
    public var timeZoneText: String?
    public var todoEventCount: Int = 0
    public var scheduleEventcount: Int = 0
    public var totalEventCount: Int { self.todoEventCount + self.scheduleEventcount }
    public var look = WidgetLook(globalSetting: .init())
    public var style: TodayStyleSetting { self.look.setting() }
    
    public var displayHolidayName: String? {
        return self.style.showHolidayName ? self.holidayName : nil
    }
    public var displayTimeZoneText: String? {
        return self.style.showTimeZone ? self.timeZoneText : nil
    }
    public var showsMonthAndYear: Bool { self.style.showMonthYear }
    public var showsTotalCount: Bool { self.style.showTotalCount }
    public var showsTodoCount: Bool { self.style.showTodoCount }
    public var showsScheduleCount: Bool { self.style.showScheduleCount }
    
    public var eventCountLines: TodayEventCountLines {
        let showsEachCount = (self.showsTodoCount && self.todoEventCount > 0)
            || (self.showsScheduleCount && self.scheduleEventcount > 0)
        switch (self.showsTotalCount, showsEachCount) {
        case (true, true): return .both
        case (true, false), (false, true): return .one
        case (false, false): return .empty
        }
    }
    
    public init(
        id: CalendarDay,
        weekDayText: String,
        day: Int,
        monthAndYearText: String
    ) {
        self.id = id
        self.weekDayText = weekDayText
        self.day = day
        self.monthAndYearText = monthAndYearText
    }
    
    public init(_ today: Date, _ calendar: Calendar) {
        self.id = .init(
            calendar.component(.year, from: today),
            calendar.component(.month, from: today),
            calendar.component(.day, from: today)
        )
        let timeZone = calendar.timeZone
        self.weekDayText = today.text("date_form.EEEE".localized(), timeZone: timeZone).uppercased()
        self.day = calendar.component(.day, from: today)
        self.monthAndYearText = today.text("date_form.MMM_yyyy".localized(), timeZone: timeZone).uppercased()
        if timeZone != TimeZone.current {
            self.timeZoneText = timeZone.localizedName(for: .shortStandard, locale: .current)
        }
    }
    
    public static func sample() -> TodayWidgetViewModel {
        return .init(
            id: .init(2024, 03, 14),
            weekDayText: "widget.events.today::sample::sunday".localized(),
            day: 14,
            monthAndYearText: "widget.events.today::sample::march2024".localized()
        )
        |> \.holidayName .~ "widget.events.today::sample::holiday".localized()
        |> \.timeZoneText .~ Constant.sampleTimeZoneText
        |> \.todoEventCount .~ 3
        |> \.scheduleEventcount .~ 4
    }
}

