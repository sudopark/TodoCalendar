//
//  ContinuousMonthsView.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


@Observable final class ContinuousMonthsViewState {

    fileprivate var weekDays: [WeekDayModel] = []
    fileprivate var selectedDay: String?
    fileprivate var today: String?
    fileprivate var focusedMonth: CalendarMonth?
    var rowWidth: CGFloat = 0
    @ObservationIgnored fileprivate var eventStacks: (String) -> AnyPublisher<WeekEventStackViewModel, Never> = { _ in
        Empty().eraseToAnyPublisher()
    }
    @ObservationIgnored fileprivate var eventsPerDay: (String) -> AnyPublisher<[[any CalendarEvent]], Never> = { _ in
        Empty().eraseToAnyPublisher()
    }

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    func bind(_ viewModel: any ContinuousMonthsViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true

        self.eventStacks = viewModel.eventStack(at:)
        self.eventsPerDay = viewModel.eventsPerDay(at:)

        viewModel.weekDays
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] days in
                self?.weekDays = days
            })
            .store(in: self.cancellables)

        viewModel.selectedDayIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.selectedDay = identifier
            })
            .store(in: self.cancellables)

        viewModel.todayIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.today = identifier
            })
            .store(in: self.cancellables)

        viewModel.focusedMonth
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] month in
                self?.focusedMonth = month
            })
            .store(in: self.cancellables)
    }
}

final class ContinuousMonthsViewEventHandler: Observable {
    var daySelected: (DayCellViewModel) -> Void = { _ in }
    var shareEvents: (CalendarShareRangeKind, DayCellViewModel) -> Void = { _, _ in }

    func bind(_ viewModel: any ContinuousMonthsViewModel) {
        self.daySelected = viewModel.select(_:)
        self.shareEvents = viewModel.shareEvents(_:for:)
    }
}


struct ContinuousMonthsHeaderView: View {

    @Environment(ContinuousMonthsViewState.self) private var state
    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        WeekDaysHeaderView(weekDays: self.state.weekDays)
            .padding([.leading, .trailing], spacing: .small)
            .background(self.appearance.colorSet.dayBackground.asColor)
    }
}

struct ContinuousMonthsBackgroundView: View {

    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        self.appearance.colorSet.dayBackground.asColor
    }
}

struct ContinuousMonthsWeekCellView: View {

    let week: WeekRowModel

    @Environment(ContinuousMonthsViewState.self) private var state
    @Environment(ContinuousMonthsViewEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        let expectSize = CGSize(width: self.state.rowWidth, height: self.appearance.rowHeightOnCalendar.cgValue)
        WeekRowView(
            week: self.week, expectSize, isCollapsed: false,
            selectedDay: self.state.selectedDay,
            today: self.state.today,
            focusedMonth: self.state.focusedMonth,
            eventsPerDay: self.state.eventsPerDay(self.week.id),
            eventStack: self.state.eventStacks(self.week.id)
        )
        .eventHandler(\.daySelected, self.eventHandler.daySelected)
        .eventHandler(\.shareEvents, self.eventHandler.shareEvents)
        .frame(width: self.state.rowWidth)
    }
}


// MARK: - preview

final class DummyContinuousMonthsViewModel: ContinuousMonthsViewModel, @unchecked Sendable {

    private let focused = CurrentValueSubject<CalendarMonth, Never>(.init(year: 2023, month: 9))
    private let selectedDay = CurrentValueSubject<String?, Never>("2023-9-13")

