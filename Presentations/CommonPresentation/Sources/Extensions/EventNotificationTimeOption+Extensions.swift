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

extension Optional where Wrapped == EventNotificationTimeOption {
    
    public var text: String {
        switch self {
        case .none: 
            return "event_notification_setting::option_title::no_notification".localized()
        case .some(let value):
            return value.text
        }
    }
}

extension EventNotificationTimeOption {
    
    public var text: String {
        switch self {
        case .atTime:
            return "event_notification_setting::option_title::at_time".localized()
        case .before(let seconds):
            return seconds.beforeText
        case .allDay9AM:
            return "event_notification_setting::option_title::allday_9am".localized()
        case .allDay12AM:
            return "event_notification_setting::option_title::allday_12am".localized()
        case .allDay9AMBefore(let seconds):
            return seconds.alldayBeforeText
        case .custom(let timeZone, let componets):
            let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
            return calendar.customTimeText(componets).map {
                "event_notification_setting::option_title::customTime".localized(with: $0)
            }
            ?? "event_notification_setting::option_title::custimTime_fallback".localized()
        }
    }
}

private extension TimeInterval {
    
    var beforeText: String {
        guard self >= 3600
        else {
            let mins = Int(self / 60)
            return "event_notification_setting::option_title::before_minutes".localized(with: mins)
        }
        
        guard self >= 3600 * 24
        else {
            let hours = Int(self / 3600)
            return "event_notification_setting::option_title::before_hours".localized(with: hours)
        }
        
        guard self >= 3600*24*7 else {
            let days = Int(self / 3600 / 24)
            return "event_notification_setting::option_title::before_days".localized(with: days)
        }
        
        let weeks = Int(self / 3600 / 24 / 7)
        return "event_notification_setting::option_title::before_weeks".localized(with: weeks)
    }
    
    var alldayBeforeText: String {
        guard self >= 3600*24*7
        else {
            let days = Int(self / 3600 / 24)
            return "event_notification_setting::option_title::allday_9am_before_days".localized(with: days)
        }
        
        let weeks = Int(self / 3600 / 24 / 7)
        return "event_notification_setting::option_title::allday_9am_before_weeks".localized(with: weeks)
    }
}

private extension Calendar {
    
    func customTimeText(_ component: DateComponents) -> String? {
        guard let date = self.date(from: component) else { return nil }
        let form = DateFormatter() |> \.dateFormat .~ "yyyy.MM.dd hh:mm"
        return form.string(from: date)
    }
}
