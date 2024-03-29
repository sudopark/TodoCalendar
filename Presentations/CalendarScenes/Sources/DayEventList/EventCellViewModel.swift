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

struct EventTimeText: Equatable {
    let text: String
    var pmOram: String?
    
    init(text: String, pmOram: String? = nil) {
        self.text = text
        self.pmOram = pmOram
    }
    
    init(day: TimeInterval, _ timeZone: TimeZone) {
        self.text = day.dayText(timeZone)
    }
    
    init(time: TimeInterval, _ timeZone: TimeZone, _ isShort: Bool) {
        self.text = time.timeText(timeZone, isShort: isShort)
        self.pmOram = isShort ? time.isAmOrPmText(timeZone) : nil
    }
}

enum EventPeriodText: Equatable {
    
    case singleText(_ text: EventTimeText)
    case doubleText(_ topText: EventTimeText, _ bottomText: EventTimeText)
    
    init?(
        _ todo: TodoCalendarEvent,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone,
        is24hourForm: Bool
    ) {
        guard let time = todo.eventTime
        else {
            self = .singleText(
                .init(text: "Todo".localized())
            )
            return
        }
        
        let (isAllTodayTimeContains, _, endTimeInToday) = todayRange.checkTodayRangeBound(time, timeZone: timeZone)
        
        switch (time, endTimeInToday, isAllTodayTimeContains) {
        case (_, _, true):
            self = .doubleText(
                .init(text: "Todo".localized()),
                .init(text: "Allday".localized())
            )
            
        case (.at(let t), true, _):
            self = .doubleText(
                .init(text: "Todo".localized()),
                .init(time: t, timeZone, !is24hourForm)
            )
            
        case (_, true, _):
            self = .doubleText(
                .init(text: "Todo".localized()),
                .init(time: time.upperBoundWithFixed, timeZone, !is24hourForm)
            )
            
        case (_, false, _):
            self = .doubleText(
                .init(text: "Todo".localized()),
                .init(day: time.upperBoundWithFixed, timeZone)
            )
        }
    }
    
    init?(
        schedule eventTime: EventTime,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone,
        is24hourForm: Bool
    ) {
        let (isAllDay, startTimeInToday, endTimeInToday) = todayRange.checkTodayRangeBound(eventTime, timeZone: timeZone)
        switch (eventTime, startTimeInToday, endTimeInToday, isAllDay) {
        case (_, _, _, true):
            self = .singleText(
                .init(text: "Allday".localized())
            )
            
        case (.at(let time), true, true, _):
            self = .singleText(
                .init(time: time, timeZone, !is24hourForm)
            )
            
        case (_, true, true, _):
            self = .doubleText(
                .init(time: eventTime.lowerBoundWithFixed, timeZone, !is24hourForm),
                .init(time: eventTime.upperBoundWithFixed, timeZone, !is24hourForm)
            )
            
        case (_, true, false, _):
            self = .doubleText(
                .init(time: eventTime.lowerBoundWithFixed, timeZone, !is24hourForm),
                .init(day: eventTime.upperBoundWithFixed, timeZone)
            )
            
        case (_, false, true, _):
            self = .doubleText(
                .init(day: eventTime.lowerBoundWithFixed, timeZone),
                .init(time: eventTime.upperBoundWithFixed, timeZone, !is24hourForm)
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
    var tagId: AllEventTagId { get }
    var name: String { get }
    var periodText: EventPeriodText? { get set }
    var periodDescription: String? { get set }
    var tagColor: EventTagColor? { get set }
    var customCompareKey: String { get }
    
    mutating func applyTagColor(_ tag: EventTag?)
}

extension EventCellViewModel {
    
    fileprivate func makeCustomCompareKey(_ additionalComponents: [String?]) -> String {
        let baseComponents: [String?] = [
            self.eventIdentifier, "\(self.tagId.hashValue)", self.name,
            self.periodText?.customCompareKey, self.periodDescription,
            self.tagColor?.compareKey
        ]
        return baseComponents.map { $0 ?? "nil" }.joined(separator: ",")
    }
    
    mutating func applyTagColor(_ tag: EventTag?) {
        switch self.tagId {
        case .default:
            self.tagColor = .default
        case .custom:
            self.tagColor = tag.map { EventTagColor.custom(hex: $0.colorHex) } ?? .default
        case .holiday:
            self.tagColor = .holiday
        }
    }
}

// MARK: - Todo

struct TodoEventCellViewModel: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: AllEventTagId
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var tagColor: EventTagColor?
    var customCompareKey: String { self.makeCustomCompareKey(["todo"]) }
    
    init(_ id: String, name: String) {
        self.eventIdentifier = id
        self.name = name
        self.tagId = .default
    }
    
    init?(
        _ todo: TodoCalendarEvent,
        in todayRange: Range<TimeInterval>,
        _ timeZone: TimeZone,
        _ is24hourForm: Bool
    ) {
        self.eventIdentifier = todo.eventId
        self.tagId = todo.eventTagId
        self.name = todo.name
        self.periodText = EventPeriodText(todo, in: todayRange, timeZone: timeZone, is24hourForm: is24hourForm)
        self.periodDescription = todo.eventTime?.durationText(timeZone)
    }
}

struct PendingTodoEventCellViewModel: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: AllEventTagId
    let name: String
    var periodText: EventPeriodText? = .singleText(
        .init(text: "Todo".localized())
    )
    var periodDescription: String?
    var tagColor: EventTagColor?
    var customCompareKey: String {
        self.makeCustomCompareKey(["pending-todo"])
    }
    
    init(name: String, defaultTagId: String?) {
        self.eventIdentifier = "pending:\(UUID().uuidString)"
        self.name = name
        self.tagId = defaultTagId.map { .custom($0) } ?? .default
    }
    
    // TOOD: make custom compare key
}

// MARK: - Schedule

struct ScheduleEventCellViewModel: EventCellViewModel {
    
