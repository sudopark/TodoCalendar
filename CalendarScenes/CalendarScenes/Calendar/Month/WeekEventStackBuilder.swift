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


// MARK: - EventOnWeek + WeekEventStack

struct EventOnWeek: Equatable {
    let event: any CalendarEvent
    var name: String { self.event.name }
    let eventRangesOnWeek: Range<TimeInterval>
    let overlapDays: Set<Int>
    let daysSequence: ClosedRange<Int>
    let daysIdentifiers: [String]
    var eventId: String { self.event.eventId }
    var eventTagId: AllEventTagId { self.event.eventTagId }
    var hasPeriod: Bool { self.event.eventTimeOnCalendar?.isPeriod == true }
    var isHoliday: Bool { self.event is HolidayCalendarEvent }
    
    var eventStartDayIdentifierOnWeek: String? { self.daysIdentifiers.first }
    
    fileprivate var length: Int { self.overlapDays.count }
    
    init?(_ event: any CalendarEvent, on weekRange: Range<TimeInterval>, with calendar: Calendar) {
        guard let overlapRange = event.eventTimeOnCalendar?.clamped(to: weekRange) else { return nil }
        self.event = event
        self.eventRangesOnWeek = overlapRange
        
        let allWeekDays = calendar.betweenDays(
            Date(timeIntervalSince1970: weekRange.lowerBound),
            to: Date(timeIntervalSince1970: weekRange.upperBound)
        )
        let overlapDays = calendar.overlapEventDays(overlapRange, weekRange)
        guard let sequence = allWeekDays.weekDaysSubSequences(overlapDays) else { return nil }
        self.overlapDays = overlapDays |> Set.init
        self.daysSequence = sequence
        self.daysIdentifiers = calendar.daysIdentifiers(overlapRange)
    }
    
    init(
        _ eventRangesOnWeek: Range<TimeInterval>,
        _ overlapDays: [Int],
        _ daysSequence: ClosedRange<Int>,
        _ daysIdentifiers: [String],
        _ event: any CalendarEvent,
        _ eventTagId: String? = nil
    ) {
        self.eventRangesOnWeek = eventRangesOnWeek
        self.overlapDays = overlapDays |> Set.init
        self.daysSequence = daysSequence
        self.daysIdentifiers = daysIdentifiers
        self.event = event
    }
    
    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        return lhs.event.compareKey == rhs.event.compareKey
            && lhs.eventRangesOnWeek == rhs.eventRangesOnWeek
    }
}

struct WeekEventStack {
    
    let eventStacks: [[EventOnWeek]]
}


// MARK: - WeekEventStackBuilder

struct WeekEventStackBuilder {
    
    private let calendar: Calendar
    init(_ timeZone: TimeZone) {
        self.calendar = .init(identifier: .gregorian) |> \.timeZone .~ timeZone
    }
}

extension WeekEventStackBuilder {
    
