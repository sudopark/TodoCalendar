//
//  AppearanceSettingViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 12/23/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class AppearanceSettingViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubCalendarSettingUsecase: StubCalendarSettingUsecase!
    private var stubUISettingUsecase: StubUISettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.stubCalendarSettingUsecase = .init()
        self.stubUISettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.stubCalendarSettingUsecase = nil
        self.stubUISettingUsecase = nil
    }
    
    private func makeViewModel(_ isSystemTimeZone: Bool = false) -> AppearanceSettingViewModelImple {
        
        let timeZone = isSystemTimeZone ? TimeZone.current : TimeZone(abbreviation: "CST")!
        self.stubCalendarSettingUsecase.selectTimeZone(timeZone)
        
        let setting = CalendarAppearanceSettings(colorSetKey: .defaultLight, fontSetKey: .systemDefault)
            |> \.hapticEffectIsOn .~ true
            |> \.animationEffectIsOn .~ false
        
        let viewModel = AppearanceSettingViewModelImple(
            setting: setting,
            calendarSettingUsecase: self.stubCalendarSettingUsecase,
            uiSettingUsecase: self.stubUISettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension AppearanceSettingViewModelImpleTests {
    
    // 현재 타임존 정보 반환
    func testViewModel_provideCurrentTimeZone() {
        // given
        let expect = expectation(description: "현재 타임존 정보 반환")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel(true)
        
        // when
        let names = self.waitOutputs(expect, for: viewModel.currentTimeZoneName) {
            self.stubCalendarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "CST")!)
        }
        
        // then
        let isSystemTimeZoneName = names.map { $0 == "setting.timezone::systemTime::name".localized() }
        XCTAssertEqual(isSystemTimeZoneName, [true, false])
    }
    
    // 타임존 선택 화면으로 이동
    func testViewModel_routeToSelectTimeZone() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.routeToSelectTimezone()
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToSelectTimeZone, true)
    }
    
    // 햅틱 피드백 여부 토글
    func testViewModel_toggleIsHapticFeedbackOn() {
        // given
        let expect = expectation(description: "햅틱 피드백 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.hapticIsOn) {
            
            viewModel.toggleIsOnHapticFeedback(false)
            
            viewModel.toggleIsOnHapticFeedback(true)
        }
        
        // then
        XCTAssertEqual(isOns, [true, false, true])
    }
    
    // 에니메이션 줄이기 여부 토글
    func testViewModel_toggleAnimationEffectIsOn() {
        // given
        let expect = expectation(description: "에니메이션 줄이기 여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.animationIsOn) {
            
            viewModel.toggleMinimizeAnimationEffect(true)
            
            viewModel.toggleMinimizeAnimationEffect(false)
        }
        
        // then
        XCTAssertEqual(isOns, [false, true, false])
    }
}


private class SpyRouter: BaseSpyRouter, AppearanceSettingRouting, @unchecked Sendable {
    
    var didRouteToSelectTimeZone: Bool?
    func routeToSelectTimeZone() {
        self.didRouteToSelectTimeZone = true
    }
}
