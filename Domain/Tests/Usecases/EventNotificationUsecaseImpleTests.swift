//
//  EventNotificationUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 1/16/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class EventNotificationUsecaseImpleTests: BaseTestCase {
    
    private var stubCalednarSettingUsecase: StubCalendarSettingUsecase!
    private var stubTodoUsecase: PrivateStubTodoEventUsecase!
    private var stubScheduleUsecase: PrivateStubScheduleEventUsecase!
    private var spyNotificationRepository: SpyEventNotificationRepository!
    private var spyNotificationService: StubLocalNotificationService!
    
    override func setUpWithError() throws {
        self.stubCalednarSettingUsecase = .init()
        self.stubTodoUsecase = .init()
        self.stubScheduleUsecase = .init()
        self.spyNotificationRepository = .init()
        self.spyNotificationService = .init()
    }
    
    override func tearDownWithError() throws {
        self.stubCalednarSettingUsecase = nil
        self.stubTodoUsecase = nil
        self.stubScheduleUsecase = nil
        self.spyNotificationRepository = nil
        self.spyNotificationService = nil
    }
    
    private func makeUsecase() -> EventNotificationUsecaseImple {
        
        self.stubCalednarSettingUsecase.prepare()
        
        self.stubTodoUsecase.makeTodoChangeInPeriodEvent([
            pastTodo, todoWithoutTime, futureTodoEvent1, futureTodoEvent2
        ])
        
        return .init(
            calendarSettingUsecase: self.stubCalednarSettingUsecase,
            todoEventUsecase: self.stubTodoUsecase,
            scheduleEventUescase: self.stubScheduleUsecase,
            notificationRepository: self.spyNotificationRepository,
            notificationService: self.spyNotificationService
        )
    }
}


extension EventNotificationUsecaseImpleTests {
    
