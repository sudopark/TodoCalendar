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
        let calendarUsecase = StubCalendarUsecase(
            today: .init(year: current.year, month: current.month, day: current.day, weekDay: 1)
        )
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
        let day: CalendarDay
        
        static var currentDay: Self {
            return .init(
                name: .currentDay, day: .init(2023, 09, 2)
            )
        }
        static var sameMonth: Self {
            return .init(
                name: .sameMonth, day: .init(2023, 09, 19)
            )
        }
        static var nextMonth: Self {
            return .init(
                name: .nextMonth, day: .init(2023, 10, 1)
            )
        }
        static var nextYear: Self {
            return .init(
                name: .nextYear, day: .init(2024, 10, 3)
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

private extension CalendarDay {
    
    func asDate() -> Date {
        let components = DateComponents(
            year: self.year, month: self.month, day: self.day
        )
        return Calendar.current.date(from: components) ?? Date()
    }
}
