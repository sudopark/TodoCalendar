//
//  ForemostEventUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 6/14/24.
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

class ForemostEventUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyEventNotifyService: SharedEventNotifyService!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyEventNotifyService = nil
    }
    
    private func makeUsecase(
        isForemostNotExists: Bool = false,
        foremostIsTodo: Bool = true,
        withFail: Bool = false
    ) -> ForemostEventUsecaseImple {
        let repository = StubForemostEventRepository()
        if withFail {
            repository.shouldLoadfailEvent = true
            repository.shouldFailUpdate = true
            repository.shouldFailRemove = true
        }
        if !isForemostNotExists {
            if foremostIsTodo {
                repository.stubForemostEvent = TodoEvent(uuid: "foremost_todo", name: "old")
            } else {
                repository.stubForemostEvent = ScheduleEvent(uuid: "foremost_schedule", name: "old", time: .at(100))
            }
        } else {
            repository.stubForemostEvent = nil
        }
        self.spyEventNotifyService = .init(notifyQueue: nil)
        return .init(
            repository: repository,
            sharedDataStore: .init(),
            eventNotifyService: self.spyEventNotifyService
        )
    }
}

extension ForemostEventUsecaseImpleTests {
    
    // 조회해서 이벤트 방출
    func testUsecase_whenAfterRefresh_updateFeatureId() {
        // given
        func parameterizeTest(isTodo: Bool) {
            // given
            let expect = expectation(description: "refresh 이후에 이벤트 방출")
            expect.expectedFulfillmentCount = 2
            let usecase = self.makeUsecase(foremostIsTodo: isTodo)
            
            // when
            let events = self.waitOutputs(expect, for: usecase.foremostEvent) {
                usecase.refresh()
            }
            
            // then
            let expectId = isTodo ? "foremost_todo" : "foremost_schedule"
            XCTAssertEqual(events.map { $0?.eventId }, [nil, expectId])
        }
        // when + then
        parameterizeTest(isTodo: true)
        parameterizeTest(isTodo: false)
    }
    
    func testUsecase_whenAfterRefresh_updateForemostIdIsNilWhenNotExists() {
        // given
        let expect = expectation(description: "foremost 존재하지 않는다면 refresh 이후에도 nil")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(isForemostNotExists: true)
        
        // when
        let events = self.waitOutputs(expect, for: usecase.foremostEvent) {
            usecase.refresh()
        }
        
        // then
        XCTAssertEqual(events.map { $0?.eventId }, [nil, nil])
    }
    
    func testUsecase_whenRefresh_notify() {
        // given
        func parameterizeTest(stubShouldLoadFail: Bool = false) {
            // given
            let expect = expectation(description: "refresh 중임을 알림")
            expect.expectedFulfillmentCount = 2
            let usecase = self.makeUsecase(withFail: stubShouldLoadFail)
            
            // when
            let refreshingEvent: AnyPublisher<RefreshingEvent, Never> = self.spyEventNotifyService.event()
            let isRefreshings = self.waitOutputs(expect, for: refreshingEvent) {
                usecase.refresh()
            }
            
            // then
            XCTAssertEqual(isRefreshings, [
                RefreshingEvent.refreshForemostEvent(true),
                RefreshingEvent.refreshForemostEvent(false)
            ])
        }
        // when + then
        parameterizeTest()
        parameterizeTest(stubShouldLoadFail: true)
    }
    
    // 업데이트
    func testUsecase_updateForemost() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when + then
        try await usecase.update(foremost: .init("some", true))
    }
    
    // 업데이트 실패
    func testUsecase_updateForemostFail() async {
        // given
        let usecase = self.makeUsecase(withFail: true)
        var failure: Error?
        
        // when
        do {
            try await usecase.update(foremost: .init("some", true))
        } catch {
            failure = error
        }
        
        // then
        XCTAssertNotNil(failure)
    }
    
    // 삭제하고
    func testUsecase_removeForemost() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when + then
        try await usecase.remove()
    }
    
    // 삭제 실패
    func testUsecase_removeForemostFail() async {
        // given
        let usecase = self.makeUsecase(withFail: true)
        var failure: Error?
        
        // when
        do {
            try await usecase.remove()
        } catch {
            failure = error
        }
        
        // then
        XCTAssertNotNil(failure)
    }
    
    // 업데이트, 삭제 이후에도 이벤트 방출
    func testUsecase_whenAfterUpdateAndRemove_updateCurrentForemostEventId() {
        // given
        let expect = expectation(description: "업데이트, 삭제 이후에 foremost 업데이트")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecase()
        
        // when
        let events = self.waitOutputs(expect, for: usecase.foremostEvent, timeout: 0.1) {
            Task {
                usecase.refresh()
                try await Task.sleep(for: .milliseconds(10))
                try await usecase.update(foremost: .init("new", true))
                try await Task.sleep(for: .milliseconds(10))
                try await usecase.remove()
            }
        }
        
        // then
        let ids = events.map { $0?.eventId }
        XCTAssertEqual(ids, [
            nil, "foremost_todo", "new", nil
        ])
    }
}
