//
//  MainViewModelImpleTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 2023/08/27.
//

import XCTest
import Combine
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import TodoCalendarApp


class MainViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    private var spyRouter: SpyRouter!
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.spyRouter = .init()
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyRouter = nil
        self.cancelBag = nil
    }
    
    private func makeViewModel() -> MainViewModelImple {
        let expect = expectation(description: "wait until attached")
        let viewModel = MainViewModelImple()
        viewModel.router = self.spyRouter
        self.spyRouter.didCalendarAttached = {
            expect.fulfill()
        }
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        return viewModel
    }
}

extension MainViewModelImpleTests {
    
    func testViewModel_whenFocusChanged_updateCurrentMonth() {
        // given
        let expect = expectation(description: "update current month")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let months = self.waitOutputs(expect, for: viewModel.currentMonth) {
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentMonth: true)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentMonth: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 10), isCurrentMonth: false)
        }
        
        // then
        XCTAssertEqual(months, ["8", "9", "10"])
    }
    
    func testViewModle_whenFocusChanged_updateIsShowReturnToToday() {
        // given
        let expect = expectation(description: "update is show today")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isShow = self.waitOutputs(expect, for: viewModel.isShowReturnToToday) {
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentMonth: true)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentMonth: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 10), isCurrentMonth: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentMonth: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentMonth: true)
        }
        
        // then
        XCTAssertEqual(isShow, [false, true, false])
    }
    
    // request return to today
    func testViewModel_requestReturnToToday() {
        // given
        let expect = expectation(description: "wait-return to today show")
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.isShowReturnToToday) {
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentMonth: false)
        }
        viewModel.returnToToday()
        
        // then
        XCTAssertEqual(self.spyRouter.interactor.didFocusMovedToToday, true)
    }
     
    func testViewModel_rouetToEventTypeSettingScene() {
        // given
        let expect = expectation(description: "이벤트 타입 세팅 화면으로 이동")
        let viewModel = self.makeViewModel()
        self.spyRouter.didRouteToEventTypeFilterSetting = {
            expect.fulfill()
        }
        
        // when
        viewModel.moveToEventTypeFilterSetting()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_routeToSettingScene() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.moveToSetting()
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToSetting, true)
    }
}


extension MainViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, MainRouting, @unchecked Sendable {
        
        var interactor = SpyCalendarInteractor()
        var didCalendarAttached: (() -> Void)?
        func attachCalendar() -> (any CalendarSceneInteractor)? {
            self.didCalendarAttached?()
            return self.interactor
        }
        
        var didRouteToEventTypeFilterSetting: (() -> Void)?
        func routeToEventTypeFilterSetting() {
            self.didRouteToEventTypeFilterSetting?()
        }
        
        var didRouteToSetting: Bool?
        func routeToSettingScene() {
            self.didRouteToSetting = true
        }
    }
    
    private class SpyCalendarInteractor: CalendarSceneInteractor, @unchecked Sendable {
        
        var didFocusMovedToToday: Bool?
        func moveFocusToToday() {
            self.didFocusMovedToToday = true
        }
    }
}
