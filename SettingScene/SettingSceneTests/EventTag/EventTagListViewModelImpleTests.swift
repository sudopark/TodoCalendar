//
//  EventTagListViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 2023/09/24.
//

import XCTest
import Combine
import Domain
import Extensions
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
    
    private func makeViewModel(shouldLoadFail: Bool = false) -> EventTagListViewModelImple {
        let usecase = StubEventTagUsecase()
        if shouldLoadFail {
            usecase.allTagsLoadResult = .failure(RuntimeError("failed"))
        } else {
            let tags = (0..<20).map {
                return EventTag(name: "t:\($0)", colorHex: "some")
            }
            usecase.allTagsLoadResult = .success(tags)
        }
        let viewModel = EventTagListViewModelImple(tagUsecase: usecase)
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventTagListViewModelImpleTests {
    
    func testViewModel_provideTags() {
        // given
        let expect = expectation(description: "tag 리스트 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let cells = self.waitFirstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.reload()
        }
        
        // then
        XCTAssertEqual(cells?.count, 20)
    }
    
    func testViewModel_whenLoadAllTagsFail_showError() {
        // given
        let expect = expectation(description: "tag 리스트 조회 실패시에 에러 알림")
        let viewModel = self.makeViewModel(shouldLoadFail: true)
        self.spyRouter.didShowErrorCallback = { _ in
            expect.fulfill()
        }
        
        // when
        viewModel.reload()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
}

extension EventTagListViewModelImpleTests {

    
    private class SpyRouter: BaseSpyRouter, EventTagListRouting, @unchecked Sendable {
        
    }
}
