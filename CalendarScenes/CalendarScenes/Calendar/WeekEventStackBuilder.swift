//
//  WeekEventStackBuilder.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/05.
//

import Foundation
import Domain
import Prelude
import Optics


struct CalendarEvent: Equatable {

    let eventId: EventId
    let time: EventTime
    
    init(_ eventId: EventId, _ time: EventTime) {
        self.eventId = eventId
        self.time = time
    }
    
    init?(_ todo: TodoEvent) {
        guard let time = todo.time else { return nil }
        self.eventId = .todo(todo.uuid)
        self.time = time
    }
    
    init?(_ holiday: Holiday, timeZone: TimeZone) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let components = holiday.dateComponents()
        else { return nil }
        
        let dateComponents = DateComponents(year: components.0, month: components.1, day: components.2)
        let startComponents = dateComponents |> \.hour .~ 0 |> \.minute .~ 0 |> \.second .~ 0
        let endComponents = dateComponents |> \.hour .~ 23 |> \.minute .~ 59 |> \.second .~ 59
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents)
        else { return nil }
        self.eventId = .holiday(holiday.dateString, name: holiday.name)
        self.time = .period(start.timeIntervalSince1970..<end.timeIntervalSince1970)
    }
    
    static func events(
        from scheduleEvnet: ScheduleEvent
    ) -> [CalendarEvent] {
        return scheduleEvnet.repeatingTimes
            .map { CalendarEvent(.schedule(scheduleEvnet.uuid, turn: $0.turn), $0.time) }
    }
}

struct EventOnWeek {
    let eventRangesOnWeek: Range<TimeInterval>
    let weekDaysRange: ClosedRange<Int>
    let eventId: EventId
    
    fileprivate var length: Int { self.weekDaysRange.count }
    
    init?(_ event: CalendarEvent, on weekRange: Range<TimeInterval>, with calendar: Calendar) {
        guard let overlapRange = event.time.clamped(to: weekRange) else { return nil }
        self.eventId = event.eventId
        self.eventRangesOnWeek = overlapRange
        guard let range = calendar.eventWeekDaysRange(overlapRange, weekRange)
        else { return nil }
        self.weekDaysRange = range
    }
    
    init(
        eventRangesOnWeek: Range<TimeInterval>,
        weekDaysRange: ClosedRange<Int>,
        eventId: EventId
    ) {
        self.eventRangesOnWeek = eventRangesOnWeek
        self.weekDaysRange = weekDaysRange
        self.eventId = eventId
    }
}

struct WeekEventStack {
    
    let eventStacks: [[EventOnWeek]]
}


struct WeekEventStackBuilder {
    
    private let calendar: Calendar
    init(_ timeZone: TimeZone) {
        self.calendar = .init(identifier: .gregorian) |> \.timeZone .~ timeZone
    }
}

extension WeekEventStackBuilder {
    
    func build(_ week: CalendarComponent.Week, events: [CalendarEvent]) -> WeekEventStack {
        guard let weekRange = self.calendar.weekRange(week)
        else { return .init(eventStacks: []) }
        
        let eventsOnThisWeek = events
            .compactMap { EventOnWeek($0, on: weekRange, with: self.calendar) }
            .filter { !$0.weekDaysRange.isEmpty }
            .sorted(by: { $0.length > $1.length })
        
        let sorting: ([EventOnWeek], [EventOnWeek]) -> Bool = { lhs, rhs in
            let (lhsLength, rhsLength) = (lhs.eventExistsLength, rhs.eventExistsLength)
            guard lhsLength == rhsLength else {
                return lhsLength > rhsLength
            }
            let (firstLhs, firstRhs) = (lhs.firstEventWeekDay, rhs.firstEventWeekDay)
            guard firstLhs == firstRhs else {
                return firstLhs < firstRhs
            }
            return lhs.count < rhs.count
        }
        
        let stacks = self.stack(remains: eventsOnThisWeek, stacks: [])
            .sorted(by: sorting)
        
        return .init(eventStacks: stacks)

    }
    
