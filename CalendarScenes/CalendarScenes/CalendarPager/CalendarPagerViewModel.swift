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
import Scenes

// MARK: - CalendarPagerViewModel

protocol CalendarPagerViewModel: AnyObject, Sendable {
    
    func prepare()
    func focusMoveToPreviousMonth()
    func focusMoveToNextMonth()
}


// MARK: - CalendarPagerViewModelImple

final class CalendarPagerViewModelImple: CalendarPagerViewModel, @unchecked Sendable {
    
    private let calendarUsecase: CalendarUsecase
    private let calendarSettingUsecase: CalendarSettingUsecase
    private let holidayUsecase: HolidayUsecase
    private let todoEventUsecase: TodoEventUsecase
    private let scheduleEventUsecase: ScheduleEventUsecase
    var router: CalendarPagerViewRouting?
    private var monthInteractors: [CalendarSingleMonthInteractor]?
    
    init(
        calendarUsecase: CalendarUsecase,
        calendarSettingUsecase: CalendarSettingUsecase,
        holidayUsecase: HolidayUsecase,
        todoEventUsecase: TodoEventUsecase,
        scheduleEventUsecase: ScheduleEventUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.holidayUsecase = holidayUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        
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
        
        // Timezone 변경시에 조회중인 달력은 안바뀜 하지만 조회 가능한 범위는 달라짐
        // ex) 동일날짜의 시간이라도 kst는 utc보다 9시간 빠름
        let totalViewingMonths = Publishers.CombineLatest(
                self.subject.monthsInCurrentRange.compactMap { $0 },
                self.calendarSettingUsecase.currentTimeZone
            )
            .scan(TotalMonthRanges()) { acc, pair in acc.append(pair.0, in: pair.1) }
        totalViewingMonths
            .map { $0.newRanges }
            .removeDuplicates()
            .sink(receiveValue: { [weak self] ranges in
                self?.refreshEvents(ranges)
            })
            .store(in: &self.cancellables)
    }
    
    private func refreshHolidays(for newYears: [Int]) {
        Task { [weak self] in
            await newYears.asyncForEach { year in
                try? await self?.holidayUsecase.refreshHolidays(year)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func refreshEvents(_ ranges: [Range<TimeInterval>]) {
        ranges.forEach {
            self.scheduleEventUsecase.refreshScheduleEvents(in: $0)
            self.todoEventUsecase.refreshTodoEvents(in: $0)
        }
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
        guard let months = self.subject.monthsInCurrentRange.value else { return }
        // TODO: reorder months
        let newMonths = months.map { $0.previousMonth() }
        self.subject.monthsInCurrentRange.send(newMonths)
    }
    
    func focusMoveToNextMonth() {
        guard let months = self.subject.monthsInCurrentRange.value else { return }
        // TODO: reorder months
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

private struct TotalMonthRanges {

    private let checkedRange: Range<TimeInterval>?
    let newRanges: [Range<TimeInterval>]
    
    init(
        checkedRange: Range<TimeInterval>? = nil,
        newRanges: [Range<TimeInterval>] = []
    ) {
        self.checkedRange = checkedRange
        self.newRanges = newRanges
    }
    
    func append(_ months: [CalendarMonth], in timeZone: TimeZone) -> TotalMonthRanges {
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard months.isEmpty == false,
              let firstDate = months.first.flatMap(calendar.firstDateOfMonth(_:)),
              let endDate = months.last.flatMap(calendar.lastDateOfMonth(_:))
        else { return self }

        let monthsRange = (firstDate.timeIntervalSince1970..<endDate.timeIntervalSince1970)
        
        let notCheckedRanges = (self.checkedRange.map { monthsRange.notOverlapRanges(with: $0) } ?? [monthsRange])
            
        let newCheckedRange = self.checkedRange.map { $0.merge(with: monthsRange) } ?? monthsRange
        return .init(
            checkedRange: newCheckedRange,
            newRanges: notCheckedRanges
        )
    }
}


private extension Calendar {
    
    func firstDateOfMonth(_ month: CalendarMonth) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = self.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let firstDateString = "\(month.year)-\(month.month.withLeadingZero())-01"
        return formatter.date(from: firstDateString)
            .flatMap { self.startOfDay(for: $0) }
    }
    
    func lastDateOfMonth(_ month: CalendarMonth) -> Date? {
        return self.firstDateOfMonth(month)
            .flatMap { self.lastDayOfMonth(from: $0) }
            .flatMap { self.endOfDay(for: $0) }
    }
}

private extension Range where Bound == TimeInterval {
    
    func merge(with other: Range) -> Range {
        
        let lowerBound = Swift.min(other.lowerBound, self.lowerBound)
        let upperBound = Swift.max(other.upperBound, self.upperBound)
        
        return (lowerBound..<upperBound)
    }
    
    func notOverlapRanges(with other: Range) -> [Range] {
        let leftOut = self.lowerBound < other.lowerBound ? (self.lowerBound..<other.lowerBound) : nil
        let rightOut = self.upperBound > other.upperBound ? (other.upperBound..<self.upperBound) : nil
        return [leftOut, rightOut].compactMap { $0 }
    }
}

