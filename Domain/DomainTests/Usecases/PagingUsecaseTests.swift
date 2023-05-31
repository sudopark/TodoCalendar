//
//  PagingUsecaseTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/01.
//

import XCTest
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import Domain

class PagingUsecaseTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var usecase: PagingUsecase<DummyQuery, DummyResult>!
    private var recordedResultSubject: CurrentValueSubject<DummyResult?, Never>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.recordedResultSubject = .init(nil)
        self.usecase = self.makeUsecase()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.usecase = nil
        self.recordedResultSubject = nil
    }
    
    private var shouldLoadFail: Bool = false
    private func loading(_ query: DummyQuery) async throws -> LoadingResponse {
        if self.shouldLoadFail {
            throw RuntimeError("failed")
        }
        let range = (query.pageNumber*10..<query.pageNumber*10+10)
        let prefix = query.query
        let dummies = range.map { "\(prefix):\($0)" }
        let isLast = query.pageNumber == 2
        return .init(dummies: dummies, pageNumber: query.pageNumber, hasMore: !isLast)
    }
    
    private func makeUsecase() -> PagingUsecase<DummyQuery, DummyResult> {
        
        let option = PagingOption() |> \.loadThrottleIntervalMillis .~ 0
        
        return PagingUsecase(option: option) { query in
            let response = try await self.loading(query)
            return .init(query: query, isLastPage: !response.hasMore, dummies: response.dummies)
        }
    }
    
    private func recordTotalResult() {
        
        self.usecase.totalResult
            .subscribe(self.recordedResultSubject)
            .store(in: &self.cancelBag)
    }
    
    private func updateLoadFailMocking(_ fail: Bool) {
        self.shouldLoadFail = fail
    }
}

extension PagingUsecaseTests {
    
    private func waitNewLoadPage(willNotUpdate: Bool = false, _ action: @escaping (PagingUsecase<DummyQuery, DummyResult>) -> Void) -> DummyResult? {
        // given
        let expect = expectation(description: "wait new page")
        expect.assertForOverFulfill = false
        if willNotUpdate {
            expect.isInverted = true
        }
        
        // when
        let result = self.waitFirstOutput(expect, for: self.recordedResultSubject.dropFirst()) {
            action(self.usecase)
        } ?? nil
        
        // then
        return result
    }
    
    // refresh + load more unitl end
    func testUsecase_refreshAndLoadMoreUntilEnd() {
        // given
        self.recordTotalResult()
        
        // when
        let pageTo0 = self.waitNewLoadPage { $0.refresh(.init(pageNumber: 0, query: "q")) }
        let pageTo1 = self.waitNewLoadPage { $0.loadMore() }
        let pageTo2 = self.waitNewLoadPage { $0.loadMore() }
        let noMorePage = self.waitNewLoadPage(willNotUpdate: true) { $0.loadMore() }

        XCTAssertEqual(pageTo0?.query.pageNumber, 0)
        XCTAssertEqual(pageTo0?.query.query, "q")
        XCTAssertEqual(pageTo0?.isLastPage, false)
        XCTAssertEqual(pageTo0?.dummies, (0..<10).map { "q:\($0)" })

        XCTAssertEqual(pageTo1?.query.pageNumber, 1)
        XCTAssertEqual(pageTo1?.query.query, "q")
        XCTAssertEqual(pageTo1?.isLastPage, false)
        XCTAssertEqual(pageTo1?.dummies, (0..<20).map { "q:\($0)" })

        XCTAssertEqual(pageTo2?.query.pageNumber, 2)
        XCTAssertEqual(pageTo2?.query.query, "q")
        XCTAssertEqual(pageTo2?.isLastPage, true)
        XCTAssertEqual(pageTo2?.dummies, (0..<30).map { "q:\($0)" })

        XCTAssertNil(noMorePage)
    }
    
    // refresh + loadMore(page1) + error + loadMore(page2)
    func testUsecase_whenRefreshAndLoadMoreAndLoadFailed_ignoreAndLoadUntilEnd() {
        // given
        self.recordTotalResult()
        
        // when
        let failRefresh = self.waitNewLoadPage(willNotUpdate: true) {
            self.updateLoadFailMocking(true)
            $0.refresh(.init(pageNumber: 0, query: "q"))
        }
        let pageTo0 = self.waitNewLoadPage {
            self.updateLoadFailMocking(false)
            $0.refresh(.init(pageNumber: 0, query: "q"))
        }
        let pageTo1 = self.waitNewLoadPage { $0.loadMore() }
        let failLoadMore = self.waitNewLoadPage(willNotUpdate: true) {
            self.updateLoadFailMocking(true)
            $0.loadMore()
        }
        let pageTo2 = self.waitNewLoadPage {
            self.updateLoadFailMocking(false)
            $0.loadMore()
        }
        let noMorePage = self.waitNewLoadPage(willNotUpdate: true) { $0.loadMore() }
        
        // then
        XCTAssertNil(failRefresh)
        
        XCTAssertEqual(pageTo0?.query.pageNumber, 0)
        XCTAssertEqual(pageTo0?.dummies.count, 10)
        
        XCTAssertEqual(pageTo1?.query.pageNumber, 1)
        XCTAssertEqual(pageTo1?.dummies.count, 20)
        
        XCTAssertNil(failLoadMore)
        
        XCTAssertEqual(pageTo2?.query.pageNumber, 2)
        XCTAssertEqual(pageTo2?.dummies.count, 30)
        
        XCTAssertNil(noMorePage)
    }
    