    private func stack(
        remains: [EventOnWeek],
        stacks: [[EventOnWeek]] = []
    ) -> [[EventOnWeek]] {
        var remains = remains.sorted(by: { $0.length > $1.length })
        guard !remains.isEmpty
        else { return stacks }
        
        let target = remains.removeFirst()
        if target.weekDaysRange == (1...7) {
            return self.stack(remains: remains, stacks: [[target]] + stacks)
        }
        
        let (leftCandidate, rightCandidate, dropouts) = remains.neighborCandidates(from: target)
        
        let (leftDropouts, leftNeighbors) = self.findNeighors(
            0...target.weekDaysRange.lowerBound-1,
            leftCandidate
        )
        
        let (rightDropouts, rightNeigbors) = self.findNeighors(
            target.weekDaysRange.upperBound+1...8,
            rightCandidate
        )
        
        let newStackRow = leftNeighbors + [target] + rightNeigbors
        let newRemains = (leftDropouts + dropouts + rightDropouts)
        return self.stack(
            remains: newRemains,
            stacks: [newStackRow] + stacks
        )
    }
     
    private func findNeighors(
        _ range: ClosedRange<Int>,
        _ candidates: [EventOnWeek]
    ) -> (dropouts: [EventOnWeek], neighbors: [EventOnWeek]) {
     
        let sorting: (EventOnWeek, EventOnWeek) -> Bool = { lhs, rhs in
            guard lhs.length == rhs.length
            else {
                return lhs.length > rhs.length
            }
            guard lhs.weekDaysRange.lowerBound == rhs.weekDaysRange.lowerBound
            else {
                return lhs.weekDaysRange.lowerBound < rhs.weekDaysRange.lowerBound
            }
            return lhs.eventId.isHoliday
        }
        let sortCandidate = candidates.sorted(by: sorting)
        
        guard let target = sortCandidate.first
        else {
            return (sortCandidate, [])
        }

        let remains = Array(sortCandidate.dropFirst())
        
        let (leftCandidate, rightCandidate, dropouts) = remains.neighborCandidates(from: target)
        
        let (leftDropouts, leftNeighbors) = self.findNeighors(
            0...target.weekDaysRange.lowerBound-1,
            leftCandidate
        )
        
        let (rightDropouts, rightNeighbors) = self.findNeighors(
            target.weekDaysRange.upperBound+1...8,
            rightCandidate
        )
        
        return (
            dropouts + leftDropouts + rightDropouts,
            leftNeighbors + [target] + rightNeighbors
        )
    }
}


private extension Calendar {
    
    // this_week_monday.start..<next_week_monday.start
    func weekRange(_ week: CalendarComponent.Week) -> Range<TimeInterval>? {
        guard let firstDay = week.days.first, let lastDay = week.days.last,
              let lowerBoundDate = self.date(from: firstDay).flatMap(self.startOfDay(for:)),
              let upperBoundDate = self.date(from: lastDay).flatMap(self.endOfDay(for:))
        else { return nil }
        return lowerBoundDate.timeIntervalSince1970..<upperBoundDate.timeIntervalSince1970
    }
    
    func eventWeekDaysRange(
        _ eventOnWeekRange: Range<TimeInterval>,
        _ weekRange: Range<TimeInterval>
    ) -> ClosedRange<Int>? {
        
        let firstDate = Date(timeIntervalSince1970: eventOnWeekRange.lowerBound)
        let lastDate = Date(timeIntervalSince1970: eventOnWeekRange.upperBound)
        let firstDateWeekDay = self.component(.weekday, from: firstDate)
        let lastDateWeekDay = self.component(.weekday, from: lastDate)
        guard firstDateWeekDay <= lastDateWeekDay else { return nil }
        return (firstDateWeekDay...lastDateWeekDay)
    }
}

private extension Array where Element == EventOnWeek {
    
    func neighborCandidates(from center: EventOnWeek) -> (
        left: [EventOnWeek],
        right: [EventOnWeek],
        dropouts: [EventOnWeek]
    ) {
        let leftBound = center.weekDaysRange.lowerBound
        let rightBound = center.weekDaysRange.upperBound
        
        var (left, right, notCandidate) = ([EventOnWeek](), [EventOnWeek](), [EventOnWeek]())
        self.forEach {
            if $0.weekDaysRange.upperBound < leftBound {
                left.append($0)
            } else if rightBound < $0.weekDaysRange.lowerBound {
                right.append($0)
            } else {
                notCandidate.append($0)
            }
        }
        
        return (left, right, notCandidate)
    }
    
    var eventExistsLength: Int {
        return self.reduce(into: Set<Int>()) { acc, event in
            event.weekDaysRange.forEach { acc.insert($0) }
        }
        .count
    }
    
    var firstEventWeekDay: Int {
        return self.first?.weekDaysRange.lowerBound ?? 8
    }
}
