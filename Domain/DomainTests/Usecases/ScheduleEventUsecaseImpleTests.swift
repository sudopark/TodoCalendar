//
//  ScheduleEventUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/01.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


final class ScheduleEventUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubScheduleEventRepository!
    private var spyStore: SharedDataStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
        self.spyStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
        self.spyStore = nil
    }
    
    private func makeUsecase() -> ScheduleEventUsecaseImple {
        let key = ShareDataKeys.schedules
        let events = self.dummyEvents(0..<10)
        self.spyStore.update(MemorizedScheduleEventsContainer.self, key: key.rawValue) {
            return ($0 ?? .init()).refresh(events, in: self.dummyRange)
        }
        return ScheduleEventUsecaseImple(
            scheduleRepository: self.stubRepository,
            sharedDataStore: self.spyStore
        )
    }
    
    private func stubMakeFail() {
        self.stubRepository.shouldFailMake = true
    }
    
    private func notReapeatingEvent(at day: Int) -> ScheduleEvent {
        let time = EventTime.at(.dummy(0).add(TimeInterval(day) * 24 * 3600))
        return .init(uuid: "id:\(day)", name: "name", time: time)
    }
    
    private func repeatingEvent(at day: Int) -> ScheduleEvent {
        let time = EventTime.at(.dummy(0).add(TimeInterval(day) * 24 * 3600))
        let repeating = EventRepeating(
            repeatingStartTime: time.lowerBoundTimeStamp,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        return .init(uuid: "id:\(day)", name: "name", time: time)
            |> \.repeating .~ repeating
    }
    
    private func stubEvents(_ events: [ScheduleEvent]) {
        self.stubRepository.eventsMocking = { _ in events }
    }
}

// MARK: - make case

extension ScheduleEventUsecaseImpleTests {
    
    // 생성
    func testUsecase_makeNewScheduleEvent() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.time .~ .at(.dummy())
            |> \.eventTagId .~ "some"
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertEqual(event?.name, "new")
        XCTAssertEqual(event?.eventTagId, "some")
    }
    
    // 생성 실패
    func testUsecase_makeNewScheduleEventFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubMakeFail()
        
        // when
        let params = ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ "some"
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertNil(event)
    }
    
    func testUsecase_whenMakeParamsIsNotValid_makeFail() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = ScheduleMakeParams()
            |> \.name .~ ""
            |> \.time .~ .at(.dummy())
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertNil(event)
    }
}


// MARK: - load case

extension ScheduleEventUsecaseImpleTests {
    
    private var dummyRange: Range<TimeStamp> {
        let oneDay: TimeInterval = 3600 * 24
        return TimeStamp.dummy(0)..<TimeStamp.dummy(0).add(20 * oneDay)
    }
    
    private func dummyEvents(_ range: Range<Int>) -> [ScheduleEvent] {
        return range.map {
            ScheduleEvent(uuid: "id:\($0)", name: "name:\($0)", time: .at(.dummy($0) ))
        }
    }
    
    private func stubNoMemorized() {
        self.spyStore.update(
            MemorizedScheduleEventsContainer.self,
            key: ShareDataKeys.schedules.rawValue
        ) { _ in .init() }
    }
    
    private func appendMemorized(_ event: ScheduleEvent) {
        self.spyStore.update(
            MemorizedScheduleEventsContainer.self,
            key: ShareDataKeys.schedules.rawValue
        ) { ($0 ?? .init()).append(event) }
    }
    
    func testUsecase_scheduleEventsInPeriod_withMemorized() {
        // given
        let expect = expectation(description: "캐시 있는 경우 range에 해당하는 이벤트 조회 및 refresh")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let source = usecase.scheduleEvents(in: self.dummyRange)
        let eventLits = self.waitOutputs(expect, for: source) {
            usecase.refreshScheduleEvents(in: self.dummyRange)
        }
        
        // then
        let idLists = eventLits.map { events in events.map { $0.uuid } |> Set.init }
        XCTAssertEqual(idLists, [
            (0..<10).map { "id:\($0)" } |> Set.init,
            (0..<20).map { "id:\($0)" } |> Set.init
        ])
    }
    
    func testUsecase_scheduleEventsInPeriod_withoutCache() {
        // given
        let expect = expectation(description: "캐시 없는 경우 range에 해당하는 이벤트 조회 및 refresh")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        self.stubNoMemorized()
        
        // when
        let source = usecase.scheduleEvents(in: self.dummyRange)
        let eventLists = self.waitOutputs(expect, for: source) {
            usecase.refreshScheduleEvents(in: self.dummyRange)
        }
        
        // then
        let idLists = eventLists.map { events in events.map { $0.uuid } |> Set.init }
        XCTAssertEqual(idLists, [
            [],
            (0..<20).map { "id:\($0)" } |> Set.init
        ])
    }
    
