//
//  CalendarEvent.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/14/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


public enum EventTimeOnCalendar: Hashable, Sendable {
    case at(TimeInterval)
    case period(Range<TimeInterval>)
    
    public init(_ time: EventTime, timeZone: TimeZone) {
        switch time {
        case .at(let interval):
            self = .at(interval)
        case .period(let range):
            self = .period(range)
        case .allDay(let range, let secondsFromGMT):
            self = .period(range.shiftting(secondsFromGMT, to: timeZone))
        }
    }
    
    public func clamped(to period: Range<TimeInterval>) -> Range<TimeInterval>? {
        switch self {
        case .at(let time):
            return period ~= time
                ? time..<time
                : nil
        case .period(let range):
            let clamped = range.clamped(to: period)
            return clamped.isEmpty ? nil : clamped
        }
    }
    
    var isPeriod: Bool {
        guard case .period = self else { return false }
        return true
    }
}


// MARK: - CalendarEvent

public protocol CalendarEvent: Sendable {
    
    var eventId: String { get }
    var name: String { get }
    var eventTime: EventTime? { get }
    var eventTimeOnCalendar: EventTimeOnCalendar? { get }
    var eventTagId: AllEventTagId { get }
    var isForemost: Bool { get }
    var isRepeating: Bool { get }
}

extension Array where Element == any CalendarEvent {
    
    public func sortedByEventTime() -> Array {
        
        let compare: (Element, Element) -> Bool = { lhs, rhs in
            switch (lhs.eventTime, rhs.eventTime) {
            case (.some(let leftTime), .some(let rightTime)):
                return leftTime.lowerBoundWithFixed < rightTime.lowerBoundWithFixed
            default: return false
            }
        }
        
        return self.sorted(by: compare)
    }
}

extension CalendarEvent {
    
    public var compareKey: String {
        return "\(String(describing: Self.self))-\(eventId)-\(name)-\(eventTime?.hashValue ?? -1)-\(eventTimeOnCalendar?.hashValue ?? -1)-\(eventTagId.hashValue)-\(self.isForemost)"
    }
}


// MARK: - TodoCalenadrEvent

public struct TodoCalendarEvent: CalendarEvent {
    
    public let eventId: String
    public let name: String
    public let eventTime: EventTime?
    public let eventTimeOnCalendar: EventTimeOnCalendar?
    public let eventTagId: AllEventTagId
    public let isRepeating: Bool
    public var isForemost: Bool = false
    public var createdAt: TimeInterval?
    
    public init(current todo: TodoEvent, isForemost: Bool) {
        self.eventId = todo.uuid
        self.name = todo.name
        self.eventTime = nil
        self.eventTimeOnCalendar = nil
        self.eventTagId = todo.eventTagId ?? .default
        self.isRepeating = false
        self.isForemost = isForemost
        self.createdAt = todo.creatTimeStamp
    }
    
    public init(_ todo: TodoEvent, in timeZone: TimeZone, isForemost: Bool = false) {
        self.eventId = todo.uuid
        self.name = todo.name
        self.eventTime = todo.time
        self.eventTimeOnCalendar = todo.time.map { EventTimeOnCalendar($0, timeZone: timeZone) }
        self.eventTagId = todo.eventTagId ?? .default
        self.isRepeating = todo.time != nil && todo.repeating != nil
        self.isForemost = isForemost
        self.createdAt = todo.creatTimeStamp
    }
}

extension Array where Element == TodoCalendarEvent {
    
    public func sortedByCreateTime() -> Array {
        let compare: (Element, Element) -> Bool = { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case (.some, .none): return true
            case (.none, .some): return false
            case (.some(let lt), .some(let rt)): return lt <= rt
            case (.none, .none): return lhs.name < rhs.name
            }
        }
        return self.sorted(by: compare)
    }
}

public struct ScheduleCalendarEvent: CalendarEvent {
    
