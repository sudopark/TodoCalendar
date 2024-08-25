//
//  EventNotificationTimeOption+Extensions.swift
//  CommonPresentation
//
//  Created by sudo.park on 1/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions

extension Optional where Wrapped == EventNotificationTimeOption {
    
    public var text: String {
        switch self {
        case .none:
            return R.String.eventNotificationSettingOptionTitleNoNotification
        case .some(let value):
            return value.text
        }
    }
}

extension EventNotificationTimeOption {
    
    public var text: String {
        switch self {
        case .atTime:
            return R.String.eventNotificationSettingOptionTitleAtTime
        case .before(let seconds):
            return seconds.beforeText
        case .allDay9AM:
            return R.String.eventNotificationSettingOptionTitleAllday9am
        case .allDay12AM:
            return R.String.eventNotificationSettingOptionTitleAllday12pm
        case .allDay9AMBefore(let seconds):
            return seconds.alldayBeforeText
        case .custom(let componets):
            let calendar = Calendar(identifier: .gregorian)
            return calendar.customTimeText(componets).map {
                R.String.eventNotificationSettingOptionTitleCustomTime($0)
            }
            ?? R.String.eventNotificationSettingOptionTitleCustimTimeFallback
        }
    }
}

private extension TimeInterval {
    
    var beforeText: String {
        guard self >= 3600
        else {
            let mins = Int(self / 60)
            return R.String.eventNotificationSettingOptionTitleBeforeMinutes(mins)
        }
        
        guard self >= 3600 * 24
        else {
            let hours = Int(self / 3600)
            return R.String.eventNotificationSettingOptionTitleBeforeHours(hours)
        }
        
        guard self >= 3600*24*7 else {
            let days = Int(self / 3600 / 24)
            return R.String.eventNotificationSettingOptionTitleBeforeDays(days)
        }
        
        let weeks = Int(self / 3600 / 24 / 7)
        return R.String.eventNotificationSettingOptionTitleBeforeWeeks(weeks)
    }
    
    var alldayBeforeText: String {
        guard self >= 3600*24*7
        else {
            let days = Int(self / 3600 / 24)
            return R.String.eventNotificationSettingOptionTitleAllday9amBeforeDays(days)
        }
        
        let weeks = Int(self / 3600 / 24 / 7)
        return R.String.eventNotificationSettingOptionTitleAllday9amBeforeWeeks(weeks)
    }
}

extension Calendar {
    
    public func customTimeText(_ component: DateComponents) -> String? {
        guard let date = self.date(from: component) else { return nil }
        let form = DateFormatter() |> \.dateFormat .~ R.String.DateFormYyyy.mmDdHhMm
        return form.string(from: date)
    }
}
