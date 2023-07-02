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
        
    private struct CacheItem {
        
        var event: ScheduleEvent
        var calculatedRangeAndTimes: [(Range<TimeInterval>, [ScheduleEvent.RepeatingTimes])] = []
        
        init(event: ScheduleEvent) {
            self.event = event
        }
        
        func isNotCalculated(for period: Range<TimeInterval>) -> Bool {
            return self.event.repeating != nil
                && self.calculatedRangeAndTimes
                .first(where: { period.isSubRange(of: $0.0) }) == nil
        }
        
        func firstCacheIndex(contains time: TimeInterval) -> Int? {
            return self.calculatedRangeAndTimes.firstIndex(where: {
                $0.0.contains(time)
            })
        }
        
        func nextCacheIndex(from time: TimeInterval, until end: TimeInterval) -> Int? {
            return self.calculatedRangeAndTimes.firstIndex(where: {
                return time < $0.0.lowerBound && $0.0.lowerBound < end
            })
        }
        
        mutating func append(new : (Range<TimeInterval>, [ScheduleEvent.RepeatingTimes])) {
            self.calculatedRangeAndTimes.append(new)
            self.event.nextRepeatingTimes = self.calculatedRangeAndTimes.flatMap { $0.1 }
        }
        
        func replaced(_ newEvent: ScheduleEvent) -> CacheItem {
            return self
                |> \.event .~ (newEvent |> \.nextRepeatingTimes .~ self.event.nextRepeatingTimes)
        }
    }
    
    private var caches: [String: CacheItem] = [:]
}


extension MemorizedScheduleEventsContainer {
    
    func scheduleEvents(in period: Range<TimeInterval>) -> [ScheduleEvent] {
        return self.caches.values
            .map { $0 }
            .filter { $0.event.isOverlap(with: period) }
            .map { cache in
                guard cache.isNotCalculated(for: period) else { return cache }
                return self.calculateRepeatingTimes(cache.event, with: cache, in: period)
            }
            .map { $0.event }
    }
    
    func invalidate(_ eventId: String) -> MemorizedScheduleEventsContainer {
        return MemorizedScheduleEventsContainer(
            caches: self.caches |> key(eventId) .~ nil
        )
    }
    
    func append(_ newEvent: ScheduleEvent) -> MemorizedScheduleEventsContainer {
        let newItem: CacheItem
        if let cached = self.caches[newEvent.uuid],
           newEvent.isEqualEventTimeAndRepeatOption(cached.event) {
            newItem = cached.replaced(newEvent)
        } else {
            newItem = .init(event: newEvent)
        }
        return MemorizedScheduleEventsContainer(
            caches: self.caches |> key(newEvent.uuid) .~ newItem
        )
    }
    
    func refresh(_ events: [ScheduleEvent], in period: Range<TimeInterval>) -> MemorizedScheduleEventsContainer {
        
        let cachedInPeriodMap = self.caches.values
            .filter { $0.event.isOverlap(with: period) }
            .asDictionary { $0.event.uuid }
        let newEventsMap = events.asDictionary { $0.uuid }
        
        let removed = cachedInPeriodMap.filter { newEventsMap[$0.key] == nil }
        var newItems = self.caches.filter { removed[$0.value.event.uuid] == nil }
        
        let newEventsWithCalculate = events.map { new in
            let cached: CacheItem? = cachedInPeriodMap[new.uuid]
            let shouldIgnoreCache = cached.map { !new.isEqualEventTimeAndRepeatOption($0.event) } ?? false
            return self.calculateRepeatingTimes(
                new, with: shouldIgnoreCache ? nil : cached, in: period
            )
        }
        newEventsWithCalculate.forEach {
            newItems[$0.event.uuid] = $0
        }
        
        return .init(caches: newItems)
    }
    
    private func calculateRepeatingTimes(
        _ event: ScheduleEvent,
        with cached: CacheItem?,
        in period: Range<TimeInterval>
    ) -> CacheItem {
        guard let repeating = event.repeating
        else {
            return .init(event: event)
        }
        let cached = cached ?? CacheItem(event: event)
        guard let enumerator = EventRepeatTimeEnumerator(
            repeating.repeatOption, without: event.repeatingTimeToExcludes
        )
        else { return cached }
        
        let (startTime, end) = (
            event.time,
            repeating.repeatingEndTime.map { min($0.utcTimeInterval, period.upperBound) } ?? period.upperBound
        )
        
        let calculatedResult = self.calculateRepeatingTimesBlock(
            enumerator,
            from: .init(time: startTime, turn: 1),
            unitl: end,
            acc: .empty(cached)
        )
        guard let newRange = calculatedResult.newRange
        else {
            return cached
        }
        var newItem = calculatedResult.cacheItem
        newItem.append(new: (newRange, calculatedResult.newCalculated))
        
        return newItem
    }
    
