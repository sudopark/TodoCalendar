//
//  ContinuousMonthsViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions
import CalendarPresentation


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

    private struct Buffer: Equatable {
        let timeZone: TimeZone
        let components: [CalendarComponent]
        let sectionWeeks: [[CalendarComponent.Week]]

        var sectionStackKeys: [SectionStackKey] {
            return zip(self.components, self.sectionWeeks).map { component, weeks in
                SectionStackKey(timeZone: self.timeZone, component: .init(year: component.year, month: component.month, weeks: weeks))
            }
        }

        func component(containing day: DayCellViewModel) -> CalendarComponent? {
            return self.components.first(where: { $0.year == day.year && $0.month == day.month })
        }
    }

    private struct Subject: @unchecked Sendable {
        let focusedMonth = CurrentValueSubject<CalendarMonth?, Never>(nil)
        let buffer = CurrentValueSubject<Buffer?, Never>(nil)
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
        self.bindBuffer()
        self.bindEventStacks()
    }

    private func bindBuffer() {
        let componentsAroundFocus: (CalendarMonth) -> AnyPublisher<[CalendarComponent], Never> = { [weak self] focus in
            guard let self else { return Empty().eraseToAnyPublisher() }
            let months = focus.bufferMonths()
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
                Buffer(timeZone: timeZone, components: components, sectionWeeks: components.sectionWeeks())
            }
            .removeDuplicates()
            .sink(receiveValue: { [weak self] buffer in
                self?.subject.buffer.send(buffer)
            })
            .store(in: self.cancellables)
    }

    private func bindEventStacks() {
        self.subject.buffer.compactMap { $0 }
            .receive(on: self.eventStackBuildingQueue)
            .sink(receiveValue: { [weak self] buffer in
                self?.syncSectionStackBindings(buffer.sectionStackKeys)
            })
            .store(in: self.cancellables)
    }

    private func syncSectionStackBindings(_ keys: [SectionStackKey]) {
        let removedKeys = self.sectionStackBindings.keys.filter { !keys.contains($0) }
        removedKeys.forEach { self.sectionStackBindings.removeValue(forKey: $0)?.cancel() }
        let removedWeekIds = Set(removedKeys.flatMap { $0.component.weeks.map { $0.id } })
        if !removedWeekIds.isEmpty {
            self.subject.eventStackMap.send(self.subject.eventStackMap.value.filter { !removedWeekIds.contains($0.key) })
        }

        keys.filter { self.sectionStackBindings[$0] == nil }.forEach { key in
            self.sectionStackBindings[key] = self.calendarEvents(in: key)
                .receive(on: self.eventStackBuildingQueue)
                .sink(receiveValue: { [weak self] events in
                    self?.updateEventStacks(of: key, with: events)
                })
        }
    }

    private func updateEventStacks(of key: SectionStackKey, with events: [any CalendarEvent]) {
        self.stackRevision += 1
        let revision = self.stackRevision
        let stackBuilder = WeekEventStackBuilder(key.timeZone)
        let sectionStacks = key.component.weeks.reduce(into: [String: WeekEventStackEntry]()) { acc, week in
            acc[week.id] = .init(revision: revision, stack: stackBuilder.build(week, events: events))
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
        guard let buffer = self.subject.buffer.value,
              let range = buffer.component(containing: day)?.shareRange(kind, for: day, timeZone: buffer.timeZone)
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
        let transform: (Buffer) -> [ContinuousMonthSection] = { buffer in
            return zip(buffer.components, buffer.sectionWeeks).map { component, weeks in
                ContinuousMonthSection(
                    month: .init(year: component.year, month: component.month),
                    weeks: weeks.map { WeekRowModel($0, month: component.month) }
                )
            }
        }
        return self.subject.buffer.compactMap { $0 }
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

    func bufferMonths() -> [CalendarMonth] {
        let previous = self.previousMonth()
        let next = self.nextMonth()
        return [previous.previousMonth(), previous, self, next, next.nextMonth()]
    }
}

private extension Array where Element == CalendarComponent {

    func isSameFirstWeekDay() -> Bool {
        return Set(self.compactMap { $0.weeks.first?.days.first?.weekDay }).count == 1
    }

    func sectionWeeks() -> [[CalendarComponent.Week]] {
        return self.enumerated().map { offset, component in
            guard let nextMonth = self[safe: offset + 1] else { return component.weeks }
            let nextMonthWeekIds = Set(nextMonth.weeks.map { $0.id })
            return component.weeks.filter { !nextMonthWeekIds.contains($0.id) }
        }
    }
}
