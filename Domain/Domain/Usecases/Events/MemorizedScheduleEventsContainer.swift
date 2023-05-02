//
//  MemorizedScheduleEventsContainer.swift
//  Domain
//
//  Created by sudo.park on 2023/05/01.
//

import Foundation
import Prelude
import Optics


struct MemorizedScheduleEventsContainer {
        
    private struct Item {
        
        var event: ScheduleEvent
        var calcualtedRanges: [Range<TimeStamp>] = []
        
        init(event: ScheduleEvent) {
            self.event = event
        }
        
        func isNotCalculated(for period: Range<TimeStamp>) -> Bool {
            return self.calcualtedRanges.first(where: { period.isSubRange(of: $0) }) == nil
        }
    }
    
    private var items: [String: Item] = [:]
}


extension MemorizedScheduleEventsContainer {
    
    func scheduleEvents(in period: Range<TimeStamp>) -> [ScheduleEvent] {
        return self.items.values
            .map { $0 }
            .filter { $0.event.isOverlap(with: period) }
            .map { item in
                guard item.isNotCalculated(for: period) else { return item }
                return self.calculateRepeatingTimes(item.event, with: item, in: period)
            }
            .map { $0.event }
    }
    
    func append(_ newEvent: ScheduleEvent) -> MemorizedScheduleEventsContainer {
        return MemorizedScheduleEventsContainer(
            items: self.items |> key(newEvent.uuid) .~ .init(event: newEvent)
        )
    }
    
    func refresh(_ events: [ScheduleEvent], in period: Range<TimeStamp>) -> MemorizedScheduleEventsContainer {
        
        let cachedInPeriodMap = self.items.values
            .filter { $0.event.isOverlap(with: period) }
            .asDictionary { $0.event.uuid }
        let newEventsMap = events.asDictionary { $0.uuid }
        
        let removed = cachedInPeriodMap.filter { newEventsMap[$0.key] == nil }
        var newItems = self.items.filter { removed[$0.value.event.uuid] != nil }
        
        let newEventsWithCalculate = events.map {
            self.calculateRepeatingTimes($0, with: cachedInPeriodMap[$0.uuid], in: period)
        }
        newEventsWithCalculate.forEach {
            newItems[$0.event.uuid] = $0
        }
        
        return .init(items: newItems)
    }
    
    private func calculateRepeatingTimes(
        _ event: ScheduleEvent,
        with cached: Item?,
        in period: Range<TimeStamp>
    ) -> Item {
        guard let repeating = event.repeating
        else {
            return .init(event: event)
        }
        
        // TODO: calculate with cache
        return .init(event: event)
    }
}

private extension Range where Bound == TimeStamp {
    
    func isSubRange(of parentRange: Range) -> Bool {
        return parentRange.lowerBound <= self.lowerBound
            && self.upperBound <= parentRange.upperBound
    }
}
