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
import Extensions
import UnitTestHelpKit

@testable import SettingScene
import SettingDomainTesting


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
    
    private func dummySetting(showRokuyo: Bool) -> EventListAppearanceSetting {
        return .init(
            eventTextAdditionalSize: 3,
            showHoliday: true,
            showLunarCalendarDate: true,
            is24hourForm: true,
            showUncompletedTodos: true,
            showRokuyo: showRokuyo
        )
    }
    
    private func makeViewModel(showRokuyo: Bool = true) -> EventListAppearnaceSettingViewModelImple {
    
        let viewModel = EventListAppearnaceSettingViewModelImple(
            setting: self.dummySetting(showRokuyo: showRokuyo),
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
            
            viewModel.increaseFontSize()
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.calendar.eventTextAdditionalSize, 4)
    }
    
    // holiday 이름 표시 여부 토글
    func testViewModel_toggleShowHolidayName() {
        // given
        let expect = expectation(description: "holiday 이름 표시 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowHolidayName) {
            
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
            
            viewModel.toggleShowHolidayName(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.calendar.showHoliday, false)
    }
    
    // 음력 표시여부 토글
    func testViewModel_toggleShowLunarCalendarDate() {
        // given
        let expect = expectation(description: "음력 표시여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowLunarCalendarDate) {
            
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
            viewModel.toggleShowLunarCalendarDate(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.calendar.showLunarCalendarDate, false)
    }
    
    // 로쿠요 표시여부 토글
    func testViewModel_toggleShowRokuyo() {
        // given
        let expect = expectation(description: "로쿠요 표시여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowRokuyo) {
            
            viewModel.toggleShowRokuyo(false)
            viewModel.toggleShowRokuyo(true)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false, true])
    }
    
    func testViewModel_whenAfterToggleShowRokuyo_saveUpdates() {
        // given
        let expect = expectation(description: "로쿠요 표시여부 토글 이후에 변경사항 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.isShowRokuyo) {
            viewModel.toggleShowRokuyo(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.calendar.showRokuyo, false)
    }
    
    func testViewModel_whenShowRokuyo_sampleModelRokuyoFollowsSupport() {
        // given
        let expectOn = expectation(description: "로쿠요를 켠 샘플")
        let expectOff = expectation(description: "로쿠요를 끈 샘플")
        let isDangiAvailable: Bool
        if #available(iOS 26, *) { isDangiAvailable = true } else { isDangiAvailable = false }
        let viewModelShowingRokuyo = self.makeViewModel(showRokuyo: true)
        let viewModelHidingRokuyo = self.makeViewModel(showRokuyo: false)
        
        // when
        let sampleShowingRokuyo = self.waitFirstOutput(expectOn, for: viewModelShowingRokuyo.eventListSamepleModel)
        let sampleHidingRokuyo = self.waitFirstOutput(expectOff, for: viewModelHidingRokuyo.eventListSamepleModel)
        
        // then
        XCTAssertEqual(viewModelShowingRokuyo.isRokuyoSupported, isDangiAvailable)
        XCTAssertEqual(sampleShowingRokuyo?.rokuyo != nil, isDangiAvailable)
        XCTAssertNil(sampleHidingRokuyo?.rokuyo)
    }
    
    // 24시 포맷으로 출력 여부 토글
    func testViewModel_toggle24HourForm() {
        // given
        let expect = expectation(description: "24시 포맷으로 출력 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.isShowTimeWith24HourForm) {
            
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
            viewModel.toggleIsShowTimeWith24HourForm(false)
        }
        
        // then
        XCTAssertEqual(self.spyUsecase.didChangeAppearanceSetting?.calendar.is24hourForm, false)
    }
    
    func testViewModel_toggleUncompletedTodos() {
        // given
        let expect = expectation(description: "완료되지않은 할일 노출여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.showUncompletedTodo) {
            viewModel.toggleShowUncompletedTodos(false)
            viewModel.toggleShowUncompletedTodos(true)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false, true])
    }
}


// MARK: - 미리보기 음력 날짜

extension EventListAppearnaceSettingViewModelTests {

    func testSampleModel_showsLunarDateWithGivenLunarCalendar() {
        // given
        let gregorian = Calendar(identifier: .gregorian)
        let christmas = gregorian.dateBySetting(from: Date()) { $0.month = 12; $0.day = 25 }!
        let chineseFormatter = DateFormatter()
            |> \.dateFormat .~ "date_form::MM_dd".localized()
            |> \.calendar .~ Calendar(identifier: .chinese)

        // when
        let model = EventListAppearanceSampleModel(self.dummySetting(showRokuyo: false), lunarCalendar: .chinese)

        // then
        XCTAssertEqual(model?.lunarDateText, "🌕 \(chineseFormatter.string(from: christmas))")
        XCTAssertNotEqual(model?.lunarDateText, "12/25")
    }
}