    private struct BlockCalculateResult {
        let newRange: Range<TimeInterval>?
        let newCalculated: [ScheduleEvent.RepeatingTimes]
        var cacheItem: CacheItem
        init(
            _ newRange: Range<TimeInterval>?,
            _ newCalculated: [ScheduleEvent.RepeatingTimes],
            _ cacheItem: CacheItem
        ) {
            self.newRange = newRange
            self.newCalculated = newCalculated
            self.cacheItem = cacheItem
        }
        
        static func empty(_ cachedItem: CacheItem) -> BlockCalculateResult {
            return .init(nil, [], cachedItem)
        }
    }
    
    // 캐싱된 값이 많아질수록(파편이 많을수록) 연산량이 늘어나고 재귀걸리다 스택 터질수도있음
    // 파편화된 캐시 블럭을 합쳐주는 로직이 잘 돌아가야함
    // 대부분 조회는 1달 단위로 조회하고 또한 캐싱도 한달 단위로 된다고 했을때 대부분 return 2에 걸릴것으로 예상
    // 달 조회를 많이 할수록 파편화돤 캐시블럭은 많아지겠지만 계산시에 return 2 or return 5에 걸리고 해당 연산량은 그리 크지 않을것으로 예상
    private func calculateRepeatingTimesBlock(
        _ enumerator: EventRepeatTimeEnumerator,
        from start: ScheduleEvent.RepeatingTimes,
        unitl end: TimeInterval,
        acc result: BlockCalculateResult
    ) -> BlockCalculateResult {
        let startTime = start.time.lowerBoundTimeStamp.utcTimeInterval
        // return 1
        guard startTime < end else { return result }
        
        var result = result
        
        if let blockIndex = result.cacheItem.firstCacheIndex(contains: startTime) {
            // 현재 시작점을 포함하는 범위의 캐시가 존재한다면
            // cache.start..<start..<(cache.end or end)
            let (blockRange, block) = result.cacheItem.calculatedRangeAndTimes.remove(at: blockIndex)
            guard end > blockRange.upperBound
            else{
                // return2: block.start..period..<block.end -> period를 포함하는 캐시를 리턴
                return .init(blockRange, block, result.cacheItem)
            }
            
            // block.start..period.start..block.end..<period.end
            // -> subBlock1: cache -> block.start..<block.end
            // -> subBlock2: block.end..<period.end
            let block_to_end = self.calculateRepeatingTimesBlock(
                enumerator, from: block.last ?? start, unitl: end, acc: result
            )
            // return 3
            return .init(
                blockRange.lowerBound..<end,
                block + block_to_end.newCalculated,
                block_to_end.cacheItem
            )
            
        } else if let blockIndex = result.cacheItem.nextCacheIndex(from: startTime, until: end) {
            // start..<cache.start..<end 내에 캐시가 존재한다면
            let (blockRange, block) = result.cacheItem.calculatedRangeAndTimes.remove(at: blockIndex)
            
            // leftBlock: start..<block.start
            // centerBlock: cache -> block.start..<block.end
            // rightBlock: block.end..<end
            
            let newEnd = max(end, blockRange.upperBound)
            let start_to_block = self.enumerateEventTimes(
                enumerator, from: start, until: blockRange.lowerBound
            )
            let block_to_end = self.calculateRepeatingTimesBlock(
                enumerator, from: block.last ?? start, unitl: newEnd, acc: result
            )
            // return 4
            return .init(
                startTime..<newEnd,
                start_to_block + block + block_to_end.newCalculated,
                block_to_end.cacheItem
            )
        } else {
            // return 5 캐싱된것이 없다면 주어진 범위까지 계산
            return .init(
                startTime..<end,
                self.enumerateEventTimes(enumerator, from: start, until: end),
                result.cacheItem
            )
        }
    }
    
    private func enumerateEventTimes(
        _ enumerator: EventRepeatTimeEnumerator,
        from start: ScheduleEvent.RepeatingTimes,
        until end: TimeInterval
    ) -> [ScheduleEvent.RepeatingTimes] {
        let nextFirstTurn = start.turn + 1
        return enumerator.nextEventTimes(from: start.time, until: end)
            .enumerated()
            .map { pair -> ScheduleEvent.RepeatingTimes in
                return .init(time: pair.element, turn: nextFirstTurn + pair.offset)
            }
    }
}

private extension ScheduleEvent {
    
    func isEqualEventTimeAndRepeatOption(_ old: ScheduleEvent) -> Bool {
        return self.time == old.time
            && self.repeating == old.repeating
    }
}

private extension Range where Bound == TimeInterval {
    
    func isSubRange(of parentRange: Range) -> Bool {
        return parentRange.lowerBound <= self.lowerBound
            && self.upperBound <= parentRange.upperBound
    }
}

private func min(_ lhs: TimeStamp, _ rhs: TimeStamp) -> TimeStamp {
    return lhs.utcTimeInterval <= rhs.utcTimeInterval ? lhs : rhs
}

private func max(_ lhs: TimeStamp, _ rhs: TimeStamp) -> TimeStamp {
    return lhs.utcTimeInterval >= rhs.utcTimeInterval ? lhs : rhs
}
