//
//  SelectEventTagViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 10/22/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene

class SelectEventTagViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyListener: SpyListener!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.spyListener = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.spyListener = nil
    }
    
    private func makeViewModel(
        previous: AllEventTagId
    ) -> SelectEventTagViewModelImple {
        
        let usecase = StubEventTagUsecase()
        let tags = (0..<3).map {
            return EventTag(uuid: "id:\($0)", name: "n:\($0)", colorHex: "some")
        }
        usecase.allTagsLoadResult = .success(tags)
        
        let viewModel = SelectEventTagViewModelImple(
            startWith: previous,
            tagUsecase: usecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
}

extension SelectEventTagViewModelImpleTests {
    
    func testViewModel_provideAllTagList() {
        // given
        let expect = expectation(description: "모든 태그 리스트 제공")
        let viewModel = self.makeViewModel(previous: .default)
        
        // when
        let tags = self.waitFirstOutput(expect, for: viewModel.tags) {
            viewModel.refresh()
        }
        
        // then
        let tagIds = tags?.map { $0.id }
        XCTAssertEqual(tagIds, [
            .default,
            .custom("id:0"),
            .custom("id:1"),
            .custom("id:2"),
            .holiday
        ])
    }
    
    func testViewModel_whenInitalTagIsBasetag_baseTagIsFirstSelectedTag() {
        // given
        let expect = expectation(description: "초기 선택된 태그가 기본 태그인 경우 해당 태그가 초기 선택값")
        let viewModel = self.makeViewModel(previous: .default)
        
        // when
        let selected = self.waitFirstOutput(expect, for: viewModel.selectedTagId) {
            viewModel.refresh()
        }
        
        // then
        XCTAssertEqual(selected, .default)
    }
    
    func testViewModel_whenInitalTagIsCustomTag_thatTagIsInitialSelectedTag() {
        // given
        let expect = expectation(description: "이전 선택태그 있는경우 해당 태그가 초기 선택값")
        let viewModel = self.makeViewModel(previous: .custom("id:1"))
        
        // when
        let selected = self.waitFirstOutput(expect, for: viewModel.selectedTagId) {
            viewModel.refresh()
        }
        
        // then
        XCTAssertEqual(selected, .custom("id:1"))
    }
    
    private func makeViewModelWithInitalListLoaded() -> SelectEventTagViewModelImple {
        let expect = expectation(description: "wait inital list")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel(previous: .default)
        let _ = self.waitFirstOutput(expect, for: viewModel.tags) {
            viewModel.refresh()
        }
        return viewModel
    }
    
    func testViewModel_whenAfterSelectTag_updateSelected() {
        // given
        let expect = expectation(description: "선택 태그 업데이트시에 선택태그 정보 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        let ids = self.waitOutputs(expect, for: viewModel.selectedTagId) {
            viewModel.selectTag(.custom("id:1"))
            viewModel.selectTag(.holiday)
        }
        
        // then
        XCTAssertEqual(ids, [
            .default, .custom("id:1"), .holiday
        ])
    }
    
    // TODO: 태그 추가 화면으로 이동 + 태그 추가된경우 해당 태그 선택
    
    // TODO: 태그 설정화면으로 이동 -> 선택중이던 태그가 삭제된경우 디폴트 태그로 자동 선택
    
    func testViewModel_whenAfterSelectTag_notify() {
        // given
        let expect = expectation(description: "선택태그 변경시에 외부로 이벤트 전파")
        expect.expectedFulfillmentCount = 2
        self.spyListener.didSelectedtagNotify = { expect.fulfill() }
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        viewModel.selectTag(.custom("id:1"))
        viewModel.selectTag(.default)
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyListener.didSelectedTags, [
            .init(.custom("id:1"), "n:1", .custom(hex: "some")),
            .defaultTag
        ])
    }
}


private class SpyRouter: BaseSpyRouter, SelectEventTagRouting, @unchecked Sendable {
    
    
}

private class SpyListener: SelectEventTagSceneListener {
    
    var didSelectedTags: [SelectedTag] = []
    var didSelectedtagNotify: (() -> Void)?
    func selectEventTag(didSelected tag: SelectedTag) {
        self.didSelectedTags.append(tag)
        self.didSelectedtagNotify?()
    }
}
