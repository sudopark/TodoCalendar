//
//  MonthStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum MonthStyleItem: String, WidgetStyleItem {

    case showMonthName
    case showWeekDayHeader
    case highlightToday
    case showEventUnderline

    var settingKeyPath: WritableKeyPath<MonthStyleSetting, Bool> {
        switch self {
        case .showMonthName: return \.showMonthName
        case .showWeekDayHeader: return \.showWeekDayHeader
        case .highlightToday: return \.highlightToday
        case .showEventUnderline: return \.showEventUnderline
        }
    }

    var name: String {
        switch self {
        case .showMonthName: return "widget.style.month::showMonthName".localized()
        case .showWeekDayHeader: return "widget.style.month::showWeekDayHeader".localized()
        case .highlightToday: return "widget.style.month::highlightToday".localized()
        case .showEventUnderline:
            return "widget.style.month::showEventUnderline".localized()
        }
    }
}
