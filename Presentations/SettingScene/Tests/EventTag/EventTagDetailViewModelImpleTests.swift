//
//  EventTagDetailViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 2023/10/03.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class EventTagDetailViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyListener: SpyListener!
    private var stubEventTagUsecase: StubEventTagUsecase!
    private var stubUISettingUsecase: StubUISettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.spyListener = .init()
        self.stubEventTagUsecase = .init()
        self.stubUISettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.spyListener = nil
        self.stubEventTagUsecase = nil
        self.stubUISettingUsecase = nil
    }
    
    private func makeViewModel(info: OriginalTagInfo?) -> EventTagDetailViewModelImple {
        let viewModel = EventTagDetailViewModelImple(
            originalInfo: info,
            eventTagUsecase: self.stubEventTagUsecase,
            uiSettingUsecase: self.stubUISettingUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
    
    private func stubActionFail() {
        self.stubEventTagUsecase.shouldMakeFail = true
        self.stubEventTagUsecase.shouldEditFail = true
        self.stubEventTagUsecase.shouldDeleteFail = true
    }
    
    private var customTagInfo: OriginalTagInfo {
        return .init(id: .custom("some"), name: "custom", colorHex: "old-hex")
    }
    
    private var holidayTagInfo: OriginalTagInfo {
        return .init(id: .holiday, name: "holiday", colorHex: "holiday")
    }
    
    private var defaultTagInfo: OriginalTagInfo {
        return .init(id: .default, name: "default", colorHex: "default")
    }
}

extension EventTagDetailViewModelImpleTests {
    
    // holiday => original info + deletable
    func testViewModel_provideInfosForHolidayTag() async throws {
        // given
        let viewModel = self.makeViewModel(info: self.holidayTagInfo)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, "holiday")
        let originColor = try await viewModel.originalColorHex.firstValue(with: 1)
        XCTAssertEqual(originColor, "holiday")
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    // default => original info  + deletable
    func testViewModel_provideInfosForDefaultTag() async throws {
        // given
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, "default")
        let originColor = try await viewModel.originalColorHex.firstValue(with: 1)
        XCTAssertEqual(originColor, "default")
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    // custom => original info  + deletable
    func testViewModel_provideInfoForCustomTag() async throws {
        // given
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, "custom")
        let originColor = try await viewModel.originalColorHex.firstValue(with: 1)
        XCTAssertEqual(originColor, "old-hex")
        XCTAssertEqual(viewModel.isDeletable, true)
        XCTAssertEqual(viewModel.isNameChangable, true)
    }
    
    // make case
    func testViewModel_provideInfoForMakeCase() async throws {
        // given
        let viewModel = self.makeViewModel(info: nil)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, nil)
        let originColor = try await viewModel.originalColorHex.firstValue(with: 1)
        XCTAssertEqual(originColor != nil, true)
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, true)
    }
}


// MARK: -  holiday or default 일때

extension EventTagDetailViewModelImpleTests {
    
