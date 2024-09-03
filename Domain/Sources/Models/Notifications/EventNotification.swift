//
//  EventNotification.swift
//  Domain
//
//  Created by sudo.park on 1/5/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


// MARK: - EventNotifications

public protocol EventNotification: Equatable, Sendable {
    
    var notificationId: String { get }
    var title: String { get }
    var message: String { get }
    var scheduleDateComponents: DateComponents { get }
}


public enum SingleNotificationEventSourceType: Sendable {
    case todo
    case schedule
}

public struct SingleEventNotification: EventNotification {
    
    public let notificationId: String
    public let eventType: SingleNotificationEventSourceType
    public let eventId: String
    public let eventName: String
    public let eventTImeText: String
    public let scheduleDateComponents: DateComponents
    
    public var title: String { self.eventName }
    public var message: String { self.eventTImeText }
    
    public init(
        notificationId: String,
        eventType: SingleNotificationEventSourceType,
        eventId: String,
        eventName: String,
        eventTImeText: String,
        scheduleDateComponents: DateComponents
    ) {
        self.notificationId = notificationId
        self.eventType = eventType
        self.eventId = eventId
        self.eventName = eventName
        self.eventTImeText = eventTImeText
        self.scheduleDateComponents = scheduleDateComponents
    }
}

public struct TodayEventsNotification: EventNotification {
    
    public let notificationId: String
    public let eventIds: [String]
    public let eventTimeAndNames: [String]
    public let scheduleDateComponents: DateComponents
    
    public var title: String { "event_notification::today:title".localized() }
    public var message: String { self.eventTimeAndNames.joined(separator: "\n") }
    
    init(
        notificationId: String,
        eventIds: [String],
        eventTimeAndNames: [String],
        scheduleDateComponents: DateComponents
    ) {
        self.notificationId = notificationId
        self.eventIds = eventIds
        self.eventTimeAndNames = eventTimeAndNames
        self.scheduleDateComponents = scheduleDateComponents
    }
}


// MARK: - EventNotification make params

public struct SingleEventNotificationMakeParams: Sendable, Equatable {
    
    public enum ScheduleTime: Equatable, Sendable {
        case at(TimeInterval)
        case components(DateComponents)
        
        func notificationFireDate(_ calendar: Calendar) -> Date? {
            switch self {
            case .at(let interval): return Date(timeIntervalSince1970: interval)
            case .components(let components):
                return calendar.date(from: components)
            }
        }
    }
    
    public let eventType: SingleNotificationEventSourceType
    public let eventId: String
    public let eventName: String
    public let eventTimeText: String
    public let scheduleTime: ScheduleTime
    
    public init?(
        todo: TodoEvent,
        timeOption: EventNotificationTimeOption
    ) {
        
        self.eventType = .todo
        self.eventId = todo.uuid
        self.eventName = "(\("event_notification::todo:prefix".localized()))\(todo.name)"
        
        guard let time = todo.time,
              let (timeText, scheduleTime) = time.notificationTimeInfo(timeOption: timeOption)
        else { return nil }
        
        self.eventTimeText = timeText
        self.scheduleTime = scheduleTime
    }
    
    public init?(
        schedule: ScheduleEvent,
        repeatingAt: EventTime?,
        with option: EventNotificationTimeOption
    ) {
        self.eventType = .schedule
        self.eventId = schedule.uuid
        self.eventName = schedule.name
        
        let eventTime = repeatingAt ?? schedule.time
        guard let (timeText, scheduleTime) = eventTime.notificationTimeInfo(timeOption: option)
        else { return nil }
        
        self.eventTimeText = timeText
        self.scheduleTime = scheduleTime
    }
}

private extension EventTime {
    
