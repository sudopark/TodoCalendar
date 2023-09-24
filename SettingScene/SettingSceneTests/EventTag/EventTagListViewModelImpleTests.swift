//
//  EventTagListViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 2023/09/24.
//

import XCTest
import Combine
import Domain
import TestDoubles
import UnitTestHelpKit

@testable import SettingScene


class EventTagListViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel() -> EventTagListViewModelImple {
        let usecase = StubUsecase()
        let viewModel = EventTagListViewModelImple(tagListUsecase: usecase)
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventTagListViewModelImpleTests {
    
    func testViewModel_provideTags() {
        // given
        let expect = expectation(description: "tag 리스트 제공")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.reload()
            viewModel.loadMore()
        }
        
        // then
        XCTAssertEqual(cvmLists.map { $0.count }, [10, 20])
    }
}

extension EventTagListViewModelImpleTests {
    
    private class StubUsecase: EventTagListUsecase, @unchecked Sendable {
        private let fakeTags = CurrentValueSubject<[EventTag]?, Never>(nil)
        func reload() {
            let tags = (0..<10).map {
                EventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "some", createAt: TimeInterval($0))
            }
            self.fakeTags.send(tags)
        }
        
        func loadMore() {
            guard let old = self.fakeTags.value, let last = old.last else { return }
            let seq = Int(last.createAt)
            let tags = (seq+1..<seq+11).map {
                EventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "some", createAt: TimeInterval($0))
            }
            self.fakeTags.send(old + tags)
        }
        
        var eventTags: AnyPublisher<[EventTag], Never> {
            return self.fakeTags
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }
    }
    
    private class SpyRouter: BaseSpyRouter, EventTagListRouting, @unchecked Sendable {
        
    }
}
