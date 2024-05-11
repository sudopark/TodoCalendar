//
//  DoneTodoEventsPagingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 5/9/24.
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


class DoneTodoEventsPagingUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    private var stubRepository: PrivateStubRepository!
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
    }
    
    private func makeUsecase() -> DoneTodoEventsPagingUsecaseImple {
        return .init(pageSize: 10, todoRepository: self.stubRepository)
    }
}

extension DoneTodoEventsPagingUsecaseImpleTests {
    
    private func prepareRecordResult(_ usecase: DoneTodoEventsPagingUsecaseImple) -> CurrentValueSubject<[DoneTodoEvent]?, Never> {
     
        let subject = CurrentValueSubject<[DoneTodoEvent]?, Never>(nil)
        
        usecase.events
            .subscribe(subject)
            .store(in: &self.cancelBag)
        
        return subject
    }
    
    private func waitNewPage(
        willNotUpdate: Bool = false,
        _ recordSubject: CurrentValueSubject<[DoneTodoEvent]?, Never>,
        _ action: @escaping () -> Void
    ) -> [DoneTodoEvent]? {
        // given
        let expect = expectation(description: "wait new page")
        expect.assertForOverFulfill = false
        if willNotUpdate {
            expect.isInverted = true
        }
        
        // when
        let result = self.waitFirstOutput(expect, for: recordSubject.dropFirst(), action)
        
        // then
        return result ?? nil
    }
    
    // 정상케이스 끝까지 조회
    func testUsecase_pagingUntilEnd() {
        // given
        let usecase = self.makeUsecase()
        let record = self.prepareRecordResult(usecase)
        
        // when
        let page1 = self.waitNewPage(record) { usecase.reload() }
        let page2 = self.waitNewPage(record) { usecase.loadMore() }
        let page3 = self.waitNewPage(record) { usecase.loadMore() }
        let noMorePaging = self.waitNewPage(willNotUpdate: true, record) { usecase.loadMore() }
        
        // then
        XCTAssertEqual(
            page1?.map { $0.uuid }, (14..<24).reversed().map { "id:\($0)" }
        )
        XCTAssertEqual(
            page2?.map { $0.uuid }, (4..<24).reversed().map { "id:\($0)" }
        )
        XCTAssertEqual(
            page3?.map { $0.uuid }, (0..<24).reversed().map { "id:\($0)" }
        )
        XCTAssertNil(noMorePaging)
    }
    
    // 조회 실패시 에러
    func testUsecase_whenFailToLoad_showError() {
        // given
        let expect = expectation(description: "조회 실패시 에러")
        let usecase = self.makeUsecase()
        self.stubRepository.shouldLoadFailMocking = true
        
        // when
        let error = self.waitFirstOutput(expect, for: usecase.loadFailed, timeout: 0.1) {
            usecase.reload()
        }
        
        // then
        XCTAssertNotNil(error)
    }
    
    // 실패 이후 재시도하고 끝까지 페이징
    func testUsecase_whenErrorOccurDuringPaging_retryPaging() {
        // given
        let usecase = self.makeUsecase()
        let record = self.prepareRecordResult(usecase)
        
        // when
        let page1 = self.waitNewPage(record) { usecase.reload() }
        let page2Failed = self.waitNewPage(willNotUpdate: true, record) {
            self.stubRepository.shouldLoadFailMocking = true
            usecase.loadMore()
        }
        let page2 = self.waitNewPage(record) {
            self.stubRepository.shouldLoadFailMocking = false
            usecase.loadMore()
        }
        
        // then
        XCTAssertEqual(
            page1?.map { $0.uuid }, (14..<24).reversed().map { "id:\($0)" }
        )
        XCTAssertNil(page2Failed)
        XCTAssertEqual(
            page2?.map { $0.uuid }, (4..<24).reversed().map { "id:\($0)" }
        )
    }
}


private final class PrivateStubRepository: StubTodoEventRepository {
    
    var shouldLoadFailMocking: Bool = false
    
    override func loadDoneTodoEvents(_ params: DoneTodoLoadPagingParams) async throws -> [DoneTodoEvent] {
        
        guard self.shouldLoadFailMocking == false
        else {
            throw RuntimeError("failed")
        }
     
        switch params.cursorAfter {
        case .none:
            return (14..<24).reversed().map { DoneTodoEvent.dummy($0) }
            
        case 14:
            return (4..<14).reversed().map { DoneTodoEvent.dummy($0) }
            
        case 4:
            return (0..<4).reversed().map { DoneTodoEvent.dummy($0) }
            
        default: return []
        }
    }
}

private extension DoneTodoEvent {

    static func dummy(_ int: Int) -> Self {
        return .init(
            uuid: "id:\(int)",
            name: "refreshed:\(int)",
            originEventId: "origin:\(int)",
            doneTime: .init(timeIntervalSince1970: TimeInterval(int))
        )
    }
}