    func testUsecase_whenNewEventMadeInRange_update() {
        // given
        let expect = expectation(description: "range에 해당하는 이벤트 조회시에 새로 생성했으면 그거 반영해서 업데이트")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let source = usecase.scheduleEvents(in: self.dummyRange).filter { $0.isEmpty == false }
        let eventLists = self.waitOutputs(expect, for: source) {
            
            Task {
                let params = ScheduleMakeParams()
                    |> \.name .~ "new"
                    |> \.time .~ .at(.dummy(0).add(3))
                _ = try? await usecase.makeScheduleEvent(params)
            }
        }
        
        // then
        let idLists = eventLists.map { events in events.map { $0.uuid } |> Set.init }
        XCTAssertEqual(idLists, [
            (0..<10).map { "id:\($0)" } |> Set.init,
            ((0..<10).map { "id:\($0)" } |> Set.init) <> ["new"]
        ])
    }
    
    func testUsecase_whenObserveEventsInRangeAndEventIsRepeating_shouldBeCalculatedEventRepeaintTime() {
        // given
        let expect = expectation(description: "range에 해당하는 이벤트 조회시에 해당 기간 내 이벤트 반복시간들도 계산되어있어야함")
        let usecase = self.makeUsecase()
        self.stubNoMemorized()
        self.appendMemorized(self.repeatingEvent(at: 100))
        self.stubEvents([
            self.notReapeatingEvent(at: 13),
            self.repeatingEvent(at: 10),
        ])
        
        // when
        let source = usecase.scheduleEvents(in: self.dummyRange).filter { $0.isEmpty == false }
        let events = self.waitFirstOutput(expect, for: source) {
            usecase.refreshScheduleEvents(in: self.dummyRange)
        } ?? []
        
        // then
        XCTAssertEqual(events.count, 2)
        let notRepeatingEvent = events.first(where: { $0.uuid == "id:13" })
        let repeatingEvent = events.first(where: { $0.uuid == "id:10" })
        XCTAssertEqual(notRepeatingEvent?.repeatingTimes.count, 1)
        XCTAssertEqual(repeatingEvent?.repeatingTimes.count, 11)
    }
    
    func testUsecase_whenMakeNewRepeatingEventDuringObserving_update() {
        // given
        let expect = expectation(description: "새로 생성되어 append된 이벤트도 range로 조회시에 기간에 포함되면 반복시간 계산해서 반환해야함")
        let usecas = self.makeUsecase()
        self.stubNoMemorized()
        
        // when
        let source = usecas.scheduleEvents(in: self.dummyRange).filter { $0.isEmpty == false }
        let events = self.waitFirstOutput(expect, for: source) {
            
            Task.init {
                let params = ScheduleMakeParams()
                    |> \.name .~ "new"
                    |> \.time .~ .at(.dummy(0).add(3))
                |> \.repeating .~ .init(
                    repeatingStartTime: .dummy(0).add(3),
                    repeatOption: EventRepeatingOptions.EveryDay()
                )
                _ = try? await usecas.makeScheduleEvent(params)
            }
        }
        
        // then
        let event = events?.first(where: { $0.uuid == "new" })
        XCTAssertEqual(event?.repeatingTimes.count, 20)
    }
    
    func testUsecase_whenMakeNewRepeatingEventDuringObservingButRangeNotOverlap_notUpdate() {
        // given
        let expect = expectation(description: "새로 생성되어 append된 이벤트도 range로 조회시에 기간에 포함 안되면 이벤트 발생 안함")
        expect.isInverted = true
        let usecas = self.makeUsecase()
        self.stubNoMemorized()
        
        // when
        let source = usecas.scheduleEvents(in: self.dummyRange).filter { $0.isEmpty == false }
        let events = self.waitFirstOutput(expect, for: source) {
            
            Task.init {
                let paramsRangeOver = ScheduleMakeParams()
                    |> \.name .~ "over"
                    |> \.time .~ .at(.dummy(0).add(24 * 3600 * 100))
                    |> \.repeating .~ .init(
                        repeatingStartTime: .dummy(0).add(24 * 3600 * 100),
                        repeatOption: EventRepeatingOptions.EveryDay()
                    )
                _ = try? await usecas.makeScheduleEvent(paramsRangeOver)
            }
        }
        
        // then
        XCTAssertNil(events)
    }
}
