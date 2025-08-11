//
//  CalendarViewModelImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/28.
//

import UIKit
import Combine
import CombineExt
import Prelude
import Optics
import Domain
import Scenes
import Extensions


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
    private let foremostEventusecase: any ForemostEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let migrationUsecase: any TemporaryUserDataMigrationUescase
    private let uiSettingUsecase: any UISettingUsecase
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    var router: (any CalendarViewRouting)?
    private let eventSyncUsecase: any EventSyncUsecase
    private var calendarPaperInteractors: [any CalendarPaperSceneInteractor]?
    // TODO: calendarVC load 이후 바로 prepare를 할것이기때문에 라이프사이클상 listener는 setter 주입이 아니라 생성시에 받아야 할수도있음
    weak var listener: (any CalendarSceneListener)?
    
    init(
        calendarUsecase: any CalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        holidayUsecase: any HolidayUsecase,
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUsecase: any ScheduleEventUsecase,
        foremostEventusecase: any ForemostEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        migrationUsecase: any TemporaryUserDataMigrationUescase,
        uiSettingUsecase: any UISettingUsecase,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        eventSyncUsecase: any EventSyncUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.holidayUsecase = holidayUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUsecase = scheduleEventUsecase
        self.foremostEventusecase = foremostEventusecase
        self.eventTagUsecase = eventTagUsecase
        self.migrationUsecase = migrationUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.googleCalendarUsecase = googleCalendarUsecase
        self.eventSyncUsecase = eventSyncUsecase
        
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
        let selectedDayPerMonths = CurrentValueSubject<[CalendarMonth: CurrentSelectDayModel], Never>([:])
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

        self.bindRefreshEvents()
        self.bindFocusedMonthChanged()
    }
    
    private func bindRefreshEvents() {
        
        // Timezone 변경시에 조회중인 달력은 안바뀜 하지만 조회 가능한 범위는 달라짐
        // ex) 동일날짜의 시간이라도 kst는 utc보다 9시간 빠름
        let totalViewingMonths = Publishers.CombineLatest(
                self.monthsWithSort,
                self.calendarSettingUsecase.currentTimeZone
            )
            .scan(TotalMonthRanges()) { acc, pair in acc.append(pair.0, in: pair.1) }
            .share()
        
        totalViewingMonths
            .map { $0.newRanges }
            .removeDuplicates()
            .sink(receiveValue: { [weak self] ranges in
                self?.refreshEvents(ranges)
            })
            .store(in: &self.cancellables)
        
        let refreshAfterEnterForeground = NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        ).map { _ in  }
        let refreshAfterMigration = self.migrationUsecase.migrationResult
            .filter { $0.isSuccess }.map { _ in  }
        
        let refreshAfterSyncEnd = Publishers.Zip(
            self.eventSyncUsecase.isSyncInProgress,
            self.eventSyncUsecase.isSyncInProgress.dropFirst()
        )
        .filter { old, new in old && !new }
        .map { _ in }
        
        Publishers.Merge3(
            refreshAfterEnterForeground, refreshAfterMigration, refreshAfterSyncEnd
        )
        .withLatestFrom(totalViewingMonths) { $1 }
        .compactMap { $0.checkedRange }
        .sink(receiveValue: { [weak self] total in
            self?.refreshEvents([total])
            self?.todoEventUsecase.refreshCurentTodoEvents()
        })
        .store(in: &self.cancellables)
        
        let refreshAfterGoogleCalendarIntegrated = self.googleCalendarUsecase.integratedAccount
            .filter { $0 != nil }
        refreshAfterGoogleCalendarIntegrated
            .withLatestFrom(totalViewingMonths) { $1 }
            .compactMap { $0.checkedRange }
            .sink(receiveValue: { [weak self] total in
                self?.googleCalendarUsecase.refreshEvents(in: total)
            })
            .store(in: &self.cancellables)
        
        refreshAfterEnterForeground
            .sink(receiveValue: { [weak self] in
                self?.eventSyncUsecase.sync()
            })
            .store(in: &self.cancellables)
    }
    
    private func bindFocusedMonthChanged() {
        typealias CurrentAndFocusInfo = (
            focusedMonth: CalendarMonth,
            focusedDayMap: [CalendarMonth: CurrentSelectDayModel],
            currentDay: CalendarComponent.Day
        )
        let transformWithFocusedMonthAnsIsCurrentDay: (CurrentAndFocusInfo) -> SelectDayInfo?
        transformWithFocusedMonthAnsIsCurrentDay = { info in
            guard let currentMonthSelectedDay = info.focusedDayMap[info.focusedMonth]?.day
            else { return nil }
            let isCurrentYear = info.currentDay.year == info.focusedMonth.year
            let isCurrentMonth = isCurrentYear
                && info.currentDay.month == info.focusedMonth.month
            let isCurrentDaySelected = isCurrentYear && isCurrentMonth
                && currentMonthSelectedDay == info.currentDay.day
            
            return .init(
                info.focusedMonth.year,
                info.focusedMonth.month,
                currentMonthSelectedDay,
                isCurrentYear: isCurrentYear,
                isCurrentDay: isCurrentDaySelected
            )
        }
        
        Publishers.CombineLatest3(
            self.subject.monthsInCurrentRange.compactMap { $0?.focusedMonth },
            self.subject.selectedDayPerMonths,
            self.calendarUsecase.currentDay
        )
        .compactMap(transformWithFocusedMonthAnsIsCurrentDay)
        .removeDuplicates()
        .sink(receiveValue: { [weak self] selected in
            logger.log(level: .debug, "select day changed: \(selected)")
            self?.listener?.calendarScene(focusChangedTo: selected)
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
            self.googleCalendarUsecase.refreshEvents(in: $0)
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
        
        self.foremostEventusecase.refresh()
        
        self.bindUncompletedTodoRefresh()
        
        self.eventSyncUsecase.sync()
    }
    
    private func prepareInitialMonths(around today: CalendarComponent.Day) {
        let totalMonths = self.makeTotalMonths(around: today.year, today.month)
        Task { @MainActor in
            self.calendarPaperInteractors = self.router?.attachInitialMonths(totalMonths.totalMonths)
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
        self.calendarUsecase.currentDay
            .first()
            .sink(receiveValue: { [weak self] today in
                guard let self = self else { return }
                let totalMonths = self.makeTotalMonths(around: today.year, today.month)
                self.changeChilds(totalMonths) { thisMonthInteractor in
                    thisMonthInteractor?.selectToday()
                }
            })
            .store(in: &self.cancellables)
    }
    
    func moveDay(_ day: CalendarDay) {
        let totalMonths = self.makeTotalMonths(around: day.year, day.month)
        self.changeChilds(totalMonths) { selectMontthInteractor in
            selectMontthInteractor?.selectDay(day)
        }
    }
    
    private func changeChilds(
        _ totalMonths: TotalMonthsInRange,
        andSelectDay: @Sendable @escaping ((any CalendarPaperSceneInteractor)?) -> Void
    ) {
        Task { @MainActor in
            self.router?.changeFocus(at: totalMonths.focusedIndex)
            self.subject.monthsInCurrentRange.send(totalMonths)
            totalMonths.totalMonths.enumerated().forEach { offset, month in
                let interactor = self.calendarPaperInteractors?[safe: offset]
                interactor?.updateMonthIfNeed(month)
                if offset == totalMonths.focusedIndex {
                    andSelectDay(interactor)
                }
            }
        }
    }
    
    private func makeTotalMonths(
        around year: Int, _ month: Int
    ) -> TotalMonthsInRange {
        let currentMonth = CalendarMonth(year: year, month: month)
        let months = [
            currentMonth.previousMonth(),
            currentMonth,
            currentMonth.nextMonth()
        ]
        return TotalMonthsInRange(totalMonths: months, focusedIndex: 1)
    }
}


// MARK: - uncompleted todo

extension CalendarViewModelImple {
    
    private func bindUncompletedTodoRefresh() {
        
        let refreshAfterEnterForeground = NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        ).map { _ in }
        
        let refreshWhenDateChanged = self.calendarUsecase.currentDay.removeDuplicates().dropFirst().map { _ in }
        
        let refreshWithFirst = Publishers
            .Merge(refreshAfterEnterForeground, refreshWhenDateChanged)
            .prepend(())
        
        Publishers.CombineLatest(
            refreshWithFirst,
            self.uiSettingUsecase.currentCalendarUISeting.map { $0.showUncompletedTodos }
        )
        .filter { $1 }
        .sink(receiveValue: { [weak self] _, _ in
            self?.todoEventUsecase.refreshUncompletedTodos()
        })
        .store(in: &self.cancellables)
    }
}

extension CalendarViewModelImple: CalendarPaperSceneListener {
    
    func calendarPaper(on month: CalendarMonth, didChange selectedDay: CurrentSelectDayModel) {
        let newMap = self.subject.selectedDayPerMonths.value
            |> key(month) .~ selectedDay
        self.subject.selectedDayPerMonths.send(newMap)
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

    let checkedRange: Range<TimeInterval>?
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
              let start = months.first.flatMap(calendar.thisYearLowerBound(of:)),
              let end = months.last.flatMap(calendar.thisYearUpperBound(of:))
        else { return self }

        let range = (start.timeIntervalSince1970..<end.timeIntervalSince1970)
        
        let notCheckedRanges = (self.checkedRange.map { range.notOverlapRanges(with: $0) } ?? [range])
            
        let newCheckedRange = self.checkedRange.map { $0.merge(with: range) } ?? range
        return .init(
            checkedRange: newCheckedRange,
            newRanges: notCheckedRanges
        )
    }
}


private extension Calendar {
    
    func thisYearLowerBound(of month: CalendarMonth) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = self.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let firstDateString = "\(month.year)-01-01"
        return formatter.date(from: firstDateString)
            .flatMap { self.startOfDay(for: $0) }
    }
    
    func thisYearUpperBound(of month: CalendarMonth) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = self.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let lastDateString = "\(month.year+1)-01-01"
        return formatter.date(from: lastDateString)
            .flatMap { self.startOfDay(for: $0) }
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


private extension Result {
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }
}
