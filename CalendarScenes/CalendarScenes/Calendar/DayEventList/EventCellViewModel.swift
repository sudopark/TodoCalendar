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
    
    case singleText(_ text: String)
    case doubleText(_ topText: String, _ bottomText: String)
    
    init?(_ todo: TodoEvent, in todayRange: Range<TimeInterval>, timeZone: TimeZone) {
        guard let time = todo.time
        else {
            self = .singleText("Todo".localized())
            return
        }
        
        let (isAllTodayTimeContains, _, endTimeInToday) = todayRange.checkTodayRangeBound(time, timeZone: timeZone)
        
        switch (time, endTimeInToday, isAllTodayTimeContains) {
        case (_, _, true):
            self = .doubleText("Todo".localized(), "Allday".localized())
            
        case (.at(let t), true, _):
            self = .doubleText("Todo".localized(), t.timeText(timeZone))
            
        case (_, true, _):
            self = .doubleText(
                "Todo".localized(),
                time.upperBoundWithFixed.timeText(timeZone)
            )
            
        case (_, false, _):
            self = .doubleText(
                "Todo".localized(),
                time.upperBoundWithFixed.dayText(timeZone)
            )
        }
    }
    
    init?(
        schedule eventTime: EventTime,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone
    ) {
        let (isAllDay, startTimeInToday, endTimeInToday) = todayRange.checkTodayRangeBound(eventTime, timeZone: timeZone)
        switch (eventTime, startTimeInToday, endTimeInToday, isAllDay) {
        case (_, _, _, true):
            self = .singleText("Allday".localized())
            
        case (.at(let time), true, true, _):
            self = .singleText(time.timeText(timeZone))
            
        case (_, true, true, _):
            self = .doubleText(
                eventTime.lowerBoundWithFixed.timeText(timeZone),
                eventTime.upperBoundWithFixed.timeText(timeZone)
            )
            
        case (_, true, false, _):
            self = .doubleText(
                eventTime.lowerBoundWithFixed.timeText(timeZone),
                eventTime.upperBoundWithFixed.dayText(timeZone)
            )
            
        case (_, false, true, _):
            self = .doubleText(
                eventTime.lowerBoundWithFixed.dayText(timeZone),
                eventTime.upperBoundWithFixed.timeText(timeZone)
            )
            
        default:
            return nil
        }
    }
    
    fileprivate var customCompareKey: String {
        switch self {
        case .singleText(let text): return "single-\(text)"
        case .doubleText(let top, let bottom): return "double-\(top)+\(bottom)"
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

struct TodoEventCellViewModel: EventCellViewModel {
    
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
        self.periodText = EventPeriodText(todo, in: todayRange, timeZone: timeZone)
        self.periodDescription = todo.time?.durationText(timeZone)
    }
}

struct PendingTodoEventCellViewModel: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: String?
    let name: String
    var periodText: EventPeriodText? = .singleText("Todo".localized())
    var periodDescription: String?
    var colorHex: String?
    var customCompareKey: String {
        self.makeCustomCompareKey(["pending-todo"])
    }
    
    init(name: String, defaultTagId: String?) {
        self.eventIdentifier = "pending:\(UUID().uuidString)"
        self.name = name
        self.tagId = defaultTagId
    }
    
    // TOOD: make custom compare key
}

// MARK: - Schedule

struct ScheduleEventCellViewModel: EventCellViewModel {
    
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
              let periodText = EventPeriodText(schedule: time.time, in: todayRange, timeZone: timeZone)
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
struct HolidayEventCellViewModel: EventCellViewModel {
    
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
        self.periodText = .singleText("Allday".localized())
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


private extension Range where Bound == TimeInterval {
    
    func checkTodayRangeBound(_ time: EventTime, timeZone: TimeZone) -> (
        isAllTodayTimeContains: Bool,
        starttimeInToday: Bool,
        endTimeInToday: Bool
    ) {
        let eventTimeRange = time.rangeWithShifttingifNeed(on: timeZone)
        let startTimeInToday = self ~= eventTimeRange.lowerBound
        let endTimeInToday = self ~= eventTimeRange.upperBound
        let isAllDay = eventTimeRange.lowerBound <= self.lowerBound
            && self.upperBound <= eventTimeRange.upperBound
        
        return (isAllDay, startTimeInToday, endTimeInToday)
    }
}
