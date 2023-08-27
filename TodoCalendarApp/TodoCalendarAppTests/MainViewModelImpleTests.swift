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
        
}


extension MainViewModelImpleTests {
    
    private class SpyRouter: MainRouting, @unchecked Sendable {
        
        var interactor = SpyCalendarInteractor()
        var didCalendarAttached: (() -> Void)?
        func attachCalendar() -> CalendarSceneInteractor? {
            self.didCalendarAttached?()
            return self.interactor
        }
    }
    
    private class SpyCalendarInteractor: CalendarSceneInteractor, @unchecked Sendable {
        
        var didFocusMovedToToday: Bool?
        func moveFocusToToday() {
            self.didFocusMovedToToday = true
        }
    }
}
