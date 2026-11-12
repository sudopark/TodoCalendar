//
//  ContinuousMonthsViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions
import CalendarPresentation
import CalendarDomainInterface
import EventDomainInterface
import SettingDomainInterface


// MARK: - ContinuousMonthsViewModel

protocol ContinuousMonthsViewModel: AnyObject, Sendable, ContinuousMonthsSceneInteractor {

    func attachListener(_ listener: any ContinuousMonthsSceneListener)
    func select(_ day: DayCellViewModel)
    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel)
    func scrolled(to month: CalendarMonth)

    var weekDays: AnyPublisher<[WeekDayModel], Never> { get }
    var sections: AnyPublisher<[ContinuousMonthSection], Never> { get }
    var focusedMonth: AnyPublisher<CalendarMonth, Never> { get }
    var selectedDayIdentifier: AnyPublisher<String?, Never> { get }
    var todayIdentifier: AnyPublisher<String, Never> { get }
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never>
    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never>
}


// MARK: - ContinuousMonthsViewModelImple

private enum Constant {
    static let nextDayCount = 1
}

final class ContinuousMonthsViewModelImple: ContinuousMonthsViewModel, @unchecked Sendable {

    private let calendarUsecase: any CalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventListUsecase: any CalendarEventListhUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let uiSettingUsecase: any UISettingUsecase
    private weak var listener: (any ContinuousMonthsSceneListener)?

    init(
        initialMonth: CalendarMonth,
        calendarUsecase: any CalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventListUsecase: any CalendarEventListhUsecase,
        eventTagUsecase: any EventTagUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.eventListUsecase = eventListUsecase
        self.eventTagUsecase = eventTagUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.focusedMonth.send(initialMonth)

        self.internalBind()
    }

    private struct CalendarComponentRingBuffer: Equatable {
        let timeZone: TimeZone
        let components: [CalendarComponent]

        var sectionStackKeys: [SectionStackKey] {
            return self.components.map { SectionStackKey(timeZone: self.timeZone, component: $0) }
        }

        func component(containing day: DayCellViewModel) -> CalendarComponent? {
            return self.components.first(where: { $0.year == day.year && $0.month == day.month })
        }

        func positions(startingAt day: CalendarDay, count: Int) -> [DayPosition] {
            let identifier = "\(day.year)-\(day.month)-\(day.day)"
            let slots = self.components.flatMap { component in
                component.weeks.flatMap { week in
                    week.days.indices
                        .filter { week.days[$0].month == component.month }
                        .map { DaySlot(day: week.days[$0], indexInWeek: $0, rowId: component.rowId(of: week), component: component) }
                }
            }
            guard let start = slots.firstIndex(where: { $0.day.identifier == identifier }) else { return [] }
            return slots.dropFirst(start).prefix(count).compactMap { self.position(of: $0) }
        }

        private func position(of slot: DaySlot) -> DayPosition? {
            let day = slot.day
            guard let model = CurrentSelectDayModel(day: .init(day.year, day.month, day.day), slot.component, self.timeZone)
            else { return nil }
            return DayPosition(model: model, indexInWeek: slot.indexInWeek, rowId: slot.rowId)
        }
    }

    private struct DaySlot {
        let day: CalendarComponent.Day
        let indexInWeek: Int
        let rowId: String
        let component: CalendarComponent
    }

    private struct DayPosition: Equatable {
        let model: CurrentSelectDayModel
        let indexInWeek: Int
        let rowId: String
    }

    private struct Subject: @unchecked Sendable {
        let focusedMonth = CurrentValueSubject<CalendarMonth?, Never>(nil)
        let componentRingBuffer = CurrentValueSubject<CalendarComponentRingBuffer?, Never>(nil)
        let userSelectedDay = CurrentValueSubject<CalendarDay?, Never>(nil)
        let eventStackMap = CurrentValueSubject<[String: WeekEventStackEntry], Never>([:])
    }
    private let subject = Subject()
    private let cancellables = CancelBag()
    private let eventStackBuildingQueue = DispatchQueue(label: "continuous-months-event-stack-builder")
    // eventStackBuildingQueue 에서만 읽고 쓴다
    private var sectionStackBindings: [SectionStackKey: AnyCancellable] = [:]
    private var stackRevision: Int = 0

    private func internalBind() {
        self.bindComponentRingBuffer()
        self.bindEventStacks()
        self.bindSelectedDayNotifying()
    }

