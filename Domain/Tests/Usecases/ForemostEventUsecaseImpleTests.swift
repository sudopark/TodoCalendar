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
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
    }
    
    private func makeUsecase(
        isForemostNotExists: Bool = false,
        withFail: Bool = false
    ) -> ForemostEventUsecaseImple {
        let repository = StubForemostEventRepository()
        if withFail {
            repository.shouldLoadfailEvent = true
            repository.shouldFailUpdate = true
            repository.shouldFailRemove = true
        }
        if !isForemostNotExists {
            repository.stubForemostEvent = TodoEvent(uuid: "foremost", name: "old")
        } else {
            repository.stubForemostEvent = nil
        }
        return .init(repository: repository, sharedDataStore: .init())
    }
}

extension ForemostEventUsecaseImpleTests {
    
    // 조회해서 이벤트 방출
    func testUsecase_whenAfterRefresh_updateFeatureId() {
        // given
        let expect = expectation(description: "refresh 이후에 이벤트 방출")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let events = self.waitOutputs(expect, for: usecase.foremostEventId) {
            usecase.refresh()
        }
        
        // then
        XCTAssertEqual(events.map { $0?.eventId }, [nil, "foremost"])
    }
    
    func testUsecase_whenAfterRefresh_updateForemostIdIsNilWhenNotExists() {
        // given
        let expect = expectation(description: "foremost 존재하지 않는다면 refresh 이후에도 nil")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(isForemostNotExists: true)
        
        // when
        let events = self.waitOutputs(expect, for: usecase.foremostEventId) {
            usecase.refresh()
        }
        
        // then
        XCTAssertEqual(events.map { $0?.eventId }, [nil, nil])
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
        let events = self.waitOutputs(expect, for: usecase.foremostEventId) {
            Task {
                usecase.refresh()
                try await usecase.update(foremost: .init("new", true))
                try await usecase.remove()
            }
        }
        
        // then
        let ids = events.map { $0?.eventId }
        XCTAssertEqual(ids, [
            nil, "foremost", "new", nil
        ])
    }
}
