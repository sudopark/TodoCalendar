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
import TestDoubles

@testable import Domain


final class ScheduleEventUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubScheduleEventRepository!
    private var spyStore: SharedDataStore!
    private var spyEventNotifyService: SharedEventNotifyService!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
        self.spyStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
        self.spyStore = nil
        self.spyEventNotifyService = nil
    }
    
    private func makeUsecase() -> ScheduleEventUsecaseImple {
        let key = ShareDataKeys.schedules
        let events = self.dummyEvents(0..<10)
        self.spyStore.update(MemorizedScheduleEventsContainer.self, key: key.rawValue) {
            return ($0 ?? .init()).refresh(events, in: self.dummyRange())
        }
        self.spyEventNotifyService = .init(notifyQueue: nil)
        return ScheduleEventUsecaseImple(
            scheduleRepository: self.stubRepository,
            sharedDataStore: self.spyStore,
            eventNotifyService: self.spyEventNotifyService
        )
    }
    
    private func stubMakeFail() {
        self.stubRepository.shouldFailMake = true
    }
    
    private func notReapeatingEvent(at day: Int) -> ScheduleEvent {
        let time = EventTime.at(TimeInterval(day) * 24 * 3600)
        return .init(uuid: "id:\(day)", name: "name", time: time)
    }
    
    private func repeatingEvent(at day: Int) -> ScheduleEvent {
        let time = EventTime.at(TimeInterval(day) * 24 * 3600)
        let repeating = EventRepeating(
            repeatingStartTime: time.lowerBoundWithFixed,
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
            |> \.time .~ .at(0)
            |> \.eventTagId .~ .custom("some")
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertEqual(event?.name, "new")
        XCTAssertEqual(event?.eventTagId, .custom("some"))
    }
    
    // 생성 실패
    func testUsecase_makeNewScheduleEventFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubMakeFail()
        
        // when
        let params = ScheduleMakeParams()
            |> \.name .~ "new"
            |> \.eventTagId .~ .custom("some")
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
            |> \.time .~ .at(0)
        let event = try? await usecase.makeScheduleEvent(params)
        
        // then
        XCTAssertNil(event)
    }
}


// MARK: - load case

extension ScheduleEventUsecaseImpleTests {
    
    private func dummyRange(_ range: Range<Int> = 0..<20) -> Range<TimeInterval> {
        let oneDay: TimeInterval = 3600 * 24
        return TimeInterval(range.lowerBound)*oneDay..<TimeInterval(range.upperBound)*oneDay
    }
    