    func build(_ week: CalendarComponent.Week, events: [any CalendarEvent]) -> WeekEventStack {
        guard let weekRange = self.calendar.weekRange(week)
        else { return .init(eventStacks: []) }
        
        let eventsOnThisWeek = events
            .compactMap { EventOnWeek($0, on: weekRange, with: self.calendar) }
            .filter { !$0.daysSequence.isEmpty }
            .sorted(by: { $0.length > $1.length })
        
        let sorting: ([EventOnWeek], [EventOnWeek]) -> Bool = { lhs, rhs in
            let (lhsLength, rhsLength) = (lhs.eventExistsLength, rhs.eventExistsLength)
            guard lhsLength == rhsLength else {
                return lhsLength > rhsLength
            }
            let (firstLhs, firstRhs) = (lhs.firstEventDaySequence, rhs.firstEventDaySequence)
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
        if target.daysSequence == (1...7) {
            return self.stack(remains: remains, stacks: [[target]] + stacks)
        }
        
        let (leftCandidate, rightCandidate, dropouts) = remains.neighborCandidates(from: target)
        
        let (leftDropouts, leftNeighbors) = self.findNeighors(
            0...target.daysSequence.lowerBound-1,
            leftCandidate
        )
        
        let (rightDropouts, rightNeigbors) = self.findNeighors(
            target.daysSequence.upperBound+1...8,
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
            guard lhs.daysSequence.lowerBound == rhs.daysSequence.lowerBound
            else {
                return lhs.daysSequence.lowerBound < rhs.daysSequence.lowerBound
            }
            return lhs.isHoliday
        }
        let sortCandidate = candidates.sorted(by: sorting)
        
        guard let target = sortCandidate.first
        else {
            return (sortCandidate, [])
        }

        let remains = Array(sortCandidate.dropFirst())
        
        let (leftCandidate, rightCandidate, dropouts) = remains.neighborCandidates(from: target)
        
        let (leftDropouts, leftNeighbors) = self.findNeighors(
            0...target.daysSequence.lowerBound-1,
            leftCandidate
        )
        
        let (rightDropouts, rightNeighbors) = self.findNeighors(
            target.daysSequence.upperBound+1...8,
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
    
    func overlapEventDays(
        _ eventOnWeekRange: Range<TimeInterval>,
        _ weekRange: Range<TimeInterval>
    ) -> [Int] {
        
        let firstDate = Date(timeIntervalSince1970: eventOnWeekRange.lowerBound)
        let lastDate = Date(timeIntervalSince1970: eventOnWeekRange.upperBound)
        
        return self.betweenDays(firstDate, to: lastDate)
    }
    
    func betweenDays(_ from: Date, to: Date) -> [Int] {
        var cursor = self.startOfDay(for: from); let end = self.startOfDay(for: to)
        var sender: [Int] = []; let interval: TimeInterval = 24 * 3600
        while cursor.compare(end) != .orderedDescending {
            sender.append(self.component(.day, from: cursor))
            cursor = cursor.addingTimeInterval(interval)
        }
        return sender
    }
}

private extension Array where Element == EventOnWeek {
    
    func neighborCandidates(from center: EventOnWeek) -> (
        left: [EventOnWeek],
        right: [EventOnWeek],
        dropouts: [EventOnWeek]
    ) {
        let leftBound = center.daysSequence.lowerBound
        let rightBound = center.daysSequence.upperBound
        
        var (left, right, notCandidate) = ([EventOnWeek](), [EventOnWeek](), [EventOnWeek]())
        self.forEach {
            if $0.daysSequence.upperBound < leftBound {
                left.append($0)
            } else if rightBound < $0.daysSequence.lowerBound {
                right.append($0)
            } else {
                notCandidate.append($0)
            }
        }
        
        return (left, right, notCandidate)
    }
    
    var eventExistsLength: Int {
        return self.reduce(into: Set<Int>()) { acc, event in
            event.daysSequence.forEach { acc.insert($0) }
        }
        .count
    }
    
    var firstEventDaySequence: Int {
        return self.first?.daysSequence.lowerBound ?? 8
    }
}

private extension Array where Element == Int {
    
    func weekDaysSubSequences(_ slice: [Int]) -> ClosedRange<Int>? {
        guard let sliceFirst = slice.first, let sliceLast = slice.last,
              let firstIndex = self.firstIndex(of: sliceFirst),
              let lastIndex = self.lastIndex(of: sliceLast),
              firstIndex <= lastIndex
        else { return nil }
        return (firstIndex+1...lastIndex+1)
    }
}

private extension Calendar {

    private func dayIdentifier(_ date: Date) -> String {
        let (year, month, day) = (
            self.component(.year, from: date),
            self.component(.month, from: date),
            self.component(.day, from: date)
        )
        return "\(year)-\(month)-\(day)"
    }
    
    func daysIdentifiers(_ range: Range<TimeInterval>) -> [String] {
        guard let lastDateOfEnd = self.endOfDay(for: .init(timeIntervalSince1970: range.upperBound))
        else { return [] }
        var cursor = Date(timeIntervalSince1970: range.lowerBound)
        var sender: [String] = []
        while self.compare(cursor, to: lastDateOfEnd, toGranularity: .day) != .orderedDescending {
            sender.append(self.dayIdentifier(cursor))
            
            cursor = cursor.addingTimeInterval(24 * 3600)
        }
        return sender
    }
}
