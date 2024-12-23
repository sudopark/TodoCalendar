//
//  EventCellViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/09/17.
//

import Foundation
import Domain
import Extensions
import Prelude
import Optics

// MARK: - EventPeriodText

public struct EventTimeText: Equatable, Sendable {
    public let text: String
    public var pmOram: String?
    
    public init(text: String, pmOram: String? = nil) {
        self.text = text
        self.pmOram = pmOram
    }
    
    public init(day: TimeInterval, _ timeZone: TimeZone) {
        self.text = day.dayText(timeZone)
    }
    
    public init(time: TimeInterval, _ timeZone: TimeZone, _ isShort: Bool) {
        self.text = time.timeText(timeZone, isShort: isShort)
        self.pmOram = isShort ? time.isAmOrPmText(timeZone) : nil
    }
}

public enum EventPeriodText: Equatable, Sendable {
    
    case singleText(_ text: EventTimeText)
    case doubleText(_ topText: EventTimeText, _ bottomText: EventTimeText)
    
    public init(
        _ todo: TodoCalendarEvent,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone,
        is24hourForm: Bool
    ) {
        guard let time = todo.eventTime
        else {
            self = .singleText(
                .init(text: R.String.calendarEventTimeTodo)
            )
            return
        }
        
        let (isAllTodayTimeContains, _, endTimeInToday) = todayRange.checkTodayRangeBound(time, timeZone: timeZone)
        
        switch (time, endTimeInToday, isAllTodayTimeContains) {
        case (_, _, true):
            self = .doubleText(
                .init(text: R.String.calendarEventTimeTodo),
                .init(text: R.String.calendarEventTimeAllday)
            )
            
        case (.at(let t), true, _):
            self = .doubleText(
                .init(text: R.String.calendarEventTimeTodo),
                .init(time: t, timeZone, !is24hourForm)
            )
            
        case (_, true, _):
            self = .doubleText(
                .init(text: R.String.calendarEventTimeTodo),
                .init(time: time.upperBoundWithFixed, timeZone, !is24hourForm)
            )
            
        case (_, false, _):
            self = .doubleText(
                .init(text: R.String.calendarEventTimeTodo),
                .init(day: time.upperBoundWithFixed, timeZone)
            )
        }
    }
    
    public init(
        schedule eventTime: EventTime,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone,
        is24hourForm: Bool
    ) {
        let (isAllDay, startTimeInToday, endTimeInToday) = todayRange.checkTodayRangeBound(eventTime, timeZone: timeZone)
        switch (eventTime, startTimeInToday, endTimeInToday, isAllDay) {
        case (_, _, _, true):
            self = .singleText(
                .init(text: R.String.calendarEventTimeAllday)
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
        case (_, false, false, _):
            self = .singleText(
                .init(day: eventTime.lowerBoundWithFixed, timeZone)
            )
        }
    }
    
    fileprivate var customCompareKey: String {
        switch self {
        case .singleText(let text): return "single-\(text)"
        case .doubleText(let top, let bottom): return "double-\(top)+\(bottom)"
        }
    }
}

// MARK: - EventEditAction

public enum EventListMoreAction: Sendable, Equatable {
    
    case remove(onlyThisTime: Bool)
    case toggleTo(isForemost: Bool)
    case skipTodo
    case edit
    case copy
}

public struct EventListMoreActionModel: Sendable, Equatable {
    let basicActions: [EventListMoreAction]
    let removeActions: [EventListMoreAction]
}

// MARK: - EventCellViewModel
public protocol EventCellViewModel: Sendable {
    
    var eventIdentifier: String { get }
    var tagId: AllEventTagId { get }
    var name: String { get }
    var periodText: EventPeriodText? { get set }
    var periodDescription: String? { get set }
    var tagColor: EventTagColor? { get set }
    var isForemost: Bool { get }
    var isRepeating: Bool { get }
    var customCompareKey: String { get }
    var moreActions: EventListMoreActionModel? { get }
    
    mutating func applyTagColor(_ tag: EventTag?)
}

extension EventCellViewModel {
    