    private func dummyEvents(_ range: Range<Int>) -> [ScheduleEvent] {
        return range.map {
            ScheduleEvent(uuid: "id:\($0)", name: "name:\($0)", time: .at( TimeInterval($0) ))
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
    
    private func replaceMemorized(_ events: [ScheduleEvent]) {
        var container = MemorizedScheduleEventsContainer()
        events.forEach {
            container = container.append($0)
        }
        self.spyStore.update(
            MemorizedScheduleEventsContainer.self,
            key: ShareDataKeys.schedules.rawValue) { _ in container }
        
    }
    
    func testUsecase_scheduleEventsInPeriod_withMemorized() {
        // given
        let expect = expectation(description: "캐시 있는 경우 range에 해당하는 이벤트 조회 및 refresh")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let source = usecase.scheduleEvents(in: self.dummyRange())
        let eventLits = self.waitOutputs(expect, for: source, timeout: 1) {
            usecase.refreshScheduleEvents(in: self.dummyRange())
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
        let source = usecase.scheduleEvents(in: self.dummyRange())
        let eventLists = self.waitOutputs(expect, for: source, timeout: 1) {
            usecase.refreshScheduleEvents(in: self.dummyRange())
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
        let source = usecase.scheduleEvents(in: self.dummyRange()).filter { $0.isEmpty == false }
        let eventLists = self.waitOutputs(expect, for: source, timeout: 0.1) {
            
            Task {
                let params = ScheduleMakeParams()
                    |> \.name .~ "new"
                    |> \.time .~ .at(0+3)
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
        let source = usecase.scheduleEvents(in: self.dummyRange()).filter { $0.isEmpty == false }
        let events = self.waitFirstOutput(expect, for: source, timeout: 1) {
            usecase.refreshScheduleEvents(in: self.dummyRange())
        } ?? []
        
        // then
        XCTAssertEqual(events.count, 2)
        let notRepeatingEvent = events.first(where: { $0.uuid == "id:13" })
        let repeatingEvent = events.first(where: { $0.uuid == "id:10" })
        XCTAssertEqual(notRepeatingEvent?.repeatingTimes.count, 1)
        XCTAssertEqual(repeatingEvent?.repeatingTimes.count, 11)
    }
    
    func testUsecase_whenRefreshSchedules_notify() {
        // given
        func parameterizeTest(stubShouldLoadFail: Bool = false) {
            // given
            self.stubRepository.shouldFailLoad = stubShouldLoadFail
            let expect = expectation(description: "refresh 중임을 알림")
            expect.expectedFulfillmentCount = 2
            let usecase = self.makeUsecase()
            
            // when
            let refreshingEvent: AnyPublisher<RefreshingEvent, Never> = self.spyEventNotifyService.event()
            let isRefreshings = self.waitOutputs(expect, for: refreshingEvent) {
                usecase.refreshScheduleEvents(in: self.dummyRange())
            }
            
            // then
            XCTAssertEqual(isRefreshings, [
                RefreshingEvent.refreshingSchedule(true),
                RefreshingEvent.refreshingSchedule(false)
            ])
        }
        // when + then
        parameterizeTest()
        parameterizeTest(stubShouldLoadFail: true)
    }
    
    func testUsecase_whenMakeNewRepeatingEventDuringObserving_update() {
        // given
        let expect = expectation(description: "새로 생성되어 append된 이벤트도 range로 조회시에 기간에 포함되면 반복시간 계산해서 반환해야함")
        let usecas = self.makeUsecase()
        self.stubNoMemorized()
        
        // when
        let source = usecas.scheduleEvents(in: self.dummyRange()).filter { $0.isEmpty == false }
        let events = self.waitFirstOutput(expect, for: source, timeout: 0.1) {
            
            Task.init {
                let params = ScheduleMakeParams()
                    |> \.name .~ "new"
                    |> \.time .~ .at(3.0)
                    |> \.repeating .~ .init(
                        repeatingStartTime: 3.0,
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
        let source = usecas.scheduleEvents(in: self.dummyRange()).filter { $0.isEmpty == false }
        let events = self.waitFirstOutput(expect, for: source, timeout: 0.1) {
            
            let startTime: TimeInterval = 24.0 * 3600 * 100
            let option = EventRepeatingOptions.EveryDay()
            let repeating = EventRepeating(repeatingStartTime: startTime, repeatOption: option)
            Task.init {
                let paramsRangeOver = ScheduleMakeParams()
                    |> \.name .~ "over"
                    |> \.time .~ .at(startTime)
                    |> \.repeating .~ pure(repeating)
                _ = try? await usecas.makeScheduleEvent(paramsRangeOver)
            }
        }
        
        // then
        XCTAssertNil(events)
    }
}


// MARK: - edit case

extension ScheduleEventUsecaseImpleTests {
    
    // 반복하지 않는 일정을 수정하는 경우 - 파라미터 불충분하면 실패
    func testUsecase_whenUpdateNotRepeatingEventWithInvalidParams_updateFail() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.notReapeatingEvent(at: 0)
        
        // when
        let params = SchedulePutParams()
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertNil(updated)
    }
    
    // 반복하지 않는 일정을 수정
    func testUsecase_updateNotRepeatingEvent() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.notReapeatingEvent(at: 0)
        
        // when
        let params = SchedulePutParams()
            |> \.name .~ "new"
            |> \.time .~ .at(100)
            |> \.repeatingTimeToExcludes .~ []
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertEqual(updated?.name, "new")
    }
    
    private struct Pair: Equatable { let uuid: String; let time: EventTime? }
    
    func testUsecase_whenNotRepeatingEvent_updateSubscribingEventRange() {
        // given
        let expect = expectation(description: "반복하지 않는 일정 수정 이후에 업데이트된 결과 구독중인 이벤트에 반영")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let old = self.notReapeatingEvent(at: 0)
        self.replaceMemorized([old])
        
        // when
        let source = usecase.scheduleEvents(in: 0..<100)
        let eventLists = self.waitOutputs(expect, for: source, timeout: 0.1) {
            Task {
                let params = SchedulePutParams()
                    |> \.name .~ old.name
                    |> \.time .~ pure(EventTime.at(4))
                    |> \.repeatingTimeToExcludes .~ []
                _ = try await usecase.updateScheduleEvent(old.uuid, params)
            }
        }
        
        // then
        let idAndTimeParis = eventLists
            .map { evs in evs.map { Pair(uuid: $0.uuid, time: $0.time) } }
        XCTAssertEqual(idAndTimeParis, [
            [.init(uuid: old.uuid, time: EventTime.at(0))],
            [.init(uuid: old.uuid, time: EventTime.at(4))]
        ])
    }
    
    private func stubUpdateRepeatingEvent() -> ScheduleEvent {
        let event = self.repeatingEvent(at: 0)
        self.stubRepository.updateOriginEventMocking = event
        return event
    }
    
    // 반복하는 일정 + 전체 반복일정 수정시에 - 파라민터가 불충분하면 실패
    func testUsecase_whenUpdateRepeatingEventWithInvalidParams_updateFail() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.stubUpdateRepeatingEvent()
        
        // when
        let params = SchedulePutParams()
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertNil(updated)
    }
    
    // 반복하는 일정 + 전체 반복일정 수정 -> 업데이트된 새 반복일정 내려옴
    func testUsecase_updateRepeatingEventWithAll() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.stubUpdateRepeatingEvent()
        
        // when
        let params = SchedulePutParams()
            |> \.name .~ event.name
            |> \.time .~ pure(EventTime.at(4))
            |> \.repeatingUpdateScope .~ .all
            |> \.repeatingTimeToExcludes .~ []
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertEqual(updated?.time, EventTime.at(4))
    }
    
    // 반복하는 일정 + 전체 반복일정 수정 이후에 업데이트됨 + 반복시간 다시 계산해서 구독중인 이벤트 발생
    func testUsecase_whenAllRepeatingEventUpdated_updateSubscribingEventRangeWithRefreshingRepeatTimes() {
        // given
        let expect = expectation(description: "반복하는 일정 + 전체 반복일정 수정 이후에 업데이트됨 + 반복시간 다시 계산해서 구독중인 이벤트 발생")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let old = self.stubUpdateRepeatingEvent()
        self.replaceMemorized([old])
        
        // when
        let source = usecase.scheduleEvents(
            in: self.dummyRange(0..<3)
        )
        let eventLists = self.waitOutputs(expect, for: source) {
            Task {
                let params = SchedulePutParams()
                    |> \.name .~ old.name
                    |> \.time .~ pure(EventTime.at(4.0))
                    |> \.repeatingUpdateScope .~ .all
                    |> \.repeatingTimeToExcludes .~ []
                _ = try await usecase.updateScheduleEvent(old.uuid, params)
            }
        }
        
        // then
        let eventCounts = eventLists.map { $0.count }
        XCTAssertEqual(eventCounts, [1, 1])
        let events = eventLists.compactMap { $0.first(where: { $0.uuid == old.uuid } )}
        let eventTimes = events.map { $0.time }
        XCTAssertEqual(eventTimes, [
            EventTime.at(0.0), EventTime.at(4.0)
        ])
        let eventRepeatingTimes = events.map { $0.repeatingTimes.map { $0.time } }
        XCTAssertEqual(eventRepeatingTimes, [
            [
                EventTime.at(0), EventTime.at(24*3600),
                EventTime.at(2*24*3600), EventTime.at(3*24*3600)
            ],
            [
                EventTime.at(4), EventTime.at(4+24*3600), EventTime.at(4+2*24*3600)
            ]
        ])
    }
    
    // 반복하는 일정 + 이번만 수정시에 - 파라미터가 불충분하면 실패
    func testUsecase_whenUpdateRepeatingEventOnlyThisTimeWithInvalidParams_updateFail() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.stubUpdateRepeatingEvent()
        
        // when
        let params = SchedulePutParams()
            |> \.time .~ .at(4)
            |> \.repeatingUpdateScope .~ .onlyThisTime(EventTime.at(0))
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertNil(updated)
    }
    
    // 반복하는 일정 + 이번만 수정시 제외된 새 일정 반환
    func testUsecase_updateRepeatingEventOnlyThisTime() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.stubUpdateRepeatingEvent()
        
        // when
        let params = SchedulePutParams()
            |> \.name .~ event.name
            |> \.time .~ .at(4)
            |> \.repeatingUpdateScope .~ .onlyThisTime(EventTime.at(0))
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertEqual(updated?.time, EventTime.at(4))
    }
    
    // 반복하는 일정 + 이번만 수정시에 새 일정이 구독중인 이벤트로 반환되고, 기존 일정은 반복시간이 제외해서 다시 계산해서 반환
    func testUsecase_whenRepeatingEventOnlyThisTimeUpdated_updateSubscribingPeriodEvents() {
        // given
        let expect = expectation(description: "반복하는 일정 + 이번만 수정시에 새 일정이 구독중인 이벤트로 반환되고, 기존 일정은 반복시간이 제외해서 다시 계산해서 반환")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let old = self.stubUpdateRepeatingEvent()
        self.replaceMemorized([old])
        
        // when
        let range = self.dummyRange(0..<3)
        let source = usecase.scheduleEvents(in: range)
        let eventLists = self.waitOutputs(expect, for: source, timeout: 0.1) {
            Task {
                let params = SchedulePutParams()
                    |> \.name .~ old.name
                    |> \.time .~ .at(4)
                    |> \.repeatingUpdateScope .~ .onlyThisTime(EventTime.at(2*24*3600))
                _ = try await usecase.updateScheduleEvent(old.uuid, params)
            }
        }
        
        // then
        let eventCounts = eventLists.map { $0.count }
        XCTAssertEqual(eventCounts, [1, 2])
        let eventNames = eventLists.map { es in es.map { $0.name }}
        XCTAssertEqual(eventNames, [
            [old.name],
            [old.name, old.name]
        ])
        let memorizedOriginEvent = eventLists.first?.first(where: { $0.uuid == old.uuid })
        XCTAssertEqual(memorizedOriginEvent?.repeatingTimes.map { $0.time }, [
            EventTime.at(0), EventTime.at(1*24*3600), EventTime.at(2*24*3600), EventTime.at(3*24*3600)
        ])
        XCTAssertEqual(memorizedOriginEvent?.repeatingTimes.map { $0.turn }, [
            1, 2, 3, 4
        ])
        let updatedOriginEvent = eventLists.last?.first(where: { $0.uuid == old.uuid })
        XCTAssertEqual(updatedOriginEvent?.repeatingTimes.map { $0.time }, [
            EventTime.at(0), EventTime.at(1*24*3600), EventTime.at(3*24*3600)
        ])
        XCTAssertEqual(updatedOriginEvent?.repeatingTimes.map { $0.turn }, [
            1, 2, 3
        ])
        let newEvent = eventLists.last?.first(where: { $0.uuid == "new" })
        XCTAssertEqual(newEvent?.time, EventTime.at(4))
    }
    
    // 반복하는 일정 + 이번부터 수정시에 - 파라미터가 불충분하면 실패
    func testUsecase_whenUpdateRepeatingEventFromNowWithInvalidParams_updateFail() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.stubUpdateRepeatingEvent()
        
        // when
        let params = SchedulePutParams()
            |> \.time .~ .at(4)
            |> \.repeatingUpdateScope .~ .fromNow(EventTime.at(0))
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertNil(updated)
    }
    
    // 반복하는 일정 + 이번부터 수정시 분기된 새 반복 일정 반환
    func testUsecase_updateRepeatingEventFromNow() async {
        // given
        let usecase = self.makeUsecase()
        let event = self.stubUpdateRepeatingEvent()
        
        // when
        let params = SchedulePutParams()
            |> \.name .~ event.name
            |> \.time .~ .at(4)
            |> \.repeatingUpdateScope .~ .fromNow(EventTime.at(0))
        let updated = try? await usecase.updateScheduleEvent(event.uuid, params)
        
        // then
        XCTAssertEqual(updated?.time, EventTime.at(4))
    }
    
    // 반복하는 일정 + 이번부터 수정시에 새 일정이 구독중인 이벤트로 반환되고, 기존 일정은 반복 종료되어 다시 계산해서 반환
    func testUsecase_whenRepeatingEventFromNowUpdated_updateSubscribingPeriodEvents() {
        // given
        let expect = expectation(description: "반복하는 일정 + 이번부터 수정시에 새 일정이 구독중인 이벤트로 반환되고, 기존 일정은 반복 종료되어 다시 계산해서 반환")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        let old = self.stubUpdateRepeatingEvent()
        self.replaceMemorized([old])
        
        // when
        let range = self.dummyRange(0..<3)
        let source = usecase.scheduleEvents(in: range)
        let eventLists = self.waitOutputs(expect, for: source, timeout: 0.1) {
            Task {
                let newTime: EventTime = .at(1*24*3600)
                let repeating = EventRepeating(
                    repeatingStartTime: newTime.lowerBoundWithFixed,
                    repeatOption: EventRepeatingOptions.EveryDay()
                )
                let params = SchedulePutParams()
                    |> \.name .~ old.name
                    |> \.time .~ pure(newTime)
                    |> \.repeating .~ pure(repeating)
                    |> \.repeatingUpdateScope .~ .fromNow(newTime)
                _ = try await usecase.updateScheduleEvent(old.uuid, params)
            }
        }
        
        // then
        let eventCounts = eventLists.map { $0.count }
        XCTAssertEqual(eventCounts, [1, 2])
        let eventNames = eventLists.map { es in es.map { $0.name }}
        XCTAssertEqual(eventNames, [
            [old.name],
            [old.name, old.name]
        ])
        let memorizedOriginEvent = eventLists.first?.first(where: { $0.uuid == old.uuid })
        XCTAssertEqual(memorizedOriginEvent?.repeatingTimes.map { $0.time }, [
            EventTime.at(0), EventTime.at(1*24*3600), EventTime.at(2*24*3600), EventTime.at(3*24*3600)
        ])
        XCTAssertEqual(memorizedOriginEvent?.repeatingTimes.map { $0.turn }, [
            1, 2, 3, 4
        ])
        let updatedOriginEvent = eventLists.last?.first(where: { $0.uuid == old.uuid })
        XCTAssertEqual(updatedOriginEvent?.repeatingTimes.map { $0.time }, [
            EventTime.at(0)
        ])
        XCTAssertEqual(updatedOriginEvent?.repeatingTimes.map { $0.turn }, [
            1
        ])
        let newEvent = eventLists.last?.first(where: { $0.uuid == "new" })
        XCTAssertEqual(newEvent?.time, EventTime.at(1*24*3600))
        XCTAssertEqual(newEvent?.repeatingTimes.map { $0.time }, [
            EventTime.at(1*24*3600), EventTime.at(2*24*3600), EventTime.at(3*24*3600)
        ])
    }
    
    private func stubScheduleEvent() {
        self.stubRepository.stubEvent = .init(uuid: "some", name: "name", time: .at(1))
    }
    
    func testUsecase_loadScheduleById() {
        // given
        let expect = expectation(description: "id로 이벤트 조회")
        let usecase = self.makeUsecase()
        self.stubScheduleEvent()
        
        // when
        let event = self.waitFirstOutput(expect, for: usecase.scheduleEvent("some"))
        
        // then
        XCTAssertNotNil(event)
    }
    
    func testUsecase_whenLoadSchedule_updateStore() {
        // given
        let expect = expectation(description: "id로 이벤트 조회 이후에 공유데이터 업데이트")
        let usecase = self.makeUsecase()
        self.stubScheduleEvent()
        
        // when
        let source = self.spyStore.observe(MemorizedScheduleEventsContainer.self, key: ShareDataKeys.schedules.rawValue)
            .compactMap { $0?.scheduleEvents(in: 0..<10) }
            .compactMap { $0.first(where: { $0.uuid == "some"} )}
        let event = self.waitFirstOutput(expect, for: source) {
            usecase.scheduleEvent("some")
                .sink(receiveValue: { _ in })
                .store(in: &self.cancelBag)
        }
        
        // then
        XCTAssertNotNil(event)
    }
}


// MARK: - remove case

extension ScheduleEventUsecaseImpleTests {
    
    func testUsecase_removeSchedule() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when + then
        try await usecase.removeScheduleEvent("will_removing_todo", onlyThisTime: nil)
    }
    
    private func makeUsecaseWithStubWillRemovingSchedule(
        nextEventExists: Bool
    ) -> ScheduleEventUsecaseImple {
        let usecase = self.makeUsecase()
        self.stubRepository.stubRemoveScheduleNextRepeatingExists = nextEventExists
        let schedule = ScheduleEvent(uuid: "will_removing_todo", name: "old", time: .at(0))
        self.spyStore.update(MemorizedScheduleEventsContainer.self, key: ShareDataKeys.schedules.rawValue) {
            ($0 ?? .init()).append(schedule)
        }
        return usecase
    }
    
    private var willRemovingScheduleAtStore: AnyPublisher<ScheduleEvent?, Never> {
        return self.spyStore
            .observe(MemorizedScheduleEventsContainer.self, key: ShareDataKeys.schedules.rawValue)
            .map { $0?.scheduleEvents(in: 0..<10) }
            .map { $0?.first(where: { $0.uuid == "will_removing_todo" })}
            .eraseToAnyPublisher()
    }
    
    func testUsecase_whenRemoveSchedule_removeFromShared() {
        // given
        let expect = expectation(description: "schedule 삭제 이후 공유 스토어에서 삭제")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubWillRemovingSchedule(nextEventExists: false)
        
        // when
        let schedules = self.waitOutputs(expect, for: self.willRemovingScheduleAtStore) {
            Task {
                try? await usecase.removeScheduleEvent("will_removing_todo", onlyThisTime: nil)
            }
        }
        
        // then
        let isNils = schedules.map { $0 == nil }
        XCTAssertEqual(isNils, [false, true])
    }
    
    func testUsecase_whenRemoveScheduleAndNextRepeatingExists_provideSharedAsNextEvent() {
        // given
        let expect = expectation(description: "반복이벤트 중 이번만 삭제하는 경우 다음이벤트로 대체")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubWillRemovingSchedule(nextEventExists: true)
        
        // when
        let schedules = self.waitOutputs(expect, for: self.willRemovingScheduleAtStore) {
            Task {
                try? await usecase.removeScheduleEvent("will_removing_todo", onlyThisTime: .at(0))
            }
        }
        
        // then
        let names = schedules.map { $0?.name }
        XCTAssertEqual(names, ["old", "next"])
    }
    
    func testUsecase_whenRemoveScheduleAndNextRepeatingNotExists_provideSharedAsNextEvent() {
        // given
        let expect = expectation(description: "반복이벤트 중 이번만 삭제하는 경우 다음이벤트로 대체해야하지만 없으면 nil")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubWillRemovingSchedule(nextEventExists: false)
        
        // when
        let schedules = self.waitOutputs(expect, for: self.willRemovingScheduleAtStore) {
            Task {
                try? await usecase.removeScheduleEvent("will_removing_todo", onlyThisTime: .at(0))
            }
        }
        
        // then
        let isNils = schedules.map { $0 == nil }
        XCTAssertEqual(isNils, [false, true])
    }
    
    private func makeUsecaseWithStubRemoveEventWithTag() -> ScheduleEventUsecaseImple {
        let sc1 = ScheduleEvent(uuid: "sc1", name: "sc1", time: .at(100))
        let sc4 = ScheduleEvent(uuid: "sc4", name: "sc4", time: .at(101))
        let sc3 = ScheduleEvent(uuid: "sc3", name: "sc3", time: .at(102))
        let usecase = self.makeUsecase()
        self.stubNoMemorized()
        self.replaceMemorized([sc1, sc4, sc3])
        return usecase
    }
    
    func testUsecase_whenHandleRemoveSchedules_updateList() {
        // given
        let expect = expectation(description: "삭제된 이벤트 처리시에 공유중인 리스트에서 제거")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithStubRemoveEventWithTag()
        
        // when
        let source = usecase.scheduleEvents(in: 0..<200)
        let eventLists = self.waitOutputs(expect, for: source) {
            
            usecase.handleRemovedSchedules(["sc1", "sc3"])
        }
        
        // then
        let idLists = eventLists.map { es in es.map { $0.uuid }.sorted() }
        XCTAssertEqual(idLists, [
            ["sc1", "sc3", "sc4"],
            ["sc4"]
        ])
    }
}


// MARK: - repeat all day event case

extension ScheduleEventUsecaseImpleTests {
    
