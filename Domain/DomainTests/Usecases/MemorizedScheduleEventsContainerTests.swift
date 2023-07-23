//
//  MemorizedScheduleEventsContainerTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/01.
//

import XCTest
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


class MemorizedScheduleEventsContainerTests: BaseTestCase {
    
    private func makeContainer() -> MemorizedScheduleEventsContainer {
        return .init()
    }
    
    private func period(_ range: Range<Int>) -> Range<TimeInterval> {
        return range.lowerBound.days..<range.upperBound.days
    }
    
    private func notRepeatingEvent(_ int: Int) -> ScheduleEvent {
        return ScheduleEvent(
            uuid: "id:\(int)",
            name: "some",
            time: .at(int.days)
        )
    }
    
    private func repeatingEvent(_ int: Int, customId: String? = nil, end: Int? = nil) -> ScheduleEvent {
        let time = int.days
        let repeating = EventRepeating(repeatingStartTime: time, repeatOption: EventRepeatingOptions.EveryDay())
            |> \.repeatingEndTime .~ end.map { $0.days }
        return ScheduleEvent(uuid: customId ?? "id:\(int)", name: "some", time: .at(time))
            |> \.repeating .~ repeating
        
    }
}

extension MemorizedScheduleEventsContainerTests {
    
    // 조회되는 기간에 해당되는 이벤트 반환
    func testContainer_scheduleEventsGivenPeriod() {
        // given
        var container = self.makeContainer()
        container = container.append(self.notRepeatingEvent(1))
        container = container.append(self.repeatingEvent(3))
        container = container.append(self.notRepeatingEvent(4))
        container = container.append(self.repeatingEvent(5, end: 7))
        container = container.append(self.repeatingEvent(6, end: 100))
        
        // when
        let period = self.period(2..<9)
        let events = container.scheduleEvents(in: period)
        
        // then
        let ids = events.map { $0.uuid }.sorted()
        XCTAssertEqual(ids, ["id:3", "id:4", "id:5", "id:6"])
    }
    
    // 특정 기간에 해당하는 이벤트 캐시 refresh
    func testContainer_refreshEventsGivenPeriod() {
        // given
        var container = self.makeContainer()
        container = container.append(self.notRepeatingEvent(1))
        container = container.append(self.repeatingEvent(3))
        container = container.append(self.notRepeatingEvent(4))
        container = container.append(self.repeatingEvent(5, end: 7))
        container = container.append(self.repeatingEvent(6, end: 100))
        
        // when
        let newEvents: [ScheduleEvent] = [
            self.notRepeatingEvent(2),
            self.repeatingEvent(5, end: 7),
            self.repeatingEvent(6),
            self.repeatingEvent(20)
        ]
        container = container.refresh(newEvents, in: self.period(2..<30))
        
        // then
        // 추가: 2 / 삭제:3, 4 / 유지: 5 / 업데이트: 6
        // 삭제될 이벤트 -> 3
        // 업데이트된 이벤트 -> 6(종료 시간 사라짐)
        var period = self.period(2..<9)
        var events = container.scheduleEvents(in: period)
        var ids = events.map { $0.uuid }.sorted()
        XCTAssertEqual(ids, ["id:2", "id:5", "id:6"])
        XCTAssertEqual(events.first(where: { $0.uuid == "id:6" })?.repeating?.repeatingEndTime, nil)
        
        // 추가된 이벤트 20
        period = self.period(19..<21)
        events = container.scheduleEvents(in: period)
        ids = events.map { $0.uuid }.sorted()
        XCTAssertEqual(ids, ["id:20", "id:6"])
        
        // 계속 보관중인 이벤트 -> 1
        period = self.period(0..<2)
        events = container.scheduleEvents(in: period)
        ids = events.map { $0.uuid }.sorted()
        XCTAssertEqual(ids, ["id:1"])
    }
    
    // append 할때 캐시된거에서 시간 or 반복옵션 업데이트 되었으면 다시 업데이트
    func testContainer_whenAppendScheduleEventAndNotChanged_keepHoldCache() {
        // given
        var container = self.makeContainer()
        let oldEvent = self.repeatingEvent(0)
        container = container.refresh([oldEvent], in: self.period(0..<3))   // 0, 1, 2, 3 게산된 상태
        
        // when
        let sameEventWithUpdateName = oldEvent |> \.name .~ "name updated"
        container = container.append(sameEventWithUpdateName)
        
        // then
        let event = container.scheduleEvents(in: self.period(0..<2)).first  // 캐시 유지됨
        XCTAssertEqual(event?.repeatingTimes.map { $0.day }, [0, 1, 2, 3])
        XCTAssertEqual(event?.repeatingTimes.map { $0.turn }, [1, 2, 3, 4])
    }
    
    func testContainer_whenAppendEventTimeUpdated_invalidCache() {
        // given
        var container = self.makeContainer()
        let oldEvent = self.repeatingEvent(0)
        container = container.refresh([oldEvent], in: self.period(0..<3))   // 0, 1, 2, 3 계산된 상태
        
        // when
        let newEvent = self.repeatingEvent(1, customId: "id:0")
        container = container.append(newEvent)
        
        // then
        let event = container.scheduleEvents(in: self.period(0..<3)).first // 캐시 초기화되고 1, 2, 3가 새로 계산됨
        
        XCTAssertEqual(event?.repeatingTimes.map { $0.day }, [1, 2, 3])
        XCTAssertEqual(event?.repeatingTimes.map { $0.turn}, [1, 2, 3])
    }
    
