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
    private var spyListner: SpyCalendarPaperSceneListener!
    
    override func setUpWithError() throws {
        self.spyRouter = .init()
        self.spyMonthInteractor = .init()
        self.spyEventListInteractor = .init()
        self.spyListner = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyRouter = nil
        self.spyMonthInteractor = nil
        self.spyEventListInteractor = nil
        self.spyListner = nil
    }
    
    private func makeViewModel() -> CalendarPaperViewModelImple {
        
        let viewModel = CalendarPaperViewModelImple(
            month: .init(year: 2023, month: 9),
            monthInteractor: self.spyMonthInteractor,
            eventListInteractor: self.spyEventListInteractor
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListner
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
    
    func testViewModel_whenCurrentSelectedDayUpdates_notify() {
        // given
        let viewModel = self.makeViewModel()
        let month = CalendarMonth(year: 2023, month: 02)
        let day10 = CurrentSelectDayModel(2023, 02, 10, weekId: "some", range: 0..<0)
        let day11 = CurrentSelectDayModel(2023, 02, 11, weekId: "some", range: 0..<0)
        
        // when
        viewModel.updateMonthIfNeed(month)
        viewModel.monthScene(didChange: day10, and: [])
        viewModel.monthScene(didChange: day11, and: [])
        
        // then
        XCTAssertEqual(self.spyListner.didChangeSelectedDay.map { $0.0 }, [
            month, month
        ])
        XCTAssertEqual(self.spyListner.didChangeSelectedDay.map { $0.1.day }, [
            10, 11
        ])
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
    
    private final class SpyCalendarPaperSceneListener: CalendarPaperSceneListener {
        
        var didChangeSelectedDay: [(CalendarMonth, CurrentSelectDayModel)] = []
        func calendarPaper(on month: CalendarMonth, didChange selectedDay: CurrentSelectDayModel) {
            self.didChangeSelectedDay.append((month, selectedDay))
        }
    }
}
