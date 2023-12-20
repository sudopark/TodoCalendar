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


enum EventTimeOnCalendar: Hashable {
    case at(TimeInterval)
    case period(Range<TimeInterval>)
    
    init(_ time: EventTime, timeZone: TimeZone) {
        switch time {
        case .at(let interval):
            self = .at(interval)
        case .period(let range):
            self = .period(range)
        case .allDay(let range, let secondsFromGMT):
            self = .period(range.shiftting(secondsFromGMT, to: timeZone))
        }
    }
    
    func clamped(to period: Range<TimeInterval>) -> Range<TimeInterval>? {
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

protocol CalendarEvent {
    
    var eventId: String { get }
    var name: String { get }
    var eventTime: EventTime? { get }
    var eventTimeOnCalendar: EventTimeOnCalendar? { get }
    var eventTagId: AllEventTagId { get }
}

extension CalendarEvent {
    
    var compareKey: String {
        return "\(String(describing: Self.self))-\(eventId)-\(name)-\(eventTime?.hashValue ?? -1)-\(eventTimeOnCalendar?.hashValue ?? -1)-\(eventTagId.hashValue)"
    }
}


// MARK: - TodoCalenadrEvent

struct TodoCalendarEvent: CalendarEvent {
    
    let eventId: String
    let name: String
    let eventTime: EventTime?
    let eventTimeOnCalendar: EventTimeOnCalendar?
    let eventTagId: AllEventTagId
    
    init(_ todo: TodoEvent, in timeZone: TimeZone) {
        self.eventId = todo.uuid
        self.name = todo.name
        self.eventTime = todo.time
        self.eventTimeOnCalendar = todo.time.map { EventTimeOnCalendar($0, timeZone: timeZone) }
        self.eventTagId = todo.eventTagId ?? .default
    }
}

struct ScheduleCalendarEvent: CalendarEvent {
    
    let eventIdWithoutTurn: String
    let eventId: String
    let name: String
    let eventTime: EventTime?
    let eventTimeOnCalendar: EventTimeOnCalendar?
    let eventTagId: AllEventTagId
    var turn: Int = 0
    
    static func events(
        from schedule: ScheduleEvent,
        in timeZone: TimeZone
    ) -> [ScheduleCalendarEvent] {
        
        return schedule.repeatingTimes
            .map {
                .init(
                    eventIdWithoutTurn: schedule.uuid,
                    eventId: "\(schedule.uuid)-\($0.turn)",
                    name: schedule.name,
                    eventTime: $0.time,
                    eventTimeOnCalendar: .init($0.time, timeZone: timeZone),
                    eventTagId: schedule.eventTagId ?? .default
                )
                |> \.turn .~ $0.turn
            }
    }
}


struct HolidayCalendarEvent: CalendarEvent {
    
    let eventId: String
    let name: String
    let eventTime: EventTime?
    let eventTimeOnCalendar: EventTimeOnCalendar?
    let eventTagId: AllEventTagId
    
    init?(_ holiday: Holiday, in timeZone: TimeZone) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let components = holiday.dateComponents()
        else { return nil }
        let dateComponents = DateComponents(year: components.0, month: components.1, day: components.2)
        let startComponents = dateComponents |> \.hour .~ 0 |> \.minute .~ 0 |> \.second .~ 0
        let endComponents = dateComponents |> \.hour .~ 23 |> \.minute .~ 59 |> \.second .~ 59
        
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents)
        else { return nil }
        
        self.eventId = "\(holiday.dateString)-\(holiday.name)"
        self.name = holiday.localName
        let timeRange = start.timeIntervalSince1970..<end.timeIntervalSince1970
        self.eventTime = .period(timeRange)
        self.eventTimeOnCalendar = .period(timeRange)
        self.eventTagId = .holiday
    }
}


extension Publisher where Output: Sequence, Failure == Never {
    
    func filterTagActivated(
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
