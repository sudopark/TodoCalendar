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
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


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
    
    private func makeViewModel() -> EventOnCalendarViewModelImple {
        self.spyUISettingUsecase.stubAppearanceSetting = .init(
            tagColorSetting: .init(holiday: "some", default: "default"),
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault,
            accnetDayPolicy: [:],
            showUnderLineOnEventDay: false,
            eventOnCalendar: EventOnCalendarSetting()
                |> \.textAdditionalSize .~ 3
                |> \.bold .~ false
                |> \.showEventTagColor .~ true,
            eventList: .init()
        )
        return EventOnCalendarViewModelImple(uiSettingUsecase: self.spyUISettingUsecase)
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
            viewModel.prepare()
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
            viewModel.prepare()
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
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(isShow, true)
    }
    
    // font size 증가하다 끝까지(+7 max)
    func testViewModel_increaseFontSizeUntilMax() {
        // given
        let expect = expectation(description: "font size 증가하다 끝까지(+7 max)")
        expect.expectedFulfillmentCount = 5
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.textIncreasedSizeText) {
            viewModel.prepare() // 3
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
            viewModel.prepare() // 3
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
            viewModel.prepare()
            viewModel.increaseTextSize()
        }
        let setting = self.spyUISettingUsecase.loadAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.eventOnCalendar.textAdditionalSize, 4)
    }
    
    // bold 여부 업데이트
    func testViewModel_updateIsBold() {
        // given
        let expect = expectation(description: "bold 여부 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isBolds = self.waitOutputs(expect, for: viewModel.isBoldTextOnCalendar) {
            viewModel.prepare()
            viewModel.toggleBoldText(true)
        }
        
        // then
        XCTAssertEqual(isBolds, [false, true])
        let setting = self.spyUISettingUsecase.loadAppearanceSetting()
        XCTAssertEqual(setting.eventOnCalendar.bold, true)
    }
    
    // showEvent color toggle
    func testViewModel_updateShowIsEventColor() {
        // given
        let expect = expectation(description: "showEvent color toggle")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let isShows = self.waitOutputs(expect, for: viewModel.showEvnetTagColor) {
            viewModel.prepare()
            viewModel.toggleShowEventTagColor(false)
        }
        
        // then
        XCTAssertEqual(isShows, [true, false])
        let setting = self.spyUISettingUsecase.loadAppearanceSetting()
        XCTAssertEqual(setting.eventOnCalendar.showEventTagColor, false)
    }
}
