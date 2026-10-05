//
//  ContinuousMonthsView.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
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