    public let eventIdWithoutTurn: String
    public let eventId: String
    public let name: String
    public let eventTime: EventTime?
    public let eventTimeOnCalendar: EventTimeOnCalendar?
    public let eventTagId: AllEventTagId
    public var turn: Int = 0
    public let isRepeating: Bool
    public var isForemost: Bool = false
    
    public static func events(
        from schedule: ScheduleEvent,
        in timeZone: TimeZone,
        foremostId: String? = nil
    ) -> [ScheduleCalendarEvent] {
        
        return schedule.repeatingTimes
            .map {
                .init(
                    eventIdWithoutTurn: schedule.uuid,
                    eventId: "\(schedule.uuid)-\($0.turn)",
                    name: schedule.name,
                    eventTime: $0.time,
                    eventTimeOnCalendar: .init($0.time, timeZone: timeZone),
                    eventTagId: schedule.eventTagId ?? .default,
                    isRepeating: schedule.repeating != nil,
                    isForemost: foremostId == schedule.uuid
                )
                |> \.turn .~ $0.turn
            }
    }
}


public struct HolidayCalendarEvent: CalendarEvent {
    
    public let dateString: String
    public let eventId: String
    public let name: String
    public let eventTime: EventTime?
    public let eventTimeOnCalendar: EventTimeOnCalendar?
    public let eventTagId: AllEventTagId
    public let isRepeating: Bool = true
    public let isForemost: Bool = false
    
    public init?(_ holiday: Holiday, in timeZone: TimeZone) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let components = holiday.dateComponents()
        else { return nil }
        let dateComponents = DateComponents(year: components.0, month: components.1, day: components.2)
        let startComponents = dateComponents |> \.hour .~ 0 |> \.minute .~ 0 |> \.second .~ 0
        let endComponents = dateComponents |> \.hour .~ 23 |> \.minute .~ 59 |> \.second .~ 59
        
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents)
        else { return nil }
        
        self.dateString = holiday.dateString
        self.eventId = "\(holiday.dateString)-\(holiday.name)"
        self.name = holiday.localName
        let timeRange = start.timeIntervalSince1970..<end.timeIntervalSince1970
        self.eventTime = .period(timeRange)
        self.eventTimeOnCalendar = .period(timeRange)
        self.eventTagId = .holiday
    }
}


extension EventTagUsecase {
    
    func cellWithTagInfo<P: Publisher>(
        _ source: P
    ) -> AnyPublisher<[any EventCellViewModel], Never>
    where P.Output == [any EventCellViewModel], P.Failure == Never {
        
        typealias CellsAndTag = (P.Output, [String: EventTag])
        let withTags: (P.Output) -> AnyPublisher<CellsAndTag, Never>
        withTags = { [weak self] cells in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            let customTagIds = cells.compactMap { $0.tagId.customTagId }
            guard !customTagIds.isEmpty
            else {
                return Just((cells, [:])).eraseToAnyPublisher()
            }
            return self.eventTags(customTagIds)
                .map { (cells, $0) }
                .eraseToAnyPublisher()
        }
        
        let applyTag: (CellsAndTag) -> [any EventCellViewModel] = { pair in
            let (cells, tags) = pair
            return cells.map { cell -> any EventCellViewModel in
                let tag = cell.tagId.customTagId.flatMap { tags[$0] }
                var cell = cell
                cell.applyTagColor(tag)
                return cell
            }
        }
        
        return source
            .map(withTags)
            .switchToLatest()
            .map(applyTag)
            .eraseToAnyPublisher()
    }
}


extension Publisher where Output: Sequence, Failure == Never {
    
    public func filterTagActivated(
        _ tagUseacse: any EventTagUsecase,
        tagSelector: @escaping (Output.Element) -> AllEventTagId
    ) -> AnyPublisher<[Output.Element], Never> {
        
        let filtering: (Output, Set<AllEventTagId>) -> [Output.Element]
        filtering = { outputs, offIds in
            return outputs.filter { !offIds.contains(tagSelector($0)) }
        }
        
        return Publishers.CombineLatest(
            self,
            tagUseacse.offEventTagIdsOnCalendar()
        )
        .map(filtering)
        .eraseToAnyPublisher()
    }
}
