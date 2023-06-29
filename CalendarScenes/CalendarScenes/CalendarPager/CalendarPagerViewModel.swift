//
//  CalendarPagerViewModelImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/28.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


struct CalendarMonth: Hashable, Comparable {
    
    let year: Int
    let month: Int
    
    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }
    
    static func < (lhs: CalendarMonth, rhs: CalendarMonth) -> Bool {
        return lhs.year < rhs.year && lhs.month < rhs.month
    }
    
    func nextMonth() -> CalendarMonth {
        return self.month == 12
        ? .init(year: self.year + 1, month: 1)
        : .init(year: self.year, month: self.month + 1)
    }
    
    func previousMonth() -> CalendarMonth {
        return self.month == 1
        ? .init(year: self.year - 1, month: 12)
        : .init(year: self.year, month: self.month - 1)
    }
}

final class CalendarPagerViewModelImple: @unchecked Sendable {
    
    private let calendarUsecase: CalendarUsecase
    private let holidayUsecase: HolidayUsecase
    weak var router: CalendarPagerViewRouting?
    private var monthInteractors: [CalendarMonthInteractor]?
    
    init(
        calendarUsecase: CalendarUsecase,
        holidayUsecase: HolidayUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.holidayUsecase = holidayUsecase
        
        self.internalBind()
    }
    
    private struct Subject {
        let monthsInCurrentRange = CurrentValueSubject<[CalendarMonth]?, Never>(nil)
    }
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBind() {
        
        self.subject.monthsInCurrentRange
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] months in
                months.enumerated().forEach { offset, month in
                    self?.monthInteractors?[safe: offset]?.updateMonthIfNeed(month)
                }
            })
            .store(in: &self.cancellables)
        
        let totalViewingYears = self.subject.monthsInCurrentRange
            .compactMap { $0?.years() }
            .scan(TotalYears()) { acc, years in acc.append(years) }
        totalViewingYears
            .map { $0.newOne }
            .removeDuplicates()
            .sink(receiveValue: { [weak self] newYears in
                self?.refreshHolidays(for: newYears)
            })
            .store(in: &self.cancellables)
        
        // TODO: bind months -> check new range appended -> refresh events
    }
    
    private func refreshHolidays(for newYears: [Int]) {
        Task { [weak self] in
            await newYears.asyncForEach { year in
                try? await self?.holidayUsecase.refreshHolidays(year)
            }
        }
        .store(in: &self.cancellables)
    }
}


extension CalendarPagerViewModelImple {
    
    func prepare() {
    
        self.calendarUsecase.currentDay
            .first()
            .sink(receiveValue: { [weak self] today in
                self?.prepareInitialMonths(around: today)
            })
            .store(in: &self.cancellables)
    }
    
    private func prepareInitialMonths(around today: CalendarComponent.Day) {
        let currentMonth = CalendarMonth(year: today.year, month: today.month)
        let months = [
            currentMonth.previousMonth(),
            currentMonth,
            currentMonth.nextMonth()
        ]
        self.monthInteractors = self.router?.attachInitialMonths(months)
        self.subject.monthsInCurrentRange.send(months)
    }
    
    func focusMoveToPreviousMonth() {
        guard let monts = self.subject.monthsInCurrentRange.value else { return }
        let newMonths = monts.map { $0.previousMonth() }
        self.subject.monthsInCurrentRange.send(newMonths)
    }
    
    func focusMoveToNextMonth() {
        guard let months = self.subject.monthsInCurrentRange.value else { return }
        let newMonths = months.map { $0.nextMonth() }
        self.subject.monthsInCurrentRange.send(newMonths)
    }
}

private extension Array where Element == CalendarMonth {
    
    func years() -> Set<Int> {
        return self.map { $0.year } |> Set.init
    }
}

private struct TotalYears {
    
    private let checked: Set<Int>
    let newOne: [Int]
    
    init(checked: Set<Int> = [], newOne: [Int] = []) {
        self.checked = checked
        self.newOne = newOne
    }
    
    func append(_ years: Set<Int>) -> TotalYears {
        let notChecked = years.subtracting(self.checked)
        return .init(
            checked: self.checked.union(years),
            newOne: Array(notChecked).sorted()
        )
    }
}
