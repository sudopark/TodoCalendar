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
    
    private func period(_ range: Range<Int>) -> Range<TimeStamp> {
        return TimeStamp(range.lowerBound.days, timeZone: "KST")
            ..<
        TimeStamp(range.upperBound.days, timeZone: "KST")
    }
    
    private func notRepeatingEvent(_ int: Int) -> ScheduleEvent {
        return ScheduleEvent(
            uuid: "id:\(int)",
            name: "some",
            time: .at(TimeStamp(int.days, timeZone: "KST"))
        )
    }
    
    private func repeatingEvent(_ int: Int, customId: String? = nil, end: Int? = nil) -> ScheduleEvent {
        let time = TimeStamp(int.days, timeZone: "KST")
        let repeating = EventRepeating(repeatingStartTime: time, repeatOption: EventRepeatingOptions.EveryDay())
            |> \.repeatingEndTime .~ end.map { TimeStamp($0.days, timeZone: "KST") }
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
        container = container.refresh([oldEvent], in: self.period(0..<3))   // 0, 1, 2 게산된 상태
        
        // when
        let sameEventWithUpdateName = oldEvent |> \.name .~ "name updated"
        container = container.append(sameEventWithUpdateName)
        
        // then
        let event = container.scheduleEvents(in: self.period(0..<2)).first  // 캐시없으면 0, 1 새로 계산됨
        XCTAssertEqual(event?.repeatingTimes.count, 3)
    }
    
    func testContainer_whenAppendEventTimeUpdated_invalidCache() {
        // given
        var container = self.makeContainer()
        let oldEvent = self.repeatingEvent(0)
        container = container.refresh([oldEvent], in: self.period(0..<3))   // 0, 1, 2 계산된 상태
        
        // when
        let newEvent = self.repeatingEvent(1, customId: "id:0")
        container = container.append(newEvent)
        
        // then
        let event = container.scheduleEvents(in: self.period(0..<3)).first // 캐시 초기화되고 1, 2가 새로 계산됨
        XCTAssertEqual(event?.repeatingTimes.count, 2)
    }
    
    func testContainer_whenAppendEventRepeatOptionUpdatedEvent_invalidCache() {
        // given
        var container = self.makeContainer()
        let oldEvent = self.repeatingEvent(0)
        container = container.refresh([oldEvent], in: self.period(0..<3))   // 0, 1, 2 계산된 상태
        
        // when
        let newEvent = self.repeatingEvent(0, end: 2)
        container = container.append(newEvent)
        
        // then
        let event = container.scheduleEvents(in: self.period(0..<3)).first // 캐시 초기화되고 0, 1가 새로 계산됨
        XCTAssertEqual(event?.repeatingTimes.count, 2)
    }
}

extension MemorizedScheduleEventsContainerTests {
    
    // 캐시 없는 경우 새로 생성
    
    // 조회 기간이 전부 하나으 캐시 블럭에 포함되는 경우
    // c1.s___p.s___p.e___c1.e    c2.s___c2.e
    
    // 조회 기간 중 시작시간이 캐싱된값에 포함되는 경우
    // c.s___p.s___c.e___p.e    c2.s___c2.e
    
    // 조회 기간 중 시작시간이 캐시1에 포함되고 종료 시간이 캐시2에 포함되는 경우
    // c1.s___p.s___c1.e___c2.s___p.e___c2.e    c3.s___c3.e
    
    // 조회 기간 중 시작시간이 캐시1에 포함되고 종료 시간이 캐시2보다 큰 경우
    // c1.s___p.s___c1.e___c2.s___c2.e___p.e    c3.s___c3.e
    
    
}

private extension Int {
    
    var days: TimeInterval {
        return TimeInterval(self) * 3600 * 24
    }
}
