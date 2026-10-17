//
//  SpyContinuousMonthsViewModel.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain

@testable import CalendarScenes
import CalendarPresentation


final class SpyContinuousMonthsViewModel: ContinuousMonthsViewModel, @unchecked Sendable {

    private let sectionsSubject: CurrentValueSubject<[ContinuousMonthSection], Never>

    init(center: CalendarMonth) {
        self.sectionsSubject = .init(center.fixtureBufferSections())
    }

    func sendSections(center: CalendarMonth) {
        self.sectionsSubject.send(center.fixtureBufferSections())
    }

    var didScrolledTo: CalendarMonth?
    func scrolled(to month: CalendarMonth) {
        self.didScrolledTo = month
    }

    func changeFocusedMonth(to month: CalendarMonth) { }
    func attachListener(_ listener: any ContinuousMonthsSceneListener) { }
    var didSelectDay: DayCellViewModel?
    func select(_ day: DayCellViewModel) {
        self.didSelectDay = day
    }

    var didShareKind: CalendarShareRangeKind?
    var didShareDay: DayCellViewModel?
    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel) {
        self.didShareKind = kind
        self.didShareDay = day
    }

    func selectDay(_ day: CalendarDay) { }

    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        return Just(WeekDayModel.allModels()).eraseToAnyPublisher()
    }

    var sections: AnyPublisher<[ContinuousMonthSection], Never> {
        return self.sectionsSubject.eraseToAnyPublisher()
    }

    var focusedMonth: AnyPublisher<CalendarMonth, Never> {
        return self.sectionsSubject.compactMap { $0[safe: 2]?.month }.eraseToAnyPublisher()
    }

    var selectedDayIdentifier: AnyPublisher<String?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }

    var todayIdentifier: AnyPublisher<String, Never> {
        return Empty().eraseToAnyPublisher()
    }

    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        return Empty().eraseToAnyPublisher()
    }

    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never> {
        return Empty().eraseToAnyPublisher()
    }
}

extension CalendarMonth {

    var fixtureWeekCount: Int {
        return 4 + self.month % 3
    }

    func fixtureBufferMonths() -> [CalendarMonth] {
        let previous = self.previousMonth()
        let next = self.nextMonth()
        return [previous.previousMonth(), previous, self, next, next.nextMonth()]
    }

    func fixtureBufferSections() -> [ContinuousMonthSection] {
        return self.fixtureBufferMonths().map { month in
            let weeks = (0..<month.fixtureWeekCount).map { weekIndex in
                let days = (0..<7).map { offset in
                    DayCellViewModel(
                        year: month.year, month: month.month, day: weekIndex * 7 + offset + 1,
                        isNotCurrentMonth: false, accentDay: nil
                    )
                }
                return WeekRowModel("\(month.year)-\(month.month)-w\(weekIndex)", days)
            }
            return ContinuousMonthSection(month: month, weeks: weeks)
        }
    }
}
