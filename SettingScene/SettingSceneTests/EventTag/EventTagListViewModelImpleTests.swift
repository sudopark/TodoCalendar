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
                return EventTag(uuid: "id:\($0)", name: "n:\($0)", colorHex: "some")
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
    
    private func makeViewModelWithInitialListLoaded() -> EventTagListViewModelImple {
        // given
        let expect = expectation(description: "wait initial list")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.reload()
        }
        
        // then
        return viewModel
    }
    
    func testViewModel_whenToggleTagIsOn_updateList() {
        // given
        let expect = expectation(description: "tag 활성화 여부 업데이트시에 리스트 업데이트")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.toggleIsOn("id:3")
            viewModel.toggleIsOn("id:4")
            viewModel.toggleIsOn("id:3")
        }
        
        // then
        let offTagIds = cvmLists.map { cs in cs.filter { !$0.isOn }.map { $0.id} }
        XCTAssertEqual(offTagIds, [
            [],
            ["id:3"],
            ["id:3", "id:4"],
            ["id:4"]
        ])
    }
}

extension EventTagListViewModelImpleTests {

    
    private class SpyRouter: BaseSpyRouter, EventTagListRouting, @unchecked Sendable {
        
    }
}