    // 색상정보 제공
    func testViewModel_whenHolidayTag_provideHolidayColor() async throws {
        // given
        let viewModel = self.makeViewModel(info: self.holidayTagInfo)
        
        // when
        XCTAssertEqual(viewModel.originalName, "holiday")
        let originColor = try await viewModel.originalColorHex.firstValue(with: 1)
        XCTAssertEqual(originColor, "holiday")
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    func testViewModel_whenHoliday_changeColor() async throws {
        // given
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        
        // when
        XCTAssertEqual(viewModel.originalName, "default")
        let originColor = try await viewModel.originalColorHex.firstValue(with: 1)
        XCTAssertEqual(originColor, "default")
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    // 색장 변경
    func testViewModel_whenDefaultTag_provideDefaultTagColor() {
        // given
        let expect = expectation(description: "wait changed")
        let viewModel = self.makeViewModel(info: self.holidayTagInfo)
        self.stubUISettingUsecase.didDetaulEventTagColorChangedCallback = { expect.fulfill() }
        
        // when
        viewModel.selectColor("new_color")
        viewModel.save()
        self.wait(for: [expect])
        
        // then
        XCTAssertEqual(self.stubUISettingUsecase.didChangeAppearanceSetting?.defaultTagColor.holiday, "new_color")
    }
    
    func testViewModel_whenDefaultTag_changeTagColor() {
        // given
        let expect = expectation(description: "wait changed")
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        self.stubUISettingUsecase.didDetaulEventTagColorChangedCallback = { expect.fulfill() }
        
        // when
        viewModel.selectColor("new_color")
        viewModel.save()
        self.wait(for: [expect])
        
        // then
        XCTAssertEqual(self.stubUISettingUsecase.didChangeAppearanceSetting?.defaultTagColor.default, "new_color")
    }
    
    func testViewModel_whenDefaultTagSaving_updateIsProcessing() {
        // given
        let expect = expectation(description: "wait is processing")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        
        // when
        let isProcessings = self.waitOutputs(expect, for: viewModel.isProcessing) {
            viewModel.selectColor("new_color")
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isProcessings, [false, true, false])
    }
}

extension EventTagDetailViewModelImpleTests {
    
    // update color
    func testViewModel_updateColor() {
        // given
        let expect = expectation(description: "선택생삭 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        
        // when
        let colors = self.waitOutputs(expect, for: viewModel.selectedColorHex) {
            viewModel.selectColor("new-color-1")
            viewModel.selectColor("new-color-2")
        }
        
        // then
        XCTAssertEqual(colors, [
            "old-hex", "new-color-1", "new-color-2"
        ])
    }
    
    // update isSavable
    func testViewModel_whenNameEnterAndColorSelected_updateSavable() {
        // given
        let expect = expectation(description: "custom tag 이름, 컬러 선택시에 저장가능여부 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: nil)
        
        // when
        let isSavables = self.waitOutputs(expect, for: viewModel.isSavable) {
            viewModel.enterName("new name")
            viewModel.selectColor("some")
            viewModel.enterName("")
        }
        
        // then
        XCTAssertEqual(isSavables, [false, true, false])
    }
    
    // delete custom tag
    func testViewModel_deleteTag() {
        // given
        let expect = expectation(description: "custom tag 삭제")
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventTag.remove::only_tag".localized() })
        }
        self.spyListener.didDeleted = { _ in expect.fulfill() }
        // when
        viewModel.delete()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(
            self.spyRouter.didShowToastWithMessage,
            "eventTag.removed::message".localized()
        )
        XCTAssertEqual(self.spyRouter.didShowActionSheetWith != nil, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
    
    // delete custom tag + fail
    func testViewModel_whenDeleteTagFail_showError() {
        // given
        let expect = expectation(description: "tag 삭제 실패시에 에러 출력")
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventTag.remove::only_tag".localized() })
        }
        self.stubActionFail()
        
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        viewModel.delete()
        
        // then
        self.wait(for: [expect], timeout: 0.1)
    }
    
    func testViewModel_whenDeleteTag_updateIsProcessing() {
        // given
        let expect = expectation(description: "wait is processing")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventTag.remove::only_tag".localized() })
        }
        
        // when
        let isProcessings = self.waitOutputs(expect, for: viewModel.isProcessing) {
            viewModel.delete()
        }
        
        // then
        XCTAssertEqual(isProcessings, [false, true, false])
    }
    
    func testViewModel_deleteTagWithEvents() {
        // given
        let expect = expectation(description: "tag 및 이벤트 삭제")
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventTag.remove::tag_and_evets".localized() })
        }
        self.spyListener.didDeleted = { _ in expect.fulfill() }
        
        // when
        viewModel.delete()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(
            self.spyRouter.didShowToastWithMessage,
            "eventTag.removed_with_events::message".localized()
        )
        XCTAssertEqual(self.spyRouter.didShowActionSheetWith != nil, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
    
    func testViewModel_whenDeleteTagWithEvents_updateIsProcessing() {
        // given
        let expect = expectation(description: "wait is processing")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.spyRouter.actionSheetSelectionMocking = {
            $0.actions.first(where: { $0.text == "eventTag.remove::tag_and_evets".localized() })
        }
        
        // when
        let isProcessings = self.waitOutputs(expect, for: viewModel.isProcessing) {
            viewModel.delete()
        }
        
        // then
        XCTAssertEqual(isProcessings, [false, true, false])
    }

    // save new tag
    func testViewModel_makeNewTag() {
        // given
        let expect = expectation(description: "새로운 tag 생성")
        let viewModel = self.makeViewModel(info: nil)
        self.spyListener.didCreated = { _ in expect.fulfill() }
        
        // when
        viewModel.enterName("new")
        viewModel.selectColor("some")
        viewModel.save()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
    // save new tag + fail
    func testViewModel_whenMakeNewTag_showError() {
        // given
        let expect = expectation(description: "새로운 tag 생성 실패시에 에러 출력")
        let viewModel = self.makeViewModel(info: nil)
        self.stubActionFail()
        
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        viewModel.enterName("new")
        viewModel.selectColor("some")
        viewModel.save()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_whenMakeNewTag_updateIsProcessing() {
        // given
        let expect = expectation(description: "새로운 tag 저장시에 처리중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: nil)
        
        // when
        let isProcessings = self.waitOutputs(expect, for: viewModel.isProcessing) {
            viewModel.enterName("new")
            viewModel.selectColor("some")
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isProcessings, [false, true, false])
    }
    
    // edit tag
    func testViewModel_editNewTag() {
        // given
        let expect = expectation(description: "tag 수정")
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.spyListener.didUpdated = { _ in expect.fulfill() }
        
        // when
        viewModel.enterName("new")
        viewModel.save()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
    // edit tag + fail
    func testViewModel_whenEditNewTag_showError() {
        // given
        let expect = expectation(description: "tag 수정 실패시에 에러 출력")
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.stubActionFail()
        
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        viewModel.enterName("new")
        viewModel.save()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_whenEditTag_updateIsProcessing() {
        // given
        let expect = expectation(description: "tag 수정시에 처리중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        
        // when
        let isProcessings = self.waitOutputs(expect, for: viewModel.isProcessing) {
            viewModel.enterName("new")
            viewModel.save()
        }
        
        // then
        XCTAssertEqual(isProcessings, [false, true, false])
    }
}


private class SpyRouter: BaseSpyRouter, EventTagDetailRouting, @unchecked Sendable {
    
}

private class SpyListener: EventTagDetailSceneListener, @unchecked Sendable {
    
    var didCreated: ((any EventTag) -> Void)?
    func eventTag(created newTag: any EventTag) {
        self.didCreated?(newTag)
    }
    
    var didDeleted: ((EventTagId) -> Void)?
    func eventTag(deleted tagId: EventTagId) {
        self.didDeleted?(tagId)
    }
    
    var didUpdated: ((any EventTag) -> Void)?
    func eventTag(updated newTag: any EventTag) {
        self.didUpdated?(newTag)
    }
}
