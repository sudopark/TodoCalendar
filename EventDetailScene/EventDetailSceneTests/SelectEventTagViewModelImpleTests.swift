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
    
    func testViewModel_whenRouteToAddNewTagAndNewtagCreated_provideNewTagAtList() {
        // given
        let expect = expectation(description: "태그 추가 화면으로 이동 + 태그 추가된경우 해당 태그 리스트에 추가")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        let tagLists = self.waitOutputs(expect, for: viewModel.tags) {
            viewModel.addTag()
            viewModel.eventTag(created: .init(uuid: "new_tag", name: "new tag", colorHex: "some"))
        }
        
        // then
        let tagIdLists = tagLists.map { ts in ts.map { $0.id } }
        XCTAssertEqual(tagIdLists, [
            [.default, .custom("id:0"), .custom("id:1"), .custom("id:2"), .holiday],
            [.default, .custom("new_tag"), .custom("id:0"), .custom("id:1"), .custom("id:2"), .holiday]
        ])
        XCTAssertEqual(self.spyRouter.didRouteToAddNewtag, true)
    }
    
    func testViewModel_whenRouteToAddNewTagAndNewtagCreated_selectIt() {
        // given
        let expect = expectation(description: "태그 추가 화면으로 이동 + 태그 추가된경우 해당 태그 자동으로 선택")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        let selectedIds = self.waitOutputs(expect, for: viewModel.selectedTagId) {
            viewModel.addTag()
            viewModel.eventTag(created: .init(uuid: "new_tag", name: "new tag", colorHex: "some"))
        }
        
        // then
        XCTAssertEqual(selectedIds, [
            .default, .custom("new_tag")
        ])
    }
    
    func testViewModel_whenTagUpdated_updateItFromList() {
        // given
        let expect = expectation(description: "태그가 수정된경우 해당 태그 리스트에서 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        let tagLists = self.waitOutputs(expect, for: viewModel.tags) {
            viewModel.moveToTagSetting()
            viewModel.eventTag(updated: .init(uuid: "id:1", name: "new_name", colorHex: "some"))
        }
        
        // then
        let tagIdLists = tagLists.map { ts in ts.map { $0.id } }
        let tag1Names = tagLists.compactMap { ts in ts.first(where:{ $0.id == .custom("id:1") })?.name }
        XCTAssertEqual(tagIdLists, [
            [.default, .custom("id:0"), .custom("id:1"), .custom("id:2"), .holiday],
            [.default, .custom("id:0"), .custom("id:1"), .custom("id:2"), .holiday]
        ])
        XCTAssertEqual(tag1Names, ["n:1", "new_name"])
        XCTAssertEqual(self.spyRouter.didrouteToTagList, true)
    }
    
    func testViewModel_whenTagIsRemoved_removeItFromList() {
        // given
        let expect = expectation(description: "태그가삭제된경우 해당 태그 리스트에서 제거")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        let tagLists = self.waitOutputs(expect, for: viewModel.tags) {
            viewModel.moveToTagSetting()
            viewModel.eventTag(deleted: "id:1")
        }
        
        // then
        let tagIdLists = tagLists.map { ts in ts.map { $0.id } }
        XCTAssertEqual(tagIdLists, [
            [.default, .custom("id:0"), .custom("id:1"), .custom("id:2"), .holiday],
            [.default, .custom("id:0"), .custom("id:2"), .holiday]
        ])
    }
    
    func testViewModel_whenSelectedTagListRemoved_selectDefaultTag() {
        // given
        let expect = expectation(description: "선택된 태그가 삭제된 경우 기본태그로 선택 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithInitalListLoaded()
        
        // when
        let selectedIds = self.waitOutputs(expect, for: viewModel.selectedTagId) {
            viewModel.selectTag(.custom("id:1"))
            viewModel.moveToTagSetting()
            viewModel.eventTag(deleted: "id:1")
        }
        
        // then
        XCTAssertEqual(selectedIds, [
            .default, .custom("id:1"), .default
        ])
    }
    
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
    
    var didrouteToTagList: Bool?
    func routeToTagListScene() {
        self.didrouteToTagList = true
    }
    
    var didRouteToAddNewtag: Bool?
    func routeToAddNewTagScene() {
        self.didRouteToAddNewtag = true
    }
}

private class SpyListener: SelectEventTagSceneListener {
    
    var didSelectedTags: [SelectedTag] = []
    var didSelectedtagNotify: (() -> Void)?
    func selectEventTag(didSelected tag: SelectedTag) {
        self.didSelectedTags.append(tag)
        self.didSelectedtagNotify?()
    }
}