    // 현재 시간부터 1년 단위로 날짜 있는 미래 todo 알림 등록
    func testUsecase_whenRunSyncNotifications_scheduleTodoEventNotificationsFromNowToNextYear() {
        // given
        let expect = expectation(description: "현재 시간부터 1년 단위로 날짜 있는 미래 todo 알림 등록")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        var scheduledNotificationReqs: [UNNotificationRequest] = []
        self.spyNotificationService.didNotificationAddCalled = {
            scheduledNotificationReqs.append($0)
            expect.fulfill()
        }
        
        // when
        usecase.runSyncEventNotification()
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        scheduledNotificationReqs = scheduledNotificationReqs.sorted(by: { $0.content.title < $1.content.title })
        XCTAssertEqual(scheduledNotificationReqs.count, 2)
        let eventNames = scheduledNotificationReqs.map { $0.content.title }
        XCTAssertEqual(eventNames, [
            "(\("Todo".localized()))\(futureTodoEvent1.name)",
            "(\("Todo".localized()))\(futureTodoEvent2.name)",
        ])
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[futureTodoEvent1.uuid],
            scheduledNotificationReqs[safe: 0].map { Set([$0.identifier]) }
        )
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[futureTodoEvent2.uuid],
            scheduledNotificationReqs[safe: 1].map { Set([$0.identifier]) }
        )
    }
    
    private func makeUsecaseWithInitialSync() -> EventNotificationUsecaseImple {
        // given
        let expect = expectation(description: "wait schedule twice")
        expect.expectedFulfillmentCount = 2
        expect.assertForOverFulfill = false
        let usecase = self.makeUsecase()
        
        self.spyNotificationService.didNotificationAddCalled = { _ in
            expect.fulfill()
        }
        
        // when
        usecase.runSyncEventNotification()
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        return usecase
    }
    
    // 이미 등록된 todo 수정된경우 알림 변경
    func testUsecase_whenAlreadyScheduledTodoUpdated_updateScheduleNotification() {
        // given
        let usecase = self.makeUsecaseWithInitialSync()
        let expect = expectation(description: "이미 등록된 todo 수정된경우 알림 변경")
        
        var updatedNotificationReqs: [UNNotificationRequest] = []
        self.spyNotificationService.didNotificationAddCalled = {
            updatedNotificationReqs.append($0)
            expect.fulfill()
        }
        
        // when
        let updatedTodo = futureTodoEvent2
            |> \.name .~ "future todo 2 - updated"
        self.stubTodoUsecase.makeTodoChangeInPeriodEvent([
            pastTodo, todoWithoutTime, futureTodoEvent1, updatedTodo
        ])
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        updatedNotificationReqs = updatedNotificationReqs.sorted(by: { $0.content.title < $1.content.title })
        XCTAssertEqual(updatedNotificationReqs.count, 1)
        let eventNames = updatedNotificationReqs.map { $0.content.title }
        XCTAssertEqual(eventNames, [
            "(\("Todo".localized()))future todo 2 - updated",
        ])
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[futureTodoEvent2.uuid],
            updatedNotificationReqs[safe: 0].map { Set([$0.identifier]) }
        )
        XCTAssertEqual(self.spyNotificationRepository.eventAndNotificationSets.count, 2)
        XCTAssertNotNil(usecase)    // 메모리 해제 안되게하기위해 필요함
    }
    
    // 이미 등록된 todo 삭제된 경우 알림 해제
    func testUsecase_whenAlreadyScheduledTodoRemoved_removePendingNotification() {
        // given
        let usecase = self.makeUsecaseWithInitialSync()
        let expectForRemove = expectation(description: "이미 등록된 todo 삭제된 경우 알림 해제")
        let expectForAdd = expectation(description: "신규 등록 없어서 add는 안됨")
        expectForAdd.isInverted = true
        
        var removedPendingNotificationIds: [String]?
        self.spyNotificationService.didRemovePendingNotificationWithIdentifiers = {
            removedPendingNotificationIds = $0
            expectForRemove.fulfill()
        }
        self.spyNotificationService.didNotificationAddCalled = { _ in
            expectForAdd.fulfill()
        }
        
        // when
        self.stubTodoUsecase.makeTodoChangeInPeriodEvent([
            pastTodo, todoWithoutTime, futureTodoEvent1
        ])
        self.wait(for: [expectForRemove, expectForAdd], timeout: 0.1)
        
        // then
        XCTAssertEqual(removedPendingNotificationIds?.count, 1)
        XCTAssertEqual(self.spyNotificationRepository.eventAndNotificationSets.count, 1)
        XCTAssertEqual(self.spyNotificationRepository.eventAndNotificationSets[futureTodoEvent2.uuid], nil)
        XCTAssertNotNil(usecase)    // 메모리 해제 안되게하기위해 필요함
    }
    
    // timeZone 변경시에도 연산 다시돔
    func testUsecase_whenTimeZoneChanges_reScheduleNotifications() {
        // given
        let expect = expectation(description: "timeZone 변경된 경우에도 notificaiton 다시 등록함")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithInitialSync()
        
        self.spyNotificationService.didNotificationAddCalled = { _ in
            expect.fulfill()
        }
        
        // when
        self.stubCalednarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "PDT")!)
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertNotNil(usecase)    // 메모리 해제 안되게하기위해 필요함
    }
}

extension EventNotificationUsecaseImpleTests {
    
    private func makeUsecaseWithOnlyStubSchedules() -> EventNotificationUsecaseImple {
        let usecase = self.makeUsecase()
        self.stubTodoUsecase.makeTodoChangeInPeriodEvent([])
        self.stubScheduleUsecase.makeScheduleChangeInPeriodEvent([
            pastSchedule, schedule1, scheduleWithRepeat
        ])
        return usecase
    }
    
