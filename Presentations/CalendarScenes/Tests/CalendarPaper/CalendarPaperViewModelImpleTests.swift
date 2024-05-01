//
//  CalendarPaperViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 2023/09/02.
//

import XCTest
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


class CalendarPaperViewModelImpleTests: BaseTestCase {
    
    private var spyRouter: SpyRouter!
    private var spyMonthInteractor: SpyMonthSceneInteractor!
    private var spyEventListInteractor: SpyEventInteractor!
    
    override func setUpWithError() throws {
        self.spyRouter = .init()
        self.spyMonthInteractor = .init()
        self.spyEventListInteractor = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyRouter = nil
        self.spyMonthInteractor = nil
        self.spyEventListInteractor = nil
    }
    
    private func makeViewModel() -> CalendarPaperViewModelImple {
        
        let viewModel = CalendarPaperViewModelImple(
            month: .init(year: 2023, month: 9),
            monthInteractor: self.spyMonthInteractor,
            eventListInteractor: self.spyEventListInteractor
        )
        viewModel.router = self.spyRouter
        viewModel.prepare()
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
        XCTAssertEqual(self.spyMonthInteractor.updatedMonths, months)
    }
    
    func testViewModel_updateCurrentSelectedDay() {
        // given
        let viewModel = self.makeViewModel()
        let days: [CurrentSelectDayModel] = [
            .init(2023, 9, 10, weekId: "week1", range: 0..<10),
            .init(2023, 9, 11, weekId: "week2", range: 10..<20)
        ]
        
        // when
        days.forEach {
            viewModel.monthScene(didChange: $0, and: [])
        }
        
        // then
        XCTAssertEqual(self.spyEventListInteractor.selectedDays, days)
    }
}


extension CalendarPaperViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, CalendarPaperRouting, @unchecked Sendable {
    }
    
    private class SpyMonthSceneInteractor: MonthSceneInteractor {
        
        var updatedMonths: [CalendarMonth] = []
        func updateMonthIfNeed(_ newMonth: CalendarMonth) {
            self.updatedMonths.append(newMonth)
        }
    }
    
    private class SpyEventInteractor: DayEventListSceneInteractor {
        
        var selectedDays: [CurrentSelectDayModel] = []
        var selectedDayEvents: [[any CalendarEvent]] = []
        func selectedDayChanaged(_ newDay: CurrentSelectDayModel, and eventThatDay: [any CalendarEvent]) {
            self.selectedDays.append(newDay)
            self.selectedDayEvents.append(eventThatDay)
        }
    }
}
