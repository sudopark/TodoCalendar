//
//  CalendarPaperViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/09/02.
//

import XCTest
import Domain
import UnitTestHelpKit

@testable import CalendarScenes


class CalendarPaperViewModelImpleTests: BaseTestCase {
    
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyRouter = nil
    }
    
    private func makeViewModel() -> CalendarPaperViewModelImple {
        
        let expect = expectation(description: "wait listener attached")
        let viewModel = CalendarPaperViewModelImple(
            month: .init(year: 2023, month: 9)
        )
        viewModel.router = self.spyRouter
        self.spyRouter.didListenerAttached = {
            expect.fulfill()
        }
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        return viewModel
    }
}

extension CalendarPaperViewModelImpleTests {
    
    func testViewModel_updateMonth() {
        // given
        let viewModel = self.makeViewModel()
        let months: [CalendarMonth] = [
            .init(year: 2023, month: 09),
            .init(year: 2023, month: 10)
        ]
        
        // when
        months.forEach { m in
            viewModel.updateMonthIfNeed(m)
        }
        
        // then
        XCTAssertEqual(self.spyRouter.spyMonthInteractor.updatedMonths, months)
    }
    
    func testViewModel_updateCurrentSelectedDay() {
        // given
        let viewModel = self.makeViewModel()
        let days: [CurrentSelectDayModel] = [
            .init("day1", []),
            .init("day2", [])
        ]
        
        // when
        days.forEach {
            viewModel.monthScene(didChange: $0)
        }
        
        // then
        XCTAssertEqual(self.spyRouter.spyEventListInteractor.selectedDays, days)
    }
}


extension CalendarPaperViewModelImpleTests {
    
    private class SpyRouter: CalendarPaperRouting, @unchecked Sendable {
        
        var didListenerAttached: (() -> Void)?
        let spyMonthInteractor: SpyMonthSceneInteractor = .init()
        let spyEventListInteractor: SpyEventInteractor = .init()
        func attachMonthAndEventList(_ month: CalendarMonth) -> (
            MonthSceneInteractor?,
            DayEventListSceneInteractor?
        )? {
            self.didListenerAttached?()
            return (spyMonthInteractor, spyEventListInteractor)
        }
    }
    
    private class SpyMonthSceneInteractor: MonthSceneInteractor {
        
        var updatedMonths: [CalendarMonth] = []
        func updateMonthIfNeed(_ newMonth: CalendarMonth) {
            self.updatedMonths.append(newMonth)
        }
    }
    
    private class SpyEventInteractor: DayEventListSceneInteractor {
        
        var selectedDays: [CurrentSelectDayModel] = []
        func selectedDayChanaged(_ newDay: CurrentSelectDayModel) {
            self.selectedDays.append(newDay)
        }
    }
}