    func attachListener(_ listener: any ContinuousMonthsSceneListener) { }
    func select(_ day: DayCellViewModel) {
        self.selectedDay.send(day.identifier)
    }
    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel) { }
    func scrolled(to month: CalendarMonth) {
        self.focused.send(month)
    }
    func changeFocusedMonth(to month: CalendarMonth) {
        self.focused.send(month)
    }
    func selectDay(_ day: CalendarDay) {
        self.selectedDay.send("\(day.year)-\(day.month)-\(day.day)")
    }

    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        return Just([
            .init(symbol: "SUN", "SUN", isSunday: true),
            .init(symbol: "MON", "MON"),
            .init(symbol: "TUE", "TUE"),
            .init(symbol: "WED", "WED"),
            .init(symbol: "THU", "THU"),
            .init(symbol: "FRI", "FRI"),
            .init(symbol: "SAT", "SAT", isSaturday: true)
        ])
        .eraseToAnyPublisher()
    }

    var sections: AnyPublisher<[ContinuousMonthSection], Never> {
        return self.focused
            .map { [weak self] focus in self?.dummySections(around: focus) ?? [] }
            .eraseToAnyPublisher()
    }

    var focusedMonth: AnyPublisher<CalendarMonth, Never> {
        return self.focused.eraseToAnyPublisher()
    }

    var selectedDayIdentifier: AnyPublisher<String?, Never> {
        return self.selectedDay.eraseToAnyPublisher()
    }

    var todayIdentifier: AnyPublisher<String, Never> {
        return Just("2023-9-4").eraseToAnyPublisher()
    }

    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        guard weekId == "2023-9-3-2023-9-9"
        else {
            return Just(.init(linesStack: [], shouldMarkEventDays: false)).eraseToAnyPublisher()
        }
        let period = EventOnWeek(0..<1, [4, 5, 6], (2...4), ["2023-9-4", "2023-9-5", "2023-9-6"], DummyContinuousMonthsEvent("period", "ev:period"))
        let single = EventOnWeek(0..<1, [5], (3...3), ["2023-9-5"], DummyContinuousMonthsEvent("single", "ev:single", hasPeriod: false))
        let morning = EventOnWeek(0..<1, [5], (3...3), ["2023-9-5"], DummyContinuousMonthsEvent("morning", "ev:morning", hasPeriod: false))
        let evening = EventOnWeek(0..<1, [5], (3...3), ["2023-9-5"], DummyContinuousMonthsEvent("evening", "ev:evening", hasPeriod: false))
        return Just(.init(linesStack: [[period], [single], [morning], [evening]], shouldMarkEventDays: true))
            .eraseToAnyPublisher()
    }

    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never> {
        let event = DummyContinuousMonthsEvent("dot", "ev:dot")
        let events: [[any CalendarEvent]] = weekId == "2023-9-3-2023-9-9"
            ? [[], [event], [event, event], [], [], [], []]
            : Array(repeating: [], count: 7)
        return Just(events).eraseToAnyPublisher()
    }

    private func dummySections(around focus: CalendarMonth) -> [ContinuousMonthSection] {
        let previous = focus.previousMonth()
        let next = focus.nextMonth()
        return [previous.previousMonth(), previous, focus, next, next.nextMonth()].map { month in
            ContinuousMonthSection(month: month, weeks: self.dummyWeeks(of: month))
        }
    }

    private func dummyWeeks(of month: CalendarMonth) -> [WeekRowModel] {
        let calendar = Calendar(identifier: .gregorian)
            |> \.timeZone .~ (TimeZone(abbreviation: "UTC") ?? .current)
            |> \.firstWeekday .~ DayOfWeeks.sunday.rawValue
        guard let firstDay = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1)),
              let nextFirstDay = calendar.date(byAdding: .month, value: 1, to: firstDay),
              let start = calendar.dateInterval(of: .weekOfYear, for: firstDay)?.start,
              let end = calendar.dateInterval(of: .weekOfYear, for: nextFirstDay)?.start
        else { return [] }
        let weekCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) / 7
        return (0..<weekCount).compactMap { weekIndex in
            let days = (0..<7).compactMap { offset -> CalendarComponent.Day? in
                calendar.date(byAdding: .day, value: weekIndex * 7 + offset, to: start)
                    .map { CalendarComponent.Day($0, calendar: calendar) }
            }
            return WeekRowModel(CalendarComponent.Week(days: days), month: month.month)
        }
    }
}

private struct DummyContinuousMonthsEvent: CalendarEvent {
    var eventId: String
    var name: String
    var eventTime: EventTime?
    var eventTimeOnCalendar: EventTimeOnCalendar?
    var eventTagId: EventTagId
    var isRepeating: Bool = false
    var isForemost: Bool = false
    var locationText: String?

    init(_ id: String, _ name: String, hasPeriod: Bool = true) {
        self.eventId = id
        self.name = name
        self.eventTagId = .default
        if hasPeriod {
            self.eventTimeOnCalendar = .init(.period(0..<1), timeZone: TimeZone.autoupdatingCurrent)
        }
    }
}