    private func bindComponentRingBuffer() {
        let componentsAroundFocus: (CalendarMonth) -> AnyPublisher<[CalendarComponent], Never> = { [weak self] focus in
            guard let self else { return Empty().eraseToAnyPublisher() }
            let months = focus.ringBufferMonths()
            let components = months.map { self.calendarUsecase.components(for: $0.month, of: $0.year) }
            return Publishers.CombineLatest4(components[0], components[1], components[2], components[3])
                .combineLatest(components[4])
                .map { [$0.0, $0.1, $0.2, $0.3, $1] }
                .eraseToAnyPublisher()
        }
        let components = self.subject.focusedMonth.compactMap { $0 }
            .removeDuplicates()
            .map(componentsAroundFocus)
            .switchToLatest()
            .filter { $0.isSameFirstWeekDay() }

        Publishers.CombineLatest(self.calendarSettingUsecase.currentTimeZone, components)
            .map { timeZone, components in
                CalendarComponentRingBuffer(timeZone: timeZone, components: components)
            }
            .removeDuplicates()
            .sink(receiveValue: { [weak self] ringBuffer in
                self?.subject.componentRingBuffer.send(ringBuffer)
            })
            .store(in: self.cancellables)
    }

    private func bindEventStacks() {
        self.subject.componentRingBuffer.compactMap { $0 }
            .receive(on: self.eventStackBuildingQueue)
            .sink(receiveValue: { [weak self] ringBuffer in
                self?.syncSectionStackBindings(ringBuffer.sectionStackKeys)
            })
            .store(in: self.cancellables)
    }

    private func syncSectionStackBindings(_ keys: [SectionStackKey]) {
        let removedKeys = self.sectionStackBindings.keys.filter { !keys.contains($0) }
        removedKeys.forEach { self.sectionStackBindings.removeValue(forKey: $0)?.cancel() }
        let removedRowIds = Set(removedKeys.flatMap { key in key.component.weeks.map { key.component.rowId(of: $0) } })
        if !removedRowIds.isEmpty {
            self.subject.eventStackMap.send(self.subject.eventStackMap.value.filter { !removedRowIds.contains($0.key) })
        }

        keys.filter { self.sectionStackBindings[$0] == nil }.forEach { key in
            self.sectionStackBindings[key] = self.calendarEvents(in: key)
                .receive(on: self.eventStackBuildingQueue)
                .sink(receiveValue: { [weak self] events in
                    self?.updateEventStacks(of: key, with: events)
                })
        }
    }

    private func bindSelectedDayNotifying() {
        let withEvents: (DayPosition) -> AnyPublisher<SelectDayAndEvents, Never> = { [weak self] position in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.eventsPerDay(at: position.rowId)
                .map { (position.model, $0[safe: position.indexInWeek] ?? []) }
                .eraseToAnyPublisher()
        }
        let allWithEvents: ([DayPosition]) -> AnyPublisher<[SelectDayAndEvents], Never> = { positions in
            let initial = Just([SelectDayAndEvents]()).eraseToAnyPublisher()
            return positions.map(withEvents).reduce(initial) { acc, next in
                acc.combineLatest(next).map { $0 + [$1] }.eraseToAnyPublisher()
            }
        }
        Publishers.CombineLatest(
            self.subject.userSelectedDay.compactMap { $0 },
            self.subject.componentRingBuffer.compactMap { $0 }
        )
        .map { day, ringBuffer in ringBuffer.positions(startingAt: day, count: 1 + Constant.nextDayCount) }
        .filter { !$0.isEmpty }
        .removeDuplicates()
        .map(allWithEvents)
        .switchToLatest()
        .sink(receiveValue: { [weak self] days in
            guard let selected = days.first else { return }
            self?.listener?.continuousMonths(didChangeSelectedDay: selected, and: Array(days.dropFirst()))
        })
        .store(in: self.cancellables)
    }

    private func updateEventStacks(of key: SectionStackKey, with events: [any CalendarEvent]) {
        self.stackRevision += 1
        let revision = self.stackRevision
        let stackBuilder = WeekEventStackBuilder(key.timeZone)
        let monthRange = key.component.monthRange(key.timeZone)
        let sectionStacks = key.component.weeks.reduce(into: [String: WeekEventStackEntry]()) { acc, week in
            let stack = stackBuilder.build(week, events: events, visibleRange: monthRange)
            acc[key.component.rowId(of: week)] = .init(revision: revision, stack: stack)
        }
        self.subject.eventStackMap.send(self.subject.eventStackMap.value.merging(sectionStacks) { $1 })
    }

    private func calendarEvents(in key: SectionStackKey) -> AnyPublisher<[any CalendarEvent], Never> {
        guard let range = key.component.intervalRange(at: key.timeZone)
        else { return Empty().eraseToAnyPublisher() }

        let activeHolidays = self.eventTagUsecase.offEventTagIdsOnCalendar()
            .map { offIds -> [any CalendarEvent] in
                guard !offIds.contains(.holiday) else { return [] }
                return key.component.holidayCalendarEvents(with: key.timeZone)
            }
        return Publishers.CombineLatest(
            self.eventListUsecase.calendarEvents(in: range),
            activeHolidays
        )
        .map { $0 + $1 }
        .eraseToAnyPublisher()
    }
}


// MARK: - input

extension ContinuousMonthsViewModelImple {

