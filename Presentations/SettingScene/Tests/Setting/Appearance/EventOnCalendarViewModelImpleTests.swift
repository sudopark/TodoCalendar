//
//  EventOnCalendarViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 12/16/23.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import SettingDomainInterface

@testable import SettingScene
import SettingDomainTesting


class EventOnCalendarViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyUISettingUsecase: StubUISettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyUISettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyUISettingUsecase = nil
    }
    
    private var dummySetting: EventOnCalendarAppearanceSetting {
        return .init(
            eventOnCalenarTextAdditionalSize: 3,
            eventOnCalendarIsBold: false,
            eventOnCalendarShowEventTagColor: true,
            weekRowHeight: .medium,
            monthAutoCollapseIsOn: false
        )
    }
    
    private func makeViewModel(
        setting: EventOnCalendarAppearanceSetting? = nil
    ) -> EventOnCalendarViewModelImple {
        return EventOnCalendarViewModelImple(
            setting: setting ?? self.dummySetting,
            uiSettingUsecase: self.spyUISettingUsecase
        )
    }
    
    private func makeViewModelWithSavedMonthAutoCollapseOn() -> EventOnCalendarViewModelImple {
        _ = try? self.spyUISettingUsecase.changeCalendarAppearanceSetting(
            .init() |> \.monthAutoCollapseIsOn .~ true
        )
        let saved = self.spyUISettingUsecase.loadSavedAppearanceSetting().calendar
        return self.makeViewModel(setting: .init(saved))
    }
}


extension EventOnCalendarViewModelImpleTests {
    
    // prepare시에 마지막에 저장된 설정 로드 - size:+3
    func testViewModel_whenPrepare_provideLastSaveFontSize() {
        // given
        let expect = expectation(description: "prepare시에 마지막에 저장된 설정 로드 - size:+3")
        let viewModel = self.makeViewModel()
        
        // when
        let sizeModel = self.waitFirstOutput(expect, for: viewModel.textIncreasedSizeText) {
        }
        
        // then
        XCTAssertEqual(sizeModel?.sizeText, "+3")
        XCTAssertEqual(sizeModel?.isIncreasable, true)
        XCTAssertEqual(sizeModel?.isDescreasable, true)
    }
    
    // prepare시에 마지막에 저장된 설정 로드 - bold: false
    func testViewModel_whenPrepare_provideLatestIsBold() {
        // given
        let expect = expectation(description: "prepare시에 마지막에 저장된 설정 로드 - bold: false")
        let viewModel = self.makeViewModel()
        
        // when
        let isBold = self.waitFirstOutput(expect, for: viewModel.isBoldTextOnCalendar) {
        }
        
        // then
        XCTAssertEqual(isBold, false)
    }
    
    // prepare시에 마지막에 저장된 설정 로드 - show color: true
    func testViewModel_whenPrepare_provideLatestIsShowEventColor() {
        // given
        let expect = expectation(description: "prepare시에 마지막에 저장된 설정 로드 - show color: true")
        let viewModel = self.makeViewModel()
        
        // when
        let isShow = self.waitFirstOutput(expect, for: viewModel.showEvnetTagColor) {
        }
        
        // then
        XCTAssertEqual(isShow, true)
    }
    
    func testViewModel_whenPrepare_provideLatestRowHeight() {
        // given
        let expect = expectation(description: "prepare시에 마지막에 저장된 설정 로드 - row height: medium")
        let viewModel = self.makeViewModel()
        
        // when
        let height = self.waitFirstOutput(expect, for: viewModel.rowHeight)
        
        // then
        XCTAssertEqual(height?.height, .medium)
    }
    
    func testViewModel_whenPrepare_provideLatestIsMonthAutoCollapseOn() {
        // given
        let expect = expectation(description: "prepare시에 마지막에 저장된 설정 로드 - month auto collapse: true")
        let saved = CalendarAppearanceSettings(colorSetKey: .defaultLight, fontSetKey: .systemDefault)
            |> \.monthAutoCollapseIsOn .~ true
        let viewModel = self.makeViewModel(setting: .init(saved))
        
        // when
        let isOn = self.waitFirstOutput(expect, for: viewModel.isMonthAutoCollapseOn)
        
        // then
        XCTAssertEqual(isOn, true)
    }
    
    // font size 증가하다 끝까지(+7 max)
    func testViewModel_increaseFontSizeUntilMax() {
        // given
        let expect = expectation(description: "font size 증가하다 끝까지(+7 max)")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.textIncreasedSizeText, timeout: 0.1) {
            viewModel.increaseTextSize() // 4
            viewModel.increaseTextSize() // 5
            viewModel.increaseTextSize() // 6
            viewModel.increaseTextSize() // 7
            viewModel.increaseTextSize() // ignore
        }
        