    fileprivate func makeCustomCompareKey(_ additionalComponents: [String?]) -> String {
        let baseComponents: [String?] = [
            self.eventIdentifier, "\(self.tagId.hashValue)", self.name,
            self.periodText?.customCompareKey, self.periodDescription,
            self.tagColor?.compareKey,
            "\(self.isForemost)"
        ]
        let components = baseComponents + additionalComponents
        return components.map { $0 ?? "nil" }.joined(separator: ",")
    }
    
    public mutating func applyTagColor(_ tag: EventTag?) {
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

public struct TodoEventCellViewModel: EventCellViewModel {
    
    public let eventIdentifier: String
    public var tagId: AllEventTagId
    public let name: String
    public var periodText: EventPeriodText?
    public var periodDescription: String?
    public var tagColor: EventTagColor?
    public var customCompareKey: String { self.makeCustomCompareKey(["todo"]) }
    public var eventTimeRawValue: EventTime?
    public var isRepeating: Bool = false
    public var isForemost: Bool = false
    
    public init(_ id: String, name: String) {
        self.eventIdentifier = id
        self.name = name
        self.tagId = .default
    }
    
    public init?(
        _ todo: TodoCalendarEvent,
        in todayRange: Range<TimeInterval>,
        _ timeZone: TimeZone,
        _ is24hourForm: Bool,
        forceShowEventDateDurationText: Bool = false
    ) {
        self.eventIdentifier = todo.eventId
        self.tagId = todo.eventTagId
        self.name = todo.name
        self.periodText = EventPeriodText(todo, in: todayRange, timeZone: timeZone, is24hourForm: is24hourForm)
        self.periodDescription = todo.eventTime?.durationText(
            timeZone, forceShowEventDateDurationText: forceShowEventDateDurationText
        )
        self.eventTimeRawValue = todo.eventTime
        
        self.isRepeating = todo.isRepeating
        self.isForemost = todo.isForemost
    }
    
    public var moreActions: EventListMoreActionModel? {
        let removeActions: [EventListMoreAction] = self.isRepeating
            ? [.remove(onlyThisTime: true), .remove(onlyThisTime: false)]
            : [.remove(onlyThisTime: false)]
        let skipActions: [EventListMoreAction] = self.isRepeating
            ? [.skipTodo] : []
        let basicActions: [EventListMoreAction] = [.toggleTo(isForemost: self.isForemost)] + skipActions + [.edit, .copy]
        return .init(
            basicActions: basicActions,
            removeActions: removeActions
        )
    }
}

struct PendingTodoEventCellViewModel: EventCellViewModel {
    
    let eventIdentifier: String
    var tagId: AllEventTagId
    let name: String
    var periodText: EventPeriodText? = .singleText(
        .init(text: R.String.calendarEventTimeTodo)
    )
    var periodDescription: String?
    var tagColor: EventTagColor?
    var customCompareKey: String {
        self.makeCustomCompareKey(["pending-todo"])
    }
    let isRepeating: Bool = false
    let isForemost: Bool = false
    
    init(name: String, defaultTagId: String?) {
        self.eventIdentifier = "pending:\(UUID().uuidString)"
        self.name = name
        self.tagId = defaultTagId.map { .custom($0) } ?? .default
    }
    
    // TOOD: make custom compare key
    var moreActions: EventListMoreActionModel? { nil }
}

// MARK: - Schedule

public struct ScheduleEventCellViewModel: EventCellViewModel {
    
    public let eventIdWithoutTurn: String
    public let eventIdentifier: String
    public let turn: Int?
    public var tagId: AllEventTagId
    public let name: String
    public var periodText: EventPeriodText?
    public var periodDescription: String?
    public var tagColor: EventTagColor?
    public let isRepeating: Bool
    public let isForemost: Bool
    public var customCompareKey: String {
        self.makeCustomCompareKey(["schedule", self.turn.map { "\($0)" }])
    }
    var eventTimeRawValue: EventTime?
    
    public init(_ id: String, turn: Int? = nil, name: String, isRepeating: Bool = false) {
        self.eventIdWithoutTurn = id
        self.eventIdentifier = "\(id)_\(turn ?? 0)"
        self.turn = turn
        self.name = name
        self.tagId = .default
        self.isRepeating = isRepeating
        self.isForemost = false
    }
    
    public init?(
        _ schedule: ScheduleCalendarEvent,
        in todayRange: Range<TimeInterval>,
        timeZone: TimeZone,
        _ is24hourForm: Bool,
        forceShowEventDateDurationText: Bool = false
    ) {
        guard let time = schedule.eventTime else { return nil }
        let periodText = EventPeriodText(schedule: time, in: todayRange, timeZone: timeZone, is24hourForm: is24hourForm)
        self.eventIdentifier = schedule.eventId
        self.eventIdWithoutTurn = schedule.eventIdWithoutTurn
        self.turn = schedule.turn
        self.tagId = schedule.eventTagId
        self.name = schedule.name
        self.periodText = periodText
        self.periodDescription = schedule.eventTime?.durationText(
            timeZone, forceShowEventDateDurationText: forceShowEventDateDurationText
        )
        self.eventTimeRawValue = schedule.eventTime
        
        self.isRepeating = schedule.isRepeating
        self.isForemost = schedule.isForemost
    }
    
    public var moreActions: EventListMoreActionModel? {
        let removeActions: [EventListMoreAction] = self.isRepeating
            ? [.remove(onlyThisTime: true), .remove(onlyThisTime: false)]
            : [.remove(onlyThisTime: false)]
        return .init(
            basicActions: [.toggleTo(isForemost: self.isForemost), .edit, .copy],
            removeActions: removeActions
        )
    }
}


// MARK: - Holiday
public struct HolidayEventCellViewModel: EventCellViewModel {
    
    public let eventIdentifier: String
    public var tagId: AllEventTagId
    public let name: String
    public var periodText: EventPeriodText?
    public var periodDescription: String?
    public var tagColor: EventTagColor?
    public let isRepeating: Bool = false
    public let isForemost: Bool = false
    public var customCompareKey: String { self.makeCustomCompareKey(["holidays"]) }
    
    public init(_ holiday: HolidayCalendarEvent) {
        self.eventIdentifier = holiday.eventId
        self.name = holiday.name
        self.periodText = .singleText(
            .init(text: R.String.calendarEventTimeAllday)
        )
        self.tagId = .holiday
        self.tagColor = .holiday
    }
    
    public mutating func applyTagColor(_ tag: EventTag?) {
        self.tagColor = .holiday
    }
    
    public var moreActions: EventListMoreActionModel? { nil }
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
        formatter.dateFormat = isShort ? R.String.dateForm24offHMm : R.String.dateForm24onHMm
        return formatter.string(from: Date(timeIntervalSince1970: self))
    }
    
    func dayText(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = R.String.dateFormDE.localized()
        return formatter.string(from: Date(timeIntervalSince1970: self))
    }
}

private extension EventTime {
    