    // kst에서 allday로 2023년 7월 24일 ~ 26일까지 지정했음 (GMT + 9) 매 주 반복됨
    // pdt 7월 30~ 8월 5 조회시에 걸려야함
    // t+14 7월 30~ 8월 5 조회시에 걸려야함
    // t-12 7월 30~ 8월 5 조회시에 걸려야함
    
    private func makeUsecaseWithRepeatingPerWeekAndAllDayScheduleEvent() -> ScheduleEventUsecaseImple {
        let usecase = self.makeUsecase()
        
        let kstTimeZone = TimeZone(abbreviation: "KST")!
        let range = try! TimeInterval.range(
            from: "2023-07-24 00:00:00",
            to: "2023-07-26 23:59:59",
            in: kstTimeZone
        )
        let option = EventRepeatingOptions.EveryWeek(kstTimeZone)
            |> \.interval .~ 1
            |> \.dayOfWeeks .~ [.monday]
        let repeating = EventRepeating(repeatingStartTime: range.lowerBound, repeatOption: option)
        let event = ScheduleEvent(
            uuid: "all-day", name: "allday-event",
            time: .allDay(range, secondsFromGMT: kstTimeZone.secondsFromGMT() |> TimeInterval.init)
        )
        |> \.repeating .~ repeating
        
        self.stubEvents([event])
        self.stubNoMemorized()
        return usecase
    }
    