    // 현재 시간부터 1년 단위로 미래 일정 + 반복일정의 미래 시간 알림 등록
    func testUsecase_whenSyncScheduleEventNotifications_scheduleNotificationsFromNowToNextYear() {
        // given
        let expect = expectation(description: "현재 시간부터 1년 단위로 미래 일정 + 반복일정의 미래 시간 알림 등록")
        expect.expectedFulfillmentCount = 13
        let usecase = self.makeUsecaseWithOnlyStubSchedules()
        
        self.spyNotificationService.didNotificationAddCalled = { req in
            expect.fulfill()
        }
        
        // when
        usecase.runSyncEventNotification()
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(self.spyNotificationRepository.eventAndNotificationSets[schedule1.uuid]?.count, 1)
        XCTAssertEqual(self.spyNotificationRepository.eventAndNotificationSets[scheduleWithRepeat.uuid]?.count, 12)
    }
    
    private func makeUsecaseWithInitialSyncSchedules() -> EventNotificationUsecaseImple {
        // given
        let expect = expectation(description: "wait add 13 times")
        expect.expectedFulfillmentCount = 13
        expect.assertForOverFulfill = false
        let usecase = self.makeUsecaseWithOnlyStubSchedules()
        
        self.spyNotificationService.didNotificationAddCalled = { _ in
            expect.fulfill()
        }
        
        // when
        usecase.runSyncEventNotification()
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        return usecase
    }
    
    // 이미 등록된 일정이 수정된경우 알림 변경
    func testUsecase_whenScheduleEventUpdated_updatePendingNotification() {
        // given
        let usecase = self.makeUsecaseWithInitialSyncSchedules()
        let expect = expectation(description: "이미 등록된 일정이 수정된경우 알림 변경")
        
        var updatedReq: [UNNotificationRequest] = []
        self.spyNotificationService.didNotificationAddCalled = {
            updatedReq.append($0)
            expect.fulfill()
        }
        
        // when
        let newEvent = schedule1 |> \.name .~ "updated"
        self.stubScheduleUsecase.makeScheduleChangeInPeriodEvent([
            pastSchedule, newEvent, scheduleWithRepeat
        ])
        self.wait(for: [expect], timeout: 0.1)
        
        // then
        XCTAssertEqual(updatedReq.count, 1)
        XCTAssertEqual(updatedReq.first?.content.title, "updated")
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[schedule1.uuid]?.count, 1
        )
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[scheduleWithRepeat.uuid]?.count,
            12
        )
        XCTAssertNotNil(usecase)    // 메모리 해제 안되게하기위해 필요함
    }
    
    // 이미 등록된 일정이 삭제된 경우 알림 삭제
    func testUsecase_whenScheduleEventRemoved_cancelPendingTodo() {
        // given
        let usecase = self.makeUsecaseWithInitialSyncSchedules()
        let expectForRemove = expectation(description: "이미 등록된 일정이 삭제된 경우 알림 삭제")
        let expectForAdd = expectation(description: "변경사항 없어서 신규추가 없음")
        expectForAdd.isInverted = true
        
        var removedIds: [String]?
        self.spyNotificationService.didRemovePendingNotificationWithIdentifiers = {
            removedIds = $0
            expectForRemove.fulfill()
        }
        self.spyNotificationService.didNotificationAddCalled = { _ in
            expectForAdd.fulfill()
        }
        
        // when
        self.stubScheduleUsecase.makeScheduleChangeInPeriodEvent([
            pastSchedule, scheduleWithRepeat
        ])
        self.wait(for: [expectForRemove, expectForAdd], timeout: 0.1)
        
        // then
        XCTAssertEqual(removedIds?.count, 1)
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[schedule1.uuid], nil
        )
        XCTAssertEqual(
            self.spyNotificationRepository.eventAndNotificationSets[scheduleWithRepeat.uuid]?.count,
            12
        )
        XCTAssertNotNil(usecase)    // 메모리 해제 안되게하기위해 필요함
    }
}