    // refresh(q1) + loadMore + refresh(q2) + loadMore
    func testUsecase_refreshWithNewQuery() {
        // given
        self.recordTotalResult()
        
        // when
        let page_q1_0 = self.waitNewLoadPage { $0.refresh(.init(pageNumber: 0, query: "q1")) }
        let page_q1_1 = self.waitNewLoadPage { $0.loadMore() }
        let page_q2_0 = self.waitNewLoadPage { $0.refresh(.init(pageNumber: 0, query: "q2")) }
        let page_q2_1 = self.waitNewLoadPage { $0.loadMore() }
        
        // then
        XCTAssertEqual(page_q1_0?.query.query, "q1")
        XCTAssertEqual(page_q1_0?.query.pageNumber, 0)
        XCTAssertEqual(page_q1_0?.dummies, (0..<10).map { "q1:\($0)" })
        XCTAssertEqual(page_q1_1?.query.query, "q1")
        XCTAssertEqual(page_q1_1?.query.pageNumber, 1)
        XCTAssertEqual(page_q1_1?.dummies, (0..<20).map { "q1:\($0)" })
        
        XCTAssertEqual(page_q2_0?.query.query, "q2")
        XCTAssertEqual(page_q2_0?.query.pageNumber, 0)
        XCTAssertEqual(page_q2_0?.dummies, (0..<10).map { "q2:\($0)" })
        XCTAssertEqual(page_q2_1?.query.query, "q2")
        XCTAssertEqual(page_q2_1?.query.pageNumber, 1)
        XCTAssertEqual(page_q2_1?.dummies, (0..<20).map { "q2:\($0)" })
    }
    
    // update is refreshing
    func testUsecase_whenRefreshing_updateIsRefreshing() {
        // given
        let expect = expectation(description: "refresh 중에는 refresh중임을 알림")
        expect.expectedFulfillmentCount = 3
        
        // when
        let isRefreshing = self.waitOutputs(expect, for: usecase.isRefreshing) {
            self.usecase.refresh(.init(pageNumber: 0, query: "some"))
        }
        
        // then
        XCTAssertEqual(isRefreshing, [false, true, false])
    }
    
    // update is loadMore
    func testUsecase_whenLoadMore_updateIsLoadMore() {
        // given
        self.recordTotalResult()
        _ = self.waitNewLoadPage { $0.refresh(.init(pageNumber: 0, query: "some")) }
        let expect = expectation(description: "다음페이지 로드중일떄는 이를 알림")
        expect.expectedFulfillmentCount = 3
        
        // when
        let isLoadingMore = self.waitOutputs(expect, for: usecase.isLoadingMore) {
            self.usecase.loadMore()
        }
        
        // then
        XCTAssertEqual(isLoadingMore, [false, true, false])
    }
    
    // update is refreshing + when fail
    func testUsecase_whenRefreshFail_udpateIsRefresh() {
        // given
        let expect = expectation(description: "refresh 실패해도 refresh중임을 알림")
        expect.expectedFulfillmentCount = 3
        
        // when
        let isRefreshing = self.waitOutputs(expect, for: usecase.isRefreshing) {
            self.updateLoadFailMocking(true)
            self.usecase.refresh(.init(pageNumber: 0, query: "some"))
        }
        
        // then
        XCTAssertEqual(isRefreshing, [false, true, false])
    }
    
    // update is loadMore + when fail
    func testUsecase_whenLoadMoreFail_updateIsLoadMore() {
        // given
        self.recordTotalResult()
        _ = self.waitNewLoadPage { $0.refresh(.init(pageNumber: 0, query: "some")) }
        let expect = expectation(description: "다음페이지 로드 실패해도 로딩중임을 업데이트")
        expect.expectedFulfillmentCount = 3
        
        // when
        let isLoadingMore = self.waitOutputs(expect, for: usecase.isLoadingMore) {
            self.updateLoadFailMocking(true)
            self.usecase.loadMore()
        }
        
        // then
        XCTAssertEqual(isLoadingMore, [false, true, false])
    }
}

private extension PagingUsecaseTests {
    
    struct DummyQuery: PagingQueryType {
        let pageNumber: Int
        let query: String
        
        var isFirst: Bool {
            return pageNumber == 0
        }
        
        func isSameQuery(with other: PagingUsecaseTests.DummyQuery) -> Bool {
            return self.query == other.query
        }
    }
    
    struct LoadingResponse {
        let dummies: [String]
        let pageNumber: Int
        let hasMore: Bool
    }
    
    struct DummyResult: PagingResultType {
     
        typealias Query = DummyQuery
        
        let query: PagingUsecaseTests.DummyQuery
        var isLastPage: Bool = false
        
        let dummies: [String]
        
        func nextQuery() -> PagingUsecaseTests.DummyQuery? {
            guard self.isLastPage == false
            else {
                return nil
            }
            return .init(pageNumber: self.query.pageNumber + 1, query: self.query.query)
        }
        
        func append(_ next: PagingUsecaseTests.DummyResult) -> PagingUsecaseTests.DummyResult {
            return .init(query: next.query, isLastPage: next.isLastPage, dummies: self.dummies + next.dummies)
        }
    }
}
