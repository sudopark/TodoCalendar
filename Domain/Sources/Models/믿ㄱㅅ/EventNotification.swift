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
    
    init(
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
    
    public var title: String { "Today events".localized() }
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
    
    public let eventType: SingleNotificationEventSourceType
    public let eventId: String
    public let eventName: String
    public let eventTimeText: String
    public let scheduleDateComponents: DateComponents
    
    public init?(
        todo: TodoEvent,
        in timeZone: TimeZone,
        timeOption: EventNotificationTimeOption
    ) {
        
        self.eventType = .todo
        self.eventId = todo.uuid
        self.eventName = "(\("Todo".localized()))\(todo.name)"
        
        guard let time = todo.time,
              let (timeText, component) = time.futureNotificationTime(in: timeZone, timeOption: timeOption)
        else { return nil }
        
        self.eventTimeText = timeText
        self.scheduleDateComponents = component
    }
    
    public init?(
        schedule: ScheduleEvent,
        repeatingAt: EventTime?,
        in timeZone: TimeZone,
        with option: EventNotificationTimeOption
    ) {
        self.eventType = .schedule
        self.eventId = schedule.uuid
        self.eventName = schedule.name
        
        let eventTime = repeatingAt ?? schedule.time
        guard let (timeText, components) = eventTime.futureNotificationTime(in: timeZone, timeOption: option)
        else { return nil }
        
        self.eventTimeText = timeText
        self.scheduleDateComponents = components
    }
}

private extension EventTime {
    
    func futureNotificationTime(
        in timeZone: TimeZone,
        timeOption: EventNotificationTimeOption
    ) -> (String, DateComponents)? {
        
        let now = Date()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        
        func notAllDayNotificationTime(_ startTime: TimeInterval) -> (
            String, DateComponents
        )? {
            guard let notificationTime = startTime.applyNotAllDayNotificationTime(option: timeOption),
                  notificationTime > now.timeIntervalSince1970
            else { return nil }
            let components = calendar.notificationTimeDateComponent(notificationTime)
            
            let startDate = Date(timeIntervalSince1970: startTime)
            let dateFormatter = DateFormatter()
            
            if calendar.isDateInToday(startDate) {
                dateFormatter.dateFormat = "HH:mm".localized()
                let timeText = "\("Today".localized()) \(dateFormatter.string(from: startDate))"
                return (timeText, components)
            } else if calendar.isDateInTomorrow(startDate) {
                dateFormatter.dateFormat = "HH:mm".localized()
                let timeText =  "\("Tomorrow".localized()) \(dateFormatter.string(from: startDate))"
                return (timeText, components)
                
            } else {
                dateFormatter.dateFormat = "MM d, HH:mm".localized()
                let timeText = dateFormatter.string(from: startDate)
                return (timeText, components)
            }
        }
        
        func allDayNotificationTime(_ startTime: TimeInterval) -> (
            String, DateComponents
        )? {
            guard let notificationTime = startTime.applyAllDayNotificationTime(option: timeOption, calendar: calendar),
                  notificationTime > now.timeIntervalSince1970
            else { return nil }
            
            let components = calendar.notificationTimeDateComponent(notificationTime)
            
            let startDate = Date(timeIntervalSince1970: startTime)
            
            if calendar.isDateInToday(startDate) {
                let timeText = "All day today".localized()
                return (timeText, components)
            } else if calendar.isDateInTomorrow(startDate) {
                let timeText = "All day tomorrow".localized()
                return (timeText, components)
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM d".localized()
                let timetext = "\(dateFormatter.string(from: startDate)) all day".localized()
                return (timetext, components)
            }
        }

        switch self {
        case .at(let time):
            return notAllDayNotificationTime(time)
            
        case .period(let range):
            return notAllDayNotificationTime(range.lowerBound)
            
        case .allDay(let range, let secondsFromGMT):
            let shiftRange = range.shiftting(secondsFromGMT, to: timeZone)
            return allDayNotificationTime(shiftRange.lowerBound)
        }
    }
}

private extension TimeInterval {
    
    func applyNotAllDayNotificationTime(option: EventNotificationTimeOption) -> TimeInterval? {
        switch option {
        case .atTime: return self
        case .before(let seconds): return self - seconds
        default: return nil
        }
    }
    
    func applyAllDayNotificationTime(option: EventNotificationTimeOption, calendar: Calendar) -> TimeInterval? {
        let startDate = Date(timeIntervalSince1970: self)
        switch option {
        case .allDay9AM:
            return calendar.date(bySetting: .hour, value: 9, of: startDate)?.timeIntervalSince1970
            
        case .allDay12AM:
            return calendar.date(bySetting: .hour, value: 0, of: startDate)?.timeIntervalSince1970
            
        case .allDay9AMBefore(let seconds):
            return calendar.date(bySetting: .hour, value: 9, of: startDate)
                .map { $0.timeIntervalSince1970 - seconds }
            
        default: return nil
        }
    }
}

private extension Calendar {
    
    func notificationTimeDateComponent(_ time: TimeInterval) -> DateComponents {
        return self.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: Date(timeIntervalSince1970: time)
        )
        |> \.calendar .~ Calendar(identifier: .gregorian)
        |> \.timeZone .~ pure(self.timeZone)
    }
}