    func testContainer_whenAppendEventRepeatOptionUpdatedEvent_invalidCache() {
        // given
        var container = self.makeContainer()
        let oldEvent = self.repeatingEvent(0)
        container = container.refresh([oldEvent], in: self.period(0..<3))   // 0, 1, 2, 3 계산된 상태
        
        // when
        let newEvent = self.repeatingEvent(0, end: 2)
        container = container.append(newEvent)
        
        // then
        let event = container.scheduleEvents(in: self.period(0..<3)).first // 캐시 초기화되고 0, 1, 2가 새로 계산됨
        XCTAssertEqual(event?.repeatingTimes.map { $0.day }, [0, 1, 2])
        XCTAssertEqual(event?.repeatingTimes.map { $0.turn }, [1, 2, 3])
    }
}

extension MemorizedScheduleEventsContainerTests {
    
    // 캐시 없는 경우 새로 생성
    func testContainer_whenCacheNotExist_calcuatedGivenRange() {
        // given
        var container = self.makeContainer()
        container = container.append(self.repeatingEvent(0))
        
        // when
        let event = container.scheduleEvents(in: self.period(3..<5)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }   // 0..<5 범위가 새로 게산되어야함
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(0...5))
        XCTAssertEqual(turns, Array(1...6))
    }
    
    // 조회 기간이 전부 하나으 캐시 블럭에 포함되는 경우
    // c1.s___p.s___p.e___c1.e
    func testContainer_whenCacheExistAndContainGivenPeriod_returnCached() {
        // given
        var containr = self.makeContainer()
        containr = containr.refresh([self.repeatingEvent(0)], in: self.period(0..<10))  // 0~10 까지 계산되어있는 상황
        
        // when
        let event = containr.scheduleEvents(in: self.period(3..<6)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(0...10))
        XCTAssertEqual(turns, Array(1...11))
    }
    
    func testContainer_whenPeriodIsContainsCacheButEventEndTimeIsPriorToEnd_returnCachedUntilEndTime() {
        // given
        var container = self.makeContainer()
        container = container.refresh([self.repeatingEvent(0, end: 7)], in: self.period(0..<7))
        
        // when
        let event = container.scheduleEvents(in: self.period(3..<10)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(0...7))
        XCTAssertEqual(turns, Array(1...8))
    }
    
    // 조회 기간 중 시작시간이 캐싱된값에 포함되는 경우
    // c.s___p.s___c.e___p.e
    func testContainer_whenCacheExistsButPeriodIsMoreLonger_returnWithCachedAndNewCalulated() {
        // given
        var container = self.makeContainer()
        container = container.refresh([self.repeatingEvent(0)], in: self.period(0..<5)) // 0~5 까지만 계산한 상황
        
        // when
        let event = container.scheduleEvents(in: self.period(10..<15)).first // 0~5까지 캐시 이용하고 5~15까지 새로 계산
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(0...15))
        XCTAssertEqual(turns, Array(1...16))
    }
    
    func testContainer_whenCacheExistbutPeriodIsMoreLongerButEndTimeIsPriorToPeriodEnd_returnUntilEnd() {
        // given
        var container = self.makeContainer()
        container = container.refresh([self.repeatingEvent(0, end: 7)], in: self.period(0..<5))
        
        // when
        let event = container.scheduleEvents(in: self.period(6..<15)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(0...7))
        XCTAssertEqual(turns, Array(1...8))
    }
    
    // 조회 시작 시산이 캐싱된것보다 이전이고 종료는 캐시에 포함되는 경우
    // p.s___c.s___p.e___c.e
    func testContainer_whenPeriodIsPriorToCacheAndEndIsPriorToCacheEnd_returnCached() {
        // given
        var container = self.makeContainer()
        container = container.refresh([self.repeatingEvent(4)], in: self.period(4..<10)) // 4~10 캐시 계산됨
        
        // when
        let event = container.scheduleEvents(in: self.period(0..<7)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(4...10))
        XCTAssertEqual(turns, Array(1...7))
    }
    
    func testContainer_whenPeriodIsPriorToCacheAndEndIsPriorToCacheEndButEventEndTimeIsPrior_returnCached() {
        // given
        var container = self.makeContainer()
        container = container.refresh([self.repeatingEvent(4, end: 6)], in: self.period(4..<10)) // 4~10 캐시 계산됨
        
        // when
        let event = container.scheduleEvents(in: self.period(0..<7)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(4...6))
        XCTAssertEqual(turns, Array(1...3))
    }
    
    func testContainer_whenPeriodIsPriorToCacheAndEndIsLaterThanCaheEnd_retrunCahedAndCalculated() {
        // given
        var container = self.makeContainer()
        container = container.refresh([self.repeatingEvent(4)], in: self.period(4..<10))
        
        // when
        let event = container.scheduleEvents(in: self.period(0..<20)).first
        
        // then
        let days = event?.repeatingTimes.map { $0.day }
        let turns = event?.repeatingTimes.map { $0.turn }
        XCTAssertEqual(days, Array(4...20))
        XCTAssertEqual(turns, Array(1...17))
    }
}

private extension Int {
    
    var days: TimeInterval {
        return TimeInterval(self) * 3600 * 24
    }
}

private extension ScheduleEvent.RepeatingTimes {
    
    var day: Int {
        return (self.time.lowerBound / 24 / 3600) |> Int.init
    }
}
