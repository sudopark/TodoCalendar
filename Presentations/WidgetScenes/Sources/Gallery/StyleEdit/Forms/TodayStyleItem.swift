//
//  TodayStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum TodayStyleItem: String, WidgetStyleItem {

    case showHolidayName
    case showTimeZone
    case showMonthYear
    case showTotalCount
    case showTodoCount
    case showScheduleCount

    var settingKeyPath: WritableKeyPath<TodayStyleSetting, Bool> {
        switch self {
        case .showHolidayName: return \.showHolidayName
        case .showTimeZone: return \.showTimeZone
        case .showMonthYear: return \.showMonthYear
        case .showTotalCount: return \.showTotalCount
        case .showTodoCount: return \.showTodoCount
        case .showScheduleCount: return \.showScheduleCount
        }
    }

    var note: String? {
        switch self {
        case .showHolidayName: return "widget.style.today::showHolidayName::note".localized()
        case .showTimeZone: return "widget.style.today::showTimeZone::note".localized()
        case .showMonthYear, .showTotalCount, .showTodoCount, .showScheduleCount: return nil
        }
    }

    var name: String {
        switch self {
        case .showHolidayName: return "widget.style.today::showHolidayName".localized()
        case .showTimeZone: return "widget.style.today::showTimeZone".localized()
        case .showMonthYear: return "widget.style.today::showMonthYear".localized()
        case .showTotalCount: return "widget.style.today::showTotalCount".localized()
        case .showTodoCount: return "widget.style.today::showTodoCount".localized()
        case .showScheduleCount: return "widget.style.today::showScheduleCount".localized()
        }
    }
}
