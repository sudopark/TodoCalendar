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
    public var widgetSetting = WidgetAppearanceSettings()
    public var style = TodayStyleSetting()
    
    public var displayHolidayName: String? {
        return self.style.showHolidayName.isDisplayed ? self.holidayName : nil
    }
    public var displayTimeZoneText: String? {
        return self.style.showTimeZone.isDisplayed ? self.timeZoneText : nil
    }
    public var showsTotalCount: Bool { self.style.showTotalCount.isDisplayed }
    public var showsTodoCount: Bool { self.style.showTodoCount.isDisplayed }
    public var showsScheduleCount: Bool { self.style.showScheduleCount.isDisplayed }
    
    public var showsAnyEventCount: Bool {
        return self.showsTotalCount
            || (self.showsTodoCount && self.todoEventCount > 0)
            || (self.showsScheduleCount && self.scheduleEventcount > 0)
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


// MARK: - 스타일 항목 기본값

private extension Optional where Wrapped == Bool {
    
    /// 스타일 항목은 미설정(nil)이면 표시가 기본이다.
    var isDisplayed: Bool { self != false }
}