    let eventIdWithoutTurn: String
    let eventIdentifier: String
    let turn: Int?
    var tagId: AllEventTagId
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var tagColor: EventTagColor?
    var customCompareKey: String {
        self.makeCustomCompareKey(["schedule", self.turn.map { "\($0)" }])
    }
    
    init(_ id: String, turn: Int? = nil, name: String) {
        self.eventIdWithoutTurn = id
        self.eventIdentifier = "\(id)_\(turn ?? 0)"
        self.turn = turn
        self.name = name
        self.tagId = .default
    }
    
    init?(
        _ schedule: ScheduleCalendarEvent,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone,
        _ is24hourForm: Bool
    ) {
        guard let time = schedule.eventTime,
            let periodText = EventPeriodText(schedule: time, in: todayRange, timeZone: timeZone, is24hourForm: is24hourForm)
        else { return nil }
        self.eventIdentifier = schedule.eventId
        self.eventIdWithoutTurn = schedule.eventIdWithoutTurn
        self.turn = schedule.turn
        self.tagId = schedule.eventTagId
        self.name = schedule.name
        self.periodText = periodText
        self.periodDescription = schedule.eventTime?.durationText(timeZone)
    }
}


// MARK: - Holiday
struct HolidayEventCellViewModel: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: AllEventTagId
    let name: String
    var periodText: EventPeriodText?
    var periodDescription: String?
    var tagColor: EventTagColor?
    var customCompareKey: String { self.makeCustomCompareKey(["holidays"]) }
    
    init(_ holiday: HolidayCalendarEvent) {
        self.eventIdentifier = holiday.eventId
        self.name = holiday.name
        self.periodText = .singleText(
            .init(text: "Allday".localized())
        )
        self.tagId = .holiday
        self.tagColor = .holiday
    }
    
    mutating func applyTagColor(_ tag: EventTag?) {
        self.tagColor = .holiday
    }
}


// MARK: - extensions

private extension TimeInterval {
    
    func isAmOrPmText(_ timeZone: TimeZone) -> String {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let date = Date(timeIntervalSince1970: self)
        let isAm = calendar.component(.hour, from: date) < 12
        return isAm ? "AM" : "PM"
    }

    func timeText(_ timeZone: TimeZone, isShort: Bool) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = isShort ? "h:mm".localized() : "H:mm".localized()
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

private extension EventTagColor {
    
    var compareKey: String {
        switch self {
        case .default: return "default"
        case .holiday: return "holiday"
        case .custom(let hex): return "custom:\(hex)"
        }
    }
}