private var pastTodo: TodoEvent = {
    return TodoEvent(uuid: "past", name: "past todo")
        |> \.time .~ .at(Date().addingTimeInterval(-100).timeIntervalSince1970)
        |> \.notificationOption .~ .atTime
}()

private var todoWithoutTime: TodoEvent = {
    return TodoEvent(uuid: "todo-without-time", name: "todo without time")
}()

private var futureTodoEvent1: TodoEvent = {
    return TodoEvent(uuid: "future-todo-1", name: "future todo 1")
        |> \.time .~ .at(Date().addingTimeInterval(100).timeIntervalSince1970)
        |> \.notificationOption .~ .atTime
}()

private var futureTodoEvent2: TodoEvent = {
    return TodoEvent(uuid: "future-todo-2", name: "future todo 2")
        |> \.time .~ .at(Date().addingTimeInterval(200).timeIntervalSince1970)
        |> \.notificationOption .~ .atTime
}()

private var pastSchedule: ScheduleEvent = {
    return ScheduleEvent(
        uuid: "past",
        name: "past sc",
        time: .at(Date().addingTimeInterval(-100).timeIntervalSince1970)
    )
    |> \.notificationOption .~ .atTime
}()

private var schedule1: ScheduleEvent = {
    return ScheduleEvent(
        uuid: "sc1",
        name: "sc1",
        time: .at(Date().addingTimeInterval(100).timeIntervalSince1970)
    )
    |> \.notificationOption .~ .atTime
}()

private var scheduleWithRepeat: ScheduleEvent = {
    let time = Date().timeIntervalSince1970
    return ScheduleEvent(
        uuid: "sc-repeat",
        name: "sc-repeat",
        time: .at(time)
    )
    |> \.repeating .~ EventRepeating(
        repeatingStartTime: time,
        repeatOption: EventRepeatingOptions.EveryMonth(timeZone: TimeZone(abbreviation: "KST")!)
    )
    |> \.notificationOption .~ .atTime
}()

private final class PrivateStubTodoEventUsecase: StubTodoEventUsecase {
    
    private let fakeSubject = CurrentValueSubject<[TodoEvent]?, Never>(nil)
    
    func makeTodoChangeInPeriodEvent(_ todos: [TodoEvent]) {
        self.fakeSubject.send(todos)
    }
    
    override func todoEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[TodoEvent], Never> {
        return self.fakeSubject.compactMap { $0 }
            .eraseToAnyPublisher()
    }
}


private final class PrivateStubScheduleEventUsecase: StubScheduleEventUsecase {
    
    private let fakeSubject = CurrentValueSubject<MemorizedScheduleEventsContainer, Never>(.init())
    
    func makeScheduleChangeInPeriodEvent(_ schedules: [ScheduleEvent]) {
        var container = MemorizedScheduleEventsContainer()
        schedules.forEach {
            container = container.invalidate($0.uuid)
            container = container.append($0)
        }
        self.fakeSubject.send(container)
    }
    
    override func scheduleEvents(
        in period: Range<TimeInterval>
    ) -> AnyPublisher<[ScheduleEvent], Never> {
        return self.fakeSubject
            .map { $0.scheduleEvents(in: period) }
            .eraseToAnyPublisher()
    }
}

private final class SpyEventNotificationRepository: EventNotificationRepository, @unchecked Sendable {
    
    
    var eventAndNotificationSets: [String: Set<String>] = [:]
    
    func removeAllSavedNotificationId(of eventIds: [String]) async throws -> [String] {
        var sender: [String] = []
        eventIds.forEach {
            let set = self.eventAndNotificationSets[$0] ?? []
            sender += Array(set)
            self.eventAndNotificationSets[$0] = nil
        }
        return sender
    }
    
    func saveNotificationId(of eventId: String, _ notificationId: String) async throws {
        self.eventAndNotificationSets = eventAndNotificationSets
            |> key(eventId) %~ { $0 <> [notificationId] }
    }
}
