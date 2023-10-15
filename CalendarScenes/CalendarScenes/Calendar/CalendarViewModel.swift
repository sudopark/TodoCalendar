//
//  CalendarViewModelImple.swift
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

// MARK: - CalendarViewModel

protocol CalendarViewModel: AnyObject, Sendable, CalendarSceneInteractor {
    
    func prepare()
    func focusChanged(from previousIndex: Int, to nextIndex: Int)
}


// MARK: - CalendarViewModelImple

final class CalendarViewModelImple: CalendarViewModel, @unchecked Sendable {
    
    private let calendarUsecase: any CalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let holidayUsecase: any HolidayUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUsecase: any ScheduleEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    var router: (any CalendarViewRouting)?
    private var calendarPaperInteractors: [any CalendarPaperSceneInteractor]?
    // TODO: calendarVC load 이후 바로 prepare를 할것이기때문에 라이프사이클상 listener는 setter 주입이 아니라 생성시에 받아야 할수도있음
    weak var listener: (any CalendarSceneListener)?
    
    init(
        calendarUsecase: any CalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        holidayUsecase: any HolidayUsecase,
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        eventTagUsecase: any EventTagUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.holidayUsecase = holidayUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.eventTagUsecase = eventTagUsecase
        
        self.internalBind()
    }
    
    private struct TotalMonthsInRange {
        let totalMonths: [CalendarMonth]
        let focusedIndex: Int
        var focusedMonth: CalendarMonth? {
            return self.totalMonths[safe: focusedIndex]
        }
    }
    private struct Subject {
        let monthsInCurrentRange = CurrentValueSubject<TotalMonthsInRange?, Never>(nil)
    }
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private var monthsWithSort: AnyPublisher<[CalendarMonth], Never> {
        return self.subject.monthsInCurrentRange
            .compactMap { $0?.totalMonths }
            .map { $0.sorted() }
            .eraseToAnyPublisher()
    }
    
    private func internalBind() {
        
        self.subject.monthsInCurrentRange
            .compactMap { $0?.totalMonths }
            .sink(receiveValue: { [weak self] months in
                months.enumerated().forEach { offset, month in
                    self?.calendarPaperInteractors?[safe: offset]?.updateMonthIfNeed(month)
                }
            })
            .store(in: &self.cancellables)
        
        // Timezone 변경시에 조회중인 달력은 안바뀜 하지만 조회 가능한 범위는 달라짐
        // ex) 동일날짜의 시간이라도 kst는 utc보다 9시간 빠름
        let totalViewingMonths = Publishers.CombineLatest(
                self.monthsWithSort,
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
        
        self.bindFocusedMonthChanged()
    }
    
    private func bindFocusedMonthChanged() {
        let transformWithFocusedMonthIsCurrent: (CalendarMonth, CalendarComponent.Day) -> (CalendarMonth, Bool)
        transformWithFocusedMonthIsCurrent = { focusedMonth, currentDay in
            let isCurrentMonth = currentDay.year == focusedMonth.year
                && currentDay.month == focusedMonth.month
            return (focusedMonth, isCurrentMonth)
        }
        let compare: ((CalendarMonth, Bool), (CalendarMonth, Bool)) -> Bool = { lhs, rhs in
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        }
        
        Publishers.CombineLatest(
            self.subject.monthsInCurrentRange.compactMap { $0?.focusedMonth },
            self.calendarUsecase.currentDay
        )
        .map(transformWithFocusedMonthIsCurrent)
        .removeDuplicates(by: compare)
        .sink(receiveValue: { [weak self] (focused, isCurrent) in
            self?.listener?.calendarScene(focusChangedTo: focused, isCurrentMonth: isCurrent)
        })
        .store(in: &self.cancellables)
    }
    
    private func bindRefreshHoliday() {
        let totalViewingYears = self.monthsWithSort
            .map { $0.years() }
            .scan(TotalYears()) { acc, years in acc.append(years) }
        totalViewingYears
            .map { $0.newOne }
            .removeDuplicates()
            .sink(receiveValue: { [weak self] newYears in
                self?.refreshHolidays(for: newYears)
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


extension CalendarViewModelImple {
    
    func prepare() {
    
        self.calendarUsecase.currentDay
            .first()
            .sink(receiveValue: { [weak self] today in
                self?.prepareInitialMonths(around: today)
            })
            .store(in: &self.cancellables)
        
        self.calendarSettingUsecase.prepare()
        Task { [weak self] in
            try? await self?.holidayUsecase.prepare()
            self?.bindRefreshHoliday()
        }
        
        self.todoEventUsecase.refreshCurentTodoEvents()
        
        self.eventTagUsecase.prepare()
    }
    
    private func prepareInitialMonths(around today: CalendarComponent.Day) {
        let currentMonth = CalendarMonth(year: today.year, month: today.month)
        let months = [
            currentMonth.previousMonth(),
            currentMonth,
            currentMonth.nextMonth()
        ]
        let totalMonths = TotalMonthsInRange(totalMonths: months, focusedIndex: 1)
        Task { @MainActor in
            self.calendarPaperInteractors = self.router?.attachInitialMonths(months)
            self.subject.monthsInCurrentRange.send(totalMonths)
        }
    }
    
    func focusChanged(from previousIndex: Int, to currentIndex: Int) {
        guard let months = self.subject.monthsInCurrentRange.value?.totalMonths, !months.isEmpty
        else { return }
        let lastIndex = months.count - 1
        
        let isMoveToNext = previousIndex + 1 == currentIndex
            || (currentIndex == 0 && previousIndex == lastIndex)
        
        func updateAfterFocusMoveToNext() -> [CalendarMonth] {
            let hasNext = currentIndex + 1 <= lastIndex
            let targetIndex = hasNext ? currentIndex + 1 : 0
            return months |> ix(targetIndex) .~ months[currentIndex].nextMonth()
        }
        
        func updateAfterFocusMoveToPrevious() -> [CalendarMonth] {
            let hasPrevious = currentIndex - 1 >= 0
            let targetIndex = hasPrevious ? currentIndex - 1 : lastIndex
            return months |> ix(targetIndex) .~ months[currentIndex].previousMonth()
        }
        
        let newMonths = isMoveToNext ? updateAfterFocusMoveToNext() : updateAfterFocusMoveToPrevious()
        let newTotalMonths = TotalMonthsInRange(totalMonths: newMonths, focusedIndex: currentIndex)
        self.subject.monthsInCurrentRange.send(newTotalMonths)
    }
    
    func moveFocusToToday() {
        // TODO: 
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