    func notificationTimeInfo(
        timeOption: EventNotificationTimeOption
    ) -> (String, SingleEventNotificationMakeParams.ScheduleTime)? {
        
        func notAllDayNotificationTime(_ startTime: TimeInterval) -> (
            String, SingleEventNotificationMakeParams.ScheduleTime
        )? {
            
            let calendar = Calendar(identifier: .gregorian)
            
            guard let notificationTime = startTime.notAllDayNotificationTime(option: timeOption),
                  let notificationFireDate = notificationTime.notificationFireDate(calendar)
            else { return nil }
            
            let dateFormatter = DateFormatter()
            let startDate = Date(timeIntervalSince1970: startTime)
            if calendar.isDateInToday(notificationFireDate) {
                dateFormatter.dateFormat = "date_form::HH:mm".localized()
                let timeText = "\("event_notification::today:prefix".localized()) \(dateFormatter.string(from: startDate))"
                return (timeText, notificationTime)
            } else if calendar.isDateInTomorrow(notificationFireDate) {
                dateFormatter.dateFormat = "date_form::HH:mm".localized()
                let timeText =  "\("event_notification::tomorrow:prefix".localized()) \(dateFormatter.string(from: startDate))"
                return (timeText, notificationTime)
                
            } else {
                dateFormatter.dateFormat = "date_form::MM_d__HH:mm".localized()
                let timeText = dateFormatter.string(from: startDate)
                return (timeText, notificationTime)
            }
        }
        
        func allDayNotificationTime(
            _ startTime: TimeInterval, _ secondsFromGMT: TimeInterval
        ) -> (
            String, SingleEventNotificationMakeParams.ScheduleTime
        )? {
            guard let timeZone = TimeZone(secondsFromGMT: Int(secondsFromGMT)) else { return nil }
            let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
            let systemCalendar = Calendar(identifier: .gregorian)
            guard let notificationTime = startTime.allDayNotificationTime(option: timeOption, calendar: calendar),
                  let notificationFireDate = notificationTime.notificationFireDate(systemCalendar)
            else { return nil }
 
            let startDate = Date(timeIntervalSince1970: startTime)
            
            if systemCalendar.isDateInToday(notificationFireDate) {
                let timeText = "event_notification::allday_today".localized()
                return (timeText, notificationTime)
            } else if systemCalendar.isDateInTomorrow(notificationFireDate) {
                let timeText = "event_notification::allday_tomorrow".localized()
                return (timeText, notificationTime)
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "date_form::MM_d".localized()
                let timetext = "event_notification::some_allday".localized(with: dateFormatter.string(from: startDate))
                return (timetext, notificationTime)
            }
        }

        switch self {
        case .at(let time):
            return notAllDayNotificationTime(time)
            
        case .period(let range):
            return notAllDayNotificationTime(range.lowerBound)
            
        case .allDay(let range, let secondsFromGMT):
            return allDayNotificationTime(range.lowerBound, secondsFromGMT)
        }
    }
}

private extension TimeInterval {
    
    func notAllDayNotificationTime(
        option: EventNotificationTimeOption
    ) -> SingleEventNotificationMakeParams.ScheduleTime? {
        
        switch option {
        case .atTime:  
            return .at(self)
        case .before(let seconds):
            return .at(self - seconds)
        case .custom(let compos):
            return .components(compos)
            
        default: return nil
        }
    }
    
    func allDayNotificationTime(
        option: EventNotificationTimeOption, 
        calendar: Calendar
    ) -> SingleEventNotificationMakeParams.ScheduleTime? {
        let startDate = Date(timeIntervalSince1970: self)
        let startDateComponents = calendar.dateComponents([
            .year, .month, .day, .hour, .minute, .second
        ], from: startDate)
        switch option {
        case .allDay9AM:
            return .components(
                startDateComponents 
                    |> \.hour .~ 9
                    |> \.minute .~ 0
                    |> \.second .~ 0
            )
            
        case .allDay12AM:
            return .components(
                startDateComponents
                    |> \.hour .~ 12
                    |> \.minute .~ 0
                    |> \.second .~ 0
            )
            
        case .allDay9AMBefore(let seconds):
            let beforeDate = startDate.addingTimeInterval(-seconds)
            let beforeDateComponents = calendar.dateComponents([
                .year, .month, .day, .hour, .minute, .second
            ], from: beforeDate)
            return .components(
                beforeDateComponents
                    |> \.hour .~ 9
                    |> \.minute .~ 0
                    |> \.second .~ 0
            )
            
        case .custom(let compos):
            return .components(compos)
            
        default: return nil
        }
    }
}
