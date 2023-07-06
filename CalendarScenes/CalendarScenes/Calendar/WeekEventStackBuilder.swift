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
}

struct EventOnWeek {
    let eventRangesOnWeek: Range<TimeInterval>
    let weekDaysRange: ClosedRange<Int>
    let eventId: EventId
    
    fileprivate var length: Int { self.weekDaysRange.count }
    
    init?(_ event: CalendarEvent, on weekRange: Range<TimeInterval>, with calendar: Calendar) {
        let eventRange: Range<TimeInterval> = event.time.lowerBoundTimeStamp.utcTimeInterval..<event.time.upperBoundTimeStamp.utcTimeInterval
        let overlapRange = eventRange.clamped(to: weekRange)
        guard !overlapRange.isEmpty else { return nil }
        self.eventId = event.eventId
        self.eventRangesOnWeek = overlapRange
        guard let range = calendar.eventWeekDaysRange(overlapRange, weekRange)
        else { return nil }
        self.weekDaysRange = range
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
            let (lhsLength, rhsLength) = (lhs.eventExistsLength(), rhs.eventExistsLength())
            return lhsLength == rhsLength ? lhs.count < rhs.count : lhsLength > rhsLength
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
            return lhs.length == rhs.length
                ? lhs.weekDaysRange.lowerBound < rhs.weekDaysRange.lowerBound
                : lhs.length > rhs.length
        }
        var sortCandidate = candidates.sorted(by: sorting)
        
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
    
    private func date(from day: CalendarComponent.Day) -> Date? {
        let components = DateComponents(
            year: day.year, month: day.month, day: day.day,
            hour: 0, minute: 0, second: 0
        )
        return self.date(from: components)
    }
    
    // this_week_monday.start..<next_week_monday.start
    func weekRange(_ week: CalendarComponent.Week) -> Range<TimeInterval>? {
        guard let firstDay = week.days.first, let lastDay = week.days.last,
              let lowerBoundDate = self.date(from: firstDay).flatMap(self.startOfDay(for:)),
              let upperBoundDate = self.date(from: lastDay).flatMap(self.lastTimeOfDay(from:))
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
    
    func eventExistsLength() -> Int {
        return self.reduce(into: Set<Int>()) { acc, event in
            event.weekDaysRange.forEach { acc.insert($0) }
        }
        .count
    }
}
