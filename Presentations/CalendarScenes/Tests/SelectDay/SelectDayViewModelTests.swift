//
//  SelectDayViewModelTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 3/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Scenes
import TestDoubles
import UnitTestHelpKit

@testable import CalendarScenes


struct SelectDayViewModelTests {
    
    private let spyRouter: SpyRouter = .init()
    private let spyListener: SpyListener = .init()
    
    private func makeViewModel(
    ) -> SelectDayDialogViewModelImple {
        let current = Dummies.currentDay.day
        let calendarUsecase = StubCalendarUsecase(today: current)
        let viewModel = SelectDayDialogViewModelImple(
            currentDay: current,
            calendarUsecase: calendarUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
    
    struct Dummies {
        enum Name {
            case currentDay
            case sameMonth
            case nextMonth
            case nextYear
        }
        let name: Name
        let day: CalendarComponent.Day
        
        static var currentDay: Self {
            return .init(
                name: .currentDay, day: .init(year: 2023, month: 09, day: 2, weekDay: 1)
            )
        }
        static var sameMonth: Self {
            return .init(
                name: .sameMonth, day: .init(year: 2023, month: 09, day: 19, weekDay: 1)
            )
        }
        static var nextMonth: Self {
            return .init(
                name: .nextMonth, day: .init(year: 2023, month: 10, day: 1, weekDay: 1)
            )
        }
        static var nextYear: Self {
            return .init(
                name: .nextYear, day: .init(year: 2024, month: 10, day: 3, weekDay: 3)
            )
        }
    }
}

extension SelectDayViewModelTests {
    
    @Test func viewModel_provideInitialCurrentDate() {
        // given
        let current = Dummies.currentDay.day
        let viewModel = self.makeViewModel()
        
        // when
        let initial = viewModel.initialCurrentSelectDate
        
        // then
        let day = CalendarComponent.Day(initial, calendar: .current)
        #expect(day.year == current.year)
        #expect(day.month == current.month)
        #expect(day.day == current.day)
    }
    
    @Test("선택 환인시에 선택날짜 제공", arguments: [Dummies.currentDay, Dummies.sameMonth, Dummies.nextMonth, Dummies.nextYear]) func viewModel_whenConfirmSelect_notifySelectedDay(_ select: Dummies) {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.select(select.day.asDate())
        viewModel.confirmSelect()
        
        // then
        let selectedInfo = self.spyListener.didSelectDay
        #expect(self.spyRouter.didClosed == true)
        #expect(selectedInfo?.year == select.day.year)
        #expect(selectedInfo?.month == select.day.month)
        #expect(selectedInfo?.day == select.day.day)
        switch select.name {
        case .currentDay:
            #expect(selectedInfo?.isCurrentDay == true)
            #expect(selectedInfo?.isCurrentYear == true)
        case .sameMonth:
            #expect(selectedInfo?.isCurrentDay == false)
            #expect(selectedInfo?.isCurrentYear == true)
        case .nextMonth:
            #expect(selectedInfo?.isCurrentDay == false)
            #expect(selectedInfo?.isCurrentYear == true)
        case .nextYear:
            #expect(selectedInfo?.isCurrentDay == false)
            #expect(selectedInfo?.isCurrentYear == false)
        }
    }
}

private final class SpyRouter: BaseSpyRouter, SelectDayDialogRouting, @unchecked Sendable { }


private final class SpyListener: SelectDayDialogSceneListener, @unchecked Sendable {
    
    var didSelectDay: SelectDayInfo?
    func daySelectDialog(didSelect day: SelectDayInfo) {
        self.didSelectDay = day
    }
}

private extension CalendarComponent.Day {
    
    func asDate() -> Date {
        return Calendar.current.date(from: self) ?? Date()
    }
}
