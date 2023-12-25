//
//  EventListAppearnaceSettingViewModelTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 12/22/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class EventListAppearnaceSettingViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyUsecase: StubUISettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyUsecase = nil
    }
    
    private var dummySetting: EventListAppearanceSetting {
        return .init(eventTextAdditionalSize: 3, showHoliday: true, showLunarCalendarDate: true, is24hourForm: true, dimOnPastEvent: true)
    }
    
    private func makeViewModel() -> EventListAppearnaceSettingViewModelImple {
    
        let viewModel = EventListAppearnaceSettingViewModelImple(
            uiSettingUsecase: self.spyUsecase
        )
        return viewModel
    }
}


extension EventListAppearnaceSettingViewModelTests {
        
    // 최대, 최소 레벨까지 폰트사이즈 증가
    func testViewModel_changeFontSizeUpToLimit() {
        // given
        let expect = expectation(description: "최대, 최소 레벨까지 폰트사이즈 증가")
        expect.expectedFulfillmentCount = 10
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.eventFontIncreasedSizeModel) {
            viewModel.prepared(self.dummySetting) // 3
            viewModel.increaseFontSize()    // 4
            viewModel.increaseFontSize()    // ignore
            
            
            viewModel.decreaseFontSize()    // 3
            viewModel.decreaseFontSize()    // 2
            viewModel.decreaseFontSize()    // 1
            viewModel.decreaseFontSize()    // 0
            viewModel.decreaseFontSize()    // -1
            viewModel.decreaseFontSize()    // -2
            viewModel.decreaseFontSize()    // -3
            viewModel.decreaseFontSize()    // -4
            viewModel.decreaseFontSize()    // ignore
        }
        
        // then
        let texts = models.map { $0.sizeText }
        XCTAssertEqual(texts, [
            "+3", "+4", "+3", "+2", "+1", "±0", "-1", "-2", "-3", "-4"
        ])
        let isIncreasables = models.map { $0.isIncreasable }
        XCTAssertEqual(isIncreasables, [
            true, false, true, true, true, true, true, true, true, true
        ])
        let isDecreasables = models.map { $0.isDescreasable }
        XCTAssertEqual(isDecreasables, [
            true, true, true, true, true, true, true, true, true, false
        ])
    }
    
    // 폰트사이즈 변경시에 저장
    func testViewModel_whenAfterChangeFontSize_saveUpdates() {
        // given
        let expect = expectation(description: "폰트사이즈 변경시에 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.eventFontIncreasedSizeModel) {
            viewModel.prepared(self.dummySetting)
            viewModel.increaseFontSize()
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.eventTextAdditionalSize, 4)
    }
    
    // holiday 이름 표시 여부 토글
    func testViewModel_toggleShowHolidayName() {
        // given
        let expect = expectation(description: "holiday 이름 표시 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowHolidayName) {
            viewModel.prepared(self.dummySetting)
            
            viewModel.toggleShowHolidayName(false)
            viewModel.toggleShowHolidayName(true)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false, true])
    }
    
    func testViewModel_whenAfterToggleShowHoliday_saveUpdates() {
        // given
        let expect = expectation(description: "holiday 이름 표시 여부 토글 이후에 변경사항 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isShowHolidayName) {
            viewModel.prepared(self.dummySetting)
            viewModel.toggleShowHolidayName(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.showHoliday, false)
    }
    
    // 음력 표시여부 토글
    func testViewModel_toggleShowLunarCalendarDate() {
        // given
        let expect = expectation(description: "음력 표시여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowLunarCalendarDate) {
            viewModel.prepared(self.dummySetting)
            
            viewModel.toggleShowLunarCalendarDate(false)
            viewModel.toggleShowLunarCalendarDate(true)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false, true])
    }
    
    func testViewModel_whenAfterToggleShowLunarCalendarDate_saveUpdates() {
        // given
        let expect = expectation(description: "음력 표시여부 토글 이후에 변경사항 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isShowLunarCalendarDate) {
            viewModel.prepared(self.dummySetting)
            viewModel.toggleShowLunarCalendarDate(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.showLunarCalendarDate, false)
    }
    
    // 24시 포맷으로 출력 여부 토글
    func testViewModel_toggle24HourForm() {
        // given
        let expect = expectation(description: "24시 포맷으로 출력 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowTimeWith24HourForm) {
            viewModel.prepared(self.dummySetting)
            
            viewModel.toggleIsShowTimeWith24HourForm(false)
            viewModel.toggleIsShowTimeWith24HourForm(true)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false, true])
    }
    
    func testViewModel_whenAfterToggle24hourForm_saveUpdates() {
        // given
        let expect = expectation(description: "24시 포맷으로 출력 여부 토글 이후에 변경사항 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isShowTimeWith24HourForm) {
            viewModel.prepared(self.dummySetting)
            viewModel.toggleIsShowTimeWith24HourForm(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.is24hourForm, false)
    }
    
    // 지나간 이벤트 딤드처리 여부 토글
    func testViewModel_toggleDimedOnPastEvent() {
        // given
        let expect = expectation(description: "지나간 이벤트 딤드처리 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isDimOnPastEvent) {
            viewModel.prepared(self.dummySetting)
            
            viewModel.toggleDimOnPastEvent(false)
            viewModel.toggleDimOnPastEvent(true)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false, true])
    }
    
    func testViewModel_whenAfterToggleDimedOnPastEvent_saveUpdates() {
        // given
        let expect = expectation(description: "지나간 이벤트 딤드처리 여부 토글 이후에 변경사항 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isDimOnPastEvent) {
            viewModel.prepared(self.dummySetting)
            viewModel.toggleDimOnPastEvent(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.dimOnPastEvent, false)
    }
}
