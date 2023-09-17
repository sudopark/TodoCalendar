//
//  EventCellViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/09/17.
//

import Foundation
import Domain
import Prelude
import Optics

// MARK: - EventPeriodText

enum EventPeriodText: Equatable {
    case anyTime
    case allDay
    case atTime(_ timeText: String)
    case inToday(_ startTime: String, _ endTime: String)
    case fromTodayToFuture(_ startTime: String, _ endDay: String)
    case fromPastToToday(_ startDay: String, _ endTime: String)
    
    init?(
        _ eventTime: EventTime,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone
    ) {
        let eventTimeRange = eventTime.rangeWithShifttingifNeed(on: timeZone)
        let startTimeInToday = todayRange ~= eventTimeRange.lowerBound
        let endTimeInToday = todayRange ~= eventTimeRange.upperBound
        let isAllDay = eventTimeRange.lowerBound <= todayRange.lowerBound && todayRange.upperBound <= eventTimeRange.upperBound
        switch (eventTime, startTimeInToday, endTimeInToday, isAllDay) {
        case (_, _, _, true):
            self = .allDay
        case (.at(let time), true, true, _):
            self = .atTime(time.timeText(timeZone))
        case (_, true, true, _):
            self = .inToday(
                eventTime.lowerBoundWithFixed.timeText(timeZone),
                eventTime.upperBoundWithFixed.timeText(timeZone)
            )
        case (_, true, false, _):
            self = .fromTodayToFuture(
                eventTime.lowerBoundWithFixed.timeText(timeZone),
                eventTime.upperBoundWithFixed.dayText(timeZone)
            )
        case (_, false, true, _):
            self = .fromPastToToday(
                eventTime.lowerBoundWithFixed.dayText(timeZone),
                eventTime.upperBoundWithFixed.timeText(timeZone)
            )
        default:
            return nil
        }
    }
    
    fileprivate var customCompareKey: String {
        switch self {
        case .anyTime: return "anyTime"
        case .allDay: return "allDay"
        case .atTime(let time): return "atTime-\(time)"
        case .inToday(let start, let end): return "inToday-\(start)~\(end)"
        case .fromTodayToFuture(let start, let end): return "fromTodayToFuture\(start)~\(end)"
        case .fromPastToToday(let start, let end): return "fromPastToToday-\(start)~\(end)"
        }
    }
}

// MARK: - EventCellViewModel
protocol EventCellViewModel: Sendable {
    
    var eventIdentifier: String { get }
    var tagId: String? { get }
    var name: String { get }
    var periodText: EventPeriodText? { get set }
    var periodDescription: String? { get set }
    var colorHex: String? { get set }
    var customCompareKey: String { get }
}

extension EventCellViewModel {
    
    fileprivate func makeCustomCompareKey(_ additionalComponents: [String?]) -> String {
        let baseComponents: [String?] = [
            self.eventIdentifier, self.tagId, self.name,
            self.periodText?.customCompareKey, self.periodDescription,
            self.colorHex
        ]
        return baseComponents.map { $0 ?? "nil" }.joined(separator: ",")
    }
}

// MARK: - Todo

struct TodoEventCellViewModelImple: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: String?
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var colorHex: String?
    var customCompareKey: String { self.makeCustomCompareKey(["todo"]) }
    
    init(_ id: String, name: String) {
        self.eventIdentifier = id
        self.name = name
    }
    
    init?(_ todo: TodoEvent, in todayRange: Range<TimeInterval>, _ timeZone: TimeZone) {
        self.eventIdentifier = todo.uuid
        self.tagId = todo.eventTagId
        self.name = todo.name
        
        guard let time = todo.time else {
            self.periodText = .anyTime
            return
        }
        guard let periodText = EventPeriodText(time, in: todayRange, timeZone: timeZone)
        else { return nil }
        self.periodText = periodText
        self.periodDescription = time.durationText(timeZone)
    }
}

struct PendingTodoEventCellViewModelImple: EventCellViewModel {
    
    let pendingId: String = UUID().uuidString
    
    let eventIdentifier: String
    var tagId: String?
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var colorHex: String?
    var customCompareKey: String {
        self.makeCustomCompareKey(["pending-todo", self.pendingId])
    }
    
    // TOOD: make custom compare key
}

// MARK: - Schedule

struct ScheduleEventCellViewModelImple: EventCellViewModel {
    
    let eventIdentifier: String
    let turn: Int?
    var tagId: String?
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var colorHex: String?
    var customCompareKey: String {
        self.makeCustomCompareKey(["schedule", self.turn.map { "\($0)" }])
    }
    
    init(_ id: String, turn: Int? = nil, name: String) {
        self.eventIdentifier = id
        self.turn = turn
        self.name = name
    }
    
    init?(_ schedule: ScheduleEvent, turn: Int?, in todayRange: Range<TimeInterval>, timeZone: TimeZone) {
        guard let time = schedule.repeatingTimes.first(where: { $0.turn == turn }),
              let periodText = EventPeriodText(time.time, in: todayRange, timeZone: timeZone)
        else { return nil }
        self.eventIdentifier = schedule.uuid
        self.turn = turn
        self.tagId = schedule.eventTagId
        self.name = schedule.name
        self.periodText = periodText
        self.periodDescription = time.time.durationText(timeZone)
    }
}


// MARK: - Holiday
struct HolidayEventCellViewModelImple: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: String?
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var colorHex: String?
    var customCompareKey: String { self.makeCustomCompareKey(["holidays"]) }
    
    init(_ holiday: Holiday) {
        self.eventIdentifier = [holiday.dateString, holiday.name].joined(separator: "_")
        // TODO: set holiday tag
        self.name = holiday.localName
        self.periodText = .allDay
    }
}


// MARK: - extensions

private extension TimeInterval {
    
    func timeText(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "H:mm".localized()
        return formatter.string(from: Date(timeIntervalSince1970: self))
    }
    
    func dayText(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "d (E)".localized()
        return formatter.string(from: Date(timeIntervalSince1970: self))
    }
}

private extension EventTime {
    
    func durationText(_ timeZone: TimeZone) -> String? {
        
        switch self {
        case .period(let range):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = "MMM d HH:mm"
            return "\(range.rangeText(formatter))(\(range.totalPeriodText()))"
            
        case .allDay(let range, let secondsFrom):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = "MMM d"
            let shifttingRange = range.shiftting(secondsFrom, to: timeZone)
            let days = Int(shifttingRange.upperBound-shifttingRange.lowerBound) / (24 * 3600)
            let totalPeriodText = days > 0 ? "%ddays".localized(with: days+1) : nil
            let rangeText = shifttingRange.rangeText(formatter)
            return totalPeriodText.map { "\(rangeText)(\($0))"}
            
        default: return nil
        }
    }
}

private extension Range where Bound == TimeInterval {
    
    func rangeText(_ formatter: DateFormatter) -> String {
        let start = formatter.string(from: Date(timeIntervalSince1970: self.lowerBound))
        let end = formatter.string(from: Date(timeIntervalSince1970: self.upperBound))
        return "\(start) ~ \(end)"
    }
    
    func totalPeriodText() -> String {
        let length = Int(self.upperBound - self.lowerBound)
        let days = length / (24 * 3600)
        let hours = length % (24 * 3600) / 3600
        let minutes = length % 3600 / 60
        
        switch (days, hours, minutes) {
        case let (d, h, m) where d == 0 && h == 0:
            return "%dminutes".localized(with: m)
        case let (d, h, _) where d == 0:
            return "%dhours".localized(with: h)
        case let (d, h, _):
            return "%ddays %dhours".localized(with: d, h)
        }
    }
}