    func testUsecase_provideRepeatingEventWithAllday_otherTimeZones() {
        // given
        let kstTimeZone = TimeZone(abbreviation: "KST")!
        let kstFirstRange = try! TimeInterval.range(
            from: "2023-07-24 00:00:00",
            to: "2023-07-26 23:59:59",
            in: kstTimeZone
        )
        let kstSecondRange = try! TimeInterval.range(
            from: "2023-07-31 00:00:00",
            to: "2023-08-02 23:59:59",
            in: kstTimeZone
        )
        
        func parameterizeTests(_ timeZone: TimeZone) {
            // given
            let expect = expectation(description: "kst timezone에서 저장된 allday 2023.07.24~07.26 이벤트를 다른 timezone의 다음주 기간 에서도 조회할 수 있어야함")
            expect.assertForOverFulfill = false
            try! self.setUpWithError()
            let usecase = self.makeUsecaseWithRepeatingPerWeekAndAllDayScheduleEvent()
            
            // when
            let range = try! TimeInterval.range(
                from: "2023-07-30 00:00:00",
                to: "2023-08-05 23:59:59",
                in: timeZone
            )
            let events = self.waitFirstOutput(expect, for: usecase.scheduleEvents(in: range).drop(while: { $0.isEmpty }), timeout: 0.1) {
                usecase.refreshScheduleEvents(in: range)
            }
            
            // then
            XCTAssertEqual(events?.count, 1)
            let allDayEvent = events?.first(where: { $0.uuid == "all-day" })
            let kstTimeZone = TimeZone(abbreviation: "KST")!
            let secondsFromGMT = kstTimeZone.secondsFromGMT() |> TimeInterval.init
            XCTAssertEqual(allDayEvent?.time, .allDay(kstFirstRange, secondsFromGMT: secondsFromGMT))
            XCTAssertEqual(allDayEvent?.repeatingTimes, [
                .init(time: .allDay(kstFirstRange, secondsFromGMT: secondsFromGMT), turn: 1),
                .init(time: .allDay(kstSecondRange, secondsFromGMT: secondsFromGMT), turn: 2),
            ])
            try! self.tearDownWithError()
        }
        
        // when
        let timeZones: [TimeZone] = [
            .init(abbreviation: "UTC")!, .init(abbreviation: "KST")!, .init(abbreviation: "PDT")!,
            .init(secondsFromGMT: 14 * 3600)!, .init(secondsFromGMT: -12 * 3600)!
        ]
        
        // then
        timeZones.forEach {
            parameterizeTests($0)
        }
    }
}