    func attachListener(_ listener: any ContinuousMonthsSceneListener) {
        self.listener = listener
    }

    func changeFocusedMonth(to month: CalendarMonth) {
        self.subject.focusedMonth.send(month)
    }

    func scrolled(to month: CalendarMonth) {
        self.subject.focusedMonth.send(month)
        self.listener?.continuousMonths(didScrollTo: month)
    }

    func selectDay(_ day: CalendarDay) {
        self.subject.userSelectedDay.send(day)
    }

    func select(_ day: DayCellViewModel) {
        let calendarDay = CalendarDay(day.year, day.month, day.day)
        self.subject.userSelectedDay.send(calendarDay)
        self.listener?.continuousMonths(didSelect: calendarDay)
    }

    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel) {
        guard let ringBuffer = self.subject.componentRingBuffer.value,
              let range = ringBuffer.component(containing: day)?.shareRange(kind, for: day, timeZone: ringBuffer.timeZone)
        else { return }
        self.listener?.continuousMonths(didRequestShare: range, kind: kind)
    }
}


// MARK: - output

extension ContinuousMonthsViewModelImple {

    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        return self.calendarSettingUsecase.firstWeekDay
            .map { WeekDayModel.allModels(of: $0) }
            .eraseToAnyPublisher()
    }

    var sections: AnyPublisher<[ContinuousMonthSection], Never> {
        let transform: (CalendarComponentRingBuffer, Int) -> [ContinuousMonthSection] = { ringBuffer, currentYear in
            return ringBuffer.components.map { component in
                ContinuousMonthSection(
                    month: .init(year: component.year, month: component.month),
                    title: component.monthTitle(currentYear: currentYear, timeZone: ringBuffer.timeZone),
                    weeks: component.weeks.map { week in
                        WeekRowModel(component.rowId(of: week), WeekRowModel(week, month: component.month).days)
                    }
                )
            }
        }
        let currentYear = self.calendarUsecase.currentDay.map { $0.year }
        return Publishers.CombineLatest(self.subject.componentRingBuffer.compactMap { $0 }, currentYear)
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var focusedMonth: AnyPublisher<CalendarMonth, Never> {
        return self.subject.focusedMonth.compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var selectedDayIdentifier: AnyPublisher<String?, Never> {
        return self.subject.userSelectedDay
            .map { $0.map { "\($0.year)-\($0.month)-\($0.day)" } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var todayIdentifier: AnyPublisher<String, Never> {
        return self.calendarUsecase.currentDay
            .map { $0.identifier }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        let stackElements = self.eventStackEntry(at: weekId)
            .map { $0.stack.eventStacks }
        return Publishers.CombineLatest(self.uiSettingUsecase.currentCalendarUISeting, stackElements)
            .map { WeekEventStackViewModel(linesStack: $1, shouldMarkEventDays: $0.showUnderLineOnEventDay) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never> {
        return self.eventStackEntry(at: weekId)
            .map { $0.stack.eventsPerDay }
            .eraseToAnyPublisher()
    }

    private func eventStackEntry(at weekId: String) -> AnyPublisher<WeekEventStackEntry, Never> {
        return self.subject.eventStackMap
            .compactMap { $0[weekId] }
            .removeDuplicates(by: { $0.revision == $1.revision })
            .eraseToAnyPublisher()
    }
}


// MARK: - private types

private struct SectionStackKey: Hashable {
    let timeZone: TimeZone
    let component: CalendarComponent

    static func == (lhs: SectionStackKey, rhs: SectionStackKey) -> Bool {
        return lhs.timeZone == rhs.timeZone && lhs.component == rhs.component
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.timeZone)
        hasher.combine(self.component.year)
        hasher.combine(self.component.month)
        hasher.combine(self.component.weeks.map { $0.id })
    }
}

private struct WeekEventStackEntry {
    let revision: Int
    let stack: WeekEventStack
}


// MARK: - private extensions

private extension CalendarMonth {

    func ringBufferMonths() -> [CalendarMonth] {
        let previous = self.previousMonth()
        let next = self.nextMonth()
        return [previous.previousMonth(), previous, self, next, next.nextMonth()]
    }
}

private extension Array where Element == CalendarComponent {

    func isSameFirstWeekDay() -> Bool {
        return Set(self.compactMap { $0.weeks.first?.days.first?.weekDay }).count == 1
    }
}

private extension CalendarComponent {

    func rowId(of week: CalendarComponent.Week) -> String {
        return "\(self.year)-\(self.month):\(week.id)"
    }

    func monthTitle(currentYear: Int, timeZone: TimeZone) -> String {
        let form = self.year == currentYear ? "date_form.MMMM" : "date_form.MMM_yyyy"
        return self.monthRange(timeZone)
            .map { Date(timeIntervalSince1970: $0.lowerBound).text(form.localized(), timeZone: timeZone) } ?? ""
    }
}
