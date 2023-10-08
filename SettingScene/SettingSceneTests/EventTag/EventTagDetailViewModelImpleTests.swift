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
        return .init(id: .custom("some"), name: "custom", color: .custom(hex: "old-hex"))
    }
    
    private var holidayTagInfo: OriginalTagInfo {
        return .init(id: .holiday, name: "holiday", color: .holiday)
    }
    
    private var defaultTagInfo: OriginalTagInfo {
        return .init(id: .default, name: "default", color: .default)
    }
}

extension EventTagDetailViewModelImpleTests {
    
    // holiday => original info + deletable
    func testViewModel_provideInfosForHolidayTag() {
        // given
        let viewModel = self.makeViewModel(info: self.holidayTagInfo)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, "holiday")
        XCTAssertEqual(viewModel.originalColor, .holiday)
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    // default => original info  + deletable
    func testViewModel_provideInfosForDefaultTag() {
        // given
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, "default")
        XCTAssertEqual(viewModel.originalColor, .default)
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    // custom => original info  + deletable
    func testViewModel_provideInfoForCustomTag() {
        // given
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, "custom")
        XCTAssertEqual(viewModel.originalColor, .custom(hex: "old-hex"))
        XCTAssertEqual(viewModel.isDeletable, true)
        XCTAssertEqual(viewModel.isNameChangable, true)
    }
    
    // make case
    func testViewModel_provideInfoForMakeCase() {
        // given
        let viewModel = self.makeViewModel(info: nil)
        
        // when + then
        XCTAssertEqual(viewModel.originalName, nil)
        XCTAssertEqual(viewModel.originalColor, .default)
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, true)
    }
}


// MARK: -  holiday or default 일때

extension EventTagDetailViewModelImpleTests {
    
    // 색상정보 제공
    func testViewModel_whenHolidayTag_provideHolidayColor() {
        // given
        let viewModel = self.makeViewModel(info: self.holidayTagInfo)
        
        // when
        XCTAssertEqual(viewModel.originalName, "holiday")
        XCTAssertEqual(viewModel.originalColor, .holiday)
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    func testViewModel_whenHoliday_changeColor() {
        // given
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        
        // when
        XCTAssertEqual(viewModel.originalName, "default")
        XCTAssertEqual(viewModel.originalColor, .default)
        XCTAssertEqual(viewModel.isDeletable, false)
        XCTAssertEqual(viewModel.isNameChangable, false)
    }
    
    // 색장 변경
    func testViewModel_whenDefaultTag_provideDefaultTagColor() {
        // given
        let viewModel = self.makeViewModel(info: self.holidayTagInfo)
        
        // when
        viewModel.selectColor("new_color")
        viewModel.save()
        
        // then
        XCTAssertEqual(self.stubUISettingUsecase.didChangeAppearanceSetting?.tagColorSetting.holiday, "new_color")
    }
    
    func testViewModel_whenDefaultTag_changeTagColor() {
        // given
        let viewModel = self.makeViewModel(info: self.defaultTagInfo)
        
        // when
        viewModel.selectColor("new_color")
        viewModel.save()
        
        // then
        XCTAssertEqual(self.stubUISettingUsecase.didChangeAppearanceSetting?.tagColorSetting.default, "new_color")
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
        let colors = self.waitOutputs(expect, for: viewModel.selectedColor) {
            viewModel.selectColor("new-color-1")
            viewModel.selectColor("new-color-2")
        }
        
        // then
        XCTAssertEqual(colors, [
            .custom(hex: "old-hex"), .custom(hex: "new-color-1"), .custom(hex: "new-color-2")
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
        self.spyListener.didDeleted = { _ in expect.fulfill() }
        // when
        viewModel.delete()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
        XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
    
    // delete custom tag + fail
    func testViewModel_whenDeleteTagFail_showError() {
        // given
        let expect = expectation(description: "tag 삭제 실패시에 에러 출력")
        let viewModel = self.makeViewModel(info: self.customTagInfo)
        self.stubActionFail()
        
        self.spyRouter.didShowErrorCallback = { _ in expect.fulfill() }
        
        // when
        viewModel.delete()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
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
}


private class SpyRouter: BaseSpyRouter, EventTagDetailRouting, @unchecked Sendable {
    
}

private class SpyListener: EventTagDetailSceneListener {
    
    var didCreated: ((EventTag) -> Void)?
    func eventTag(created newTag: EventTag) {
        self.didCreated?(newTag)
    }
    
    var didDeleted: ((String) -> Void)?
    func evetTag(deleted tagId: String) {
        self.didDeleted?(tagId)
    }
    
    var didUpdated: ((EventTag) -> Void)?
    func eventTag(updated newTag: EventTag) {
        self.didUpdated?(newTag)
    }
}
