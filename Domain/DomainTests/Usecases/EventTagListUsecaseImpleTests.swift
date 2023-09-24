//
//  EventTagListUsecaseImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 2023/09/24.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class EventTagListUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    var usecase: EventTagListUsecaseImple!
    private var recordedTotalResult: CurrentValueSubject<[EventTag]?, Never>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.recordedTotalResult = .init(nil)
        self.usecase = self.makeUsecase()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.recordedTotalResult = nil
        self.usecase = nil
    }
    
    private func makeUsecase() -> EventTagListUsecaseImple {
        let repository = PrivateStubRepository()
        let option = PagingOption() |> \.loadThrottleIntervalMillis .~ 0
        return .init(option: option, repository)
    }
    
    // load 동작이 async 하게 진행되어서
    // loadMore 동작을 연속적으로 호출시 정상동작안함
    // 페이지별로 따로 구독을 해도 구독할때마다 pagingusecase에서 scan 연산자가 새로 만들어지면서 기대하는 동작을 안함
    private func recordTotalResults() {
        self.usecase.eventTags
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] tags in
                self?.recordedTotalResult.send(tags)
            })
            .store(in: &self.cancelBag)
    }
}

extension EventTagListUsecaseImpleTests {
    
    private func waitNewPageLoaded(
        isInverting: Bool = false,
        _ action: @escaping (EventTagListUsecaseImple) -> Void
    ) -> [EventTag]? {
        // given
        let expect = expectation(description: "wait new page")
        expect.assertForOverFulfill = false
        if isInverting { expect.isInverted = true }
        
        // when
        let result = self.waitFirstOutput(expect, for: self.recordedTotalResult.dropFirst())
        {
            action(self.usecase)
        } ?? nil
        
        // then
        return result
    }
    
    func testUsecase_loadTagsWithPaging() {
        // given
        self.recordTotalResults()
        
        // when
        let page0 = self.waitNewPageLoaded{ $0.reload() }    // 0..<30
        let page1 = self.waitNewPageLoaded{ $0.loadMore() }  // 30..<60
        let page2 = self.waitNewPageLoaded{ $0.loadMore() }  // 60..<90
        let page3 = self.waitNewPageLoaded { $0.loadMore() }  // 90..<100
        let pageNothing = self.waitNewPageLoaded(isInverting: true) {
            $0.loadMore()
        }
        let page0Again = self.waitNewPageLoaded { $0.reload() }   // 0..<30
        
        // then
        XCTAssertEqual(page0?.map { $0.uuid }, (0..<30).map { "id:\($0)" })
        XCTAssertEqual(page1?.map { $0.uuid }, (0..<60).map { "id:\($0)" })
        XCTAssertEqual(page2?.map { $0.uuid }, (0..<90).map { "id:\($0)" })
        XCTAssertEqual(page3?.map { $0.uuid }, (0..<100).map { "id:\($0)" })
        XCTAssertNil(pageNothing)
        XCTAssertEqual(page0Again?.map { $0.uuid }, (0..<30).map { "id:\($0)" })
    }
}


extension EventTagListUsecaseImpleTests {
    
    private class PrivateStubRepository: StubEventTagRepository {
        
        override func loadTags(
            olderThan time: TimeInterval?,
            size: Int
        ) async throws -> [EventTag] {
            if time == 99 {
                return []
            }
            
            let timeInt = time.map { Int($0) }
            let upperBound = min(
                100,
                (timeInt.map { $0 + 1 + size } ?? size)
            )
            let range = timeInt.map { $0+1..<upperBound } ?? 0..<upperBound
            
            let tags = range.map {
                return EventTag(
                    uuid: "id:\($0)", name: "some", colorHex: "some", createAt: TimeInterval($0)
                )
            }
            return tags
        }
    }
}