    func durationText(
        _ timeZone: TimeZone,
        forceShowEventDateDurationText: Bool
    ) -> String? {
        
        switch self {
        case .at(let time) where forceShowEventDateDurationText:
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = R.String.dateFormMMMD
            return formatter.string(from: Date(timeIntervalSince1970: time))
            
        case .period(let range):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = R.String.dateFormMMMDHHMm
            return "\(range.rangeText(formatter))(\(range.totalPeriodText()))"
            
        case .allDay(let range, let secondsFrom):
            let formatter = DateFormatter() |> \.timeZone .~ timeZone
            formatter.dateFormat = R.String.dateFormMMMD
            let shifttingRange = range.shiftting(secondsFrom, to: timeZone)
            let days = Int(shifttingRange.upperBound-shifttingRange.lowerBound) / (24 * 3600)
            if days > 0 {
                let totalPeriodText = R.String.calendarEventTimePeriodSomeDays(days+1)
                let rangeText = shifttingRange.rangeText(formatter)
                return "\(rangeText)(\(totalPeriodText))"
            } else if forceShowEventDateDurationText {
                return "calendar::event_time::allday::with".localized(
                    with: formatter.string(from: Date(timeIntervalSince1970: shifttingRange.lowerBound))
                )
            } else {
                return nil
            }

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
            return R.String.calendarEventTimePeriodSomeMinutes(m)
        case let (d, h, _) where d == 0:
            return R.String.calendarEventTimePeriodSomeHours(h)
        case let (d, h, _):
            return R.String.calendarEventTimePeriodSomeDaysSomeHours(d, h)
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