        // then
        let texts = models.map { $0.sizeText }
        let isIncreasable = models.map { $0.isIncreasable }
        let isDecreasable = models.map { $0.isDescreasable }
        XCTAssertEqual(texts, ["+3", "+4", "+5", "+6", "+7"])
        XCTAssertEqual(isIncreasable, [true, true, true, true, false])
        XCTAssertEqual(isDecreasable, [true, true, true, true, true])
    }
    
    // font size 감소하다 끝까지 (-2 min)
    func testViewModel_decreaseFontSizeUntilMin() {
        // given
        let expect = expectation(description: "font size 감소하다 끝까지 (-2 min)")
        expect.expectedFulfillmentCount = 6
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.textIncreasedSizeText) {
            viewModel.decreaseTextSize() // 2
            viewModel.decreaseTextSize() // 1
            viewModel.decreaseTextSize() // 0
            viewModel.decreaseTextSize() // -1
            viewModel.decreaseTextSize() // -2
            viewModel.decreaseTextSize() // ignore
        }
        
        // then
        let texts = models.map { $0.sizeText }
        let isIncreasable = models.map { $0.isIncreasable }
        let isDecreasable = models.map { $0.isDescreasable }
        XCTAssertEqual(texts, ["+3", "+2", "+1", "±0", "-1", "-2"])
        XCTAssertEqual(isIncreasable, [true, true, true, true, true, true])
        XCTAssertEqual(isDecreasable, [true, true, true, true, true, false])
    }
    
    // font size 변경시에 변경값 저장
    func testViewModel_whenAfterChangeFontSize_notify() {
        // given
        let expect = expectation(description: "font size 변경시에 변경값 저장")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitOutputs(expect, for: viewModel.textIncreasedSizeText) {
            viewModel.increaseTextSize()
        }
        let setting = self.spyUISettingUsecase.loadSavedAppearanceSetting().calendar
        
        // then
        XCTAssertEqual(setting.eventOnCalenarTextAdditionalSize, 4)
    }
    
    // bold 여부 업데이트
    func testViewModel_updateIsBold() {
        // given
        let expect = expectation(description: "bold 여부 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isBolds = self.waitOutputs(expect, for: viewModel.isBoldTextOnCalendar) {
            viewModel.toggleBoldText(true)
        }
        
        // then
        XCTAssertEqual(isBolds, [false, true])
        let setting = self.spyUISettingUsecase.loadSavedAppearanceSetting().calendar
        XCTAssertEqual(setting.eventOnCalendarIsBold, true)
    }
    
    // showEvent color toggle
    func testViewModel_updateShowIsEventColor() {
        // given
        let expect = expectation(description: "showEvent color toggle")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.showEvnetTagColor) {
            viewModel.toggleShowEventTagColor(false)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false])
        let setting = self.spyUISettingUsecase.loadSavedAppearanceSetting().calendar
        XCTAssertEqual(setting.eventOnCalendarShowEventTagColor, false)
    }
    
    func testViewModel_updateRowHeight() {
        // given
        let expect = expectation(description: "rowHeight 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let heights = self.waitOutputs(expect, for: viewModel.rowHeight) {
            viewModel.selectRowHeightOnCalendar(.large)
            viewModel.selectRowHeightOnCalendar(.small)
        }
        
        // then
        XCTAssertEqual(heights.map { $0.height }, [.medium, .large, .small])
    }
    
    func testViewModel_updateMonthAutoCollapse() {
        // given
        let expect = expectation(description: "month auto collapse 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.isMonthAutoCollapseOn) {
            viewModel.toggleMonthAutoCollapse(true)
        }
        
        // then
        XCTAssertEqual(isOns, [false, true])
        let setting = self.spyUISettingUsecase.loadSavedAppearanceSetting().calendar
        XCTAssertEqual(setting.monthAutoCollapseIsOn, true)
    }
    
    func testViewModel_whenOtherSettingChanged_notRepeatMonthAutoCollapse() {
        // given
        let expect = expectation(description: "다른 설정이 바뀌어도 자동 접기 값은 다시 방출하지 않음")
        let viewModel = self.makeViewModel()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.isMonthAutoCollapseOn) {
            viewModel.toggleBoldText(true)
        }
        
        // then
        XCTAssertEqual(isOns, [false])
    }
    
    func testViewModel_whenToggleMonthAutoCollapseToSameValue_notSave() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.toggleMonthAutoCollapse(false)
        
        // then
        XCTAssertNil(self.spyUISettingUsecase.didChangeAppearanceSetting)
    }
    
    func testViewModel_whenRowHeightIsSmall_monthAutoCollapseNotEditable() {
        // given
        let expect = expectation(description: "행 높이가 small 이면 자동 접기를 바꿀 수 없음")
        let setting = EventOnCalendarAppearanceSetting(
            eventOnCalenarTextAdditionalSize: 0,
            eventOnCalendarIsBold: false,
            eventOnCalendarShowEventTagColor: true,
            weekRowHeight: .small,
            monthAutoCollapseIsOn: false
        )
        let viewModel = self.makeViewModel(setting: setting)
        
        // when
        let isEditable = self.waitFirstOutput(expect, for: viewModel.isMonthAutoCollapseEditable)
        
        // then
        XCTAssertEqual(isEditable, false)
    }
    
    func testViewModel_whenRowHeightChanged_updateMonthAutoCollapseEditable() {
        // given
        let expect = expectation(description: "행 높이가 바뀌면 자동 접기 변경 가능 여부도 바뀜")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isEditables = self.waitOutputs(expect, for: viewModel.isMonthAutoCollapseEditable) {
            viewModel.toggleBoldText(true)
            viewModel.selectRowHeightOnCalendar(.small)
            viewModel.selectRowHeightOnCalendar(.large)
        }
        
        // then
        XCTAssertEqual(isEditables, [true, false, true])
    }
    
    func testViewModel_whenRowHeightChangedToSmall_keepMonthAutoCollapseValue() {
        // given
        let expect = expectation(description: "행 높이가 small 로 바뀌어도 자동 접기 값은 그대로")
        let viewModel = self.makeViewModelWithSavedMonthAutoCollapseOn()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.isMonthAutoCollapseOn) {
            viewModel.selectRowHeightOnCalendar(.small)
        }
        
        // then
        XCTAssertEqual(isOns, [true])
        let setting = self.spyUISettingUsecase.loadSavedAppearanceSetting().calendar
        XCTAssertEqual(setting.rowHeight, .small)
        XCTAssertEqual(setting.monthAutoCollapseIsOn, true)
    }
}
