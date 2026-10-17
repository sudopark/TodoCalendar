//
//  NextDayEventListView.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/7/26.
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


// MARK: - NextDayEventListViewState

@Observable final class NextDayEventListViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    fileprivate var dayModel: SelectedDayModel?
    fileprivate var cellViewModels: [any EventCellViewModel] = []
    fileprivate var foremostEventMarkingStatus: ForemostMarkingStatus = .idle

    func bind(_ viewModel: any NextDayEventListViewModel, _ appearance: ViewAppearance) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.dayModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.dayModel = model
            })
            .store(in: self.cancellables)

        viewModel.cellViewModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] cellViewModels in
                appearance?.withAnimationIfNeed {
                    self?.cellViewModels = cellViewModels
                }
            })
            .store(in: self.cancellables)

        viewModel.foremostEventMarkingStatus
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] status in
                self?.foremostEventMarkingStatus = status
            })
            .store(in: self.cancellables)
    }
}


// MARK: - NextDayEventListViewEventHandler

final class NextDayEventListViewEventHandler: Observable {
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestCancelDoneTodo: (String) -> Void = { _ in }
    var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }

    func bind(_ eventListCellEventHandleViewModel: any EventListCellEventHanleViewModel) {
        self.requestDoneTodo = eventListCellEventHandleViewModel.doneTodo(_:)
        self.requestCancelDoneTodo = eventListCellEventHandleViewModel.cancelDoneTodo(_:)
        self.requestShowDetail = eventListCellEventHandleViewModel.selectEvent(_:)
        self.handleMoreAction = eventListCellEventHandleViewModel.handleMoreAction(_:_:)
    }
}


// MARK: - NextDayEventListContainerView

struct NextDayEventListContainerView: View {

    @State private var state: NextDayEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: NextDayEventListViewEventHandler
    private let pendingDoneState: PendingCompleteTodoState

    var stateBinding: (NextDayEventListViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandler: NextDayEventListViewEventHandler,
        pendingDoneState: PendingCompleteTodoState
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
        self.pendingDoneState = pendingDoneState
    }

    var body: some View {
        return NextDayEventListView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environment(state)
            .environment(pendingDoneState)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


// MARK: - NextDayEventListView

struct NextDayEventListView: View {

    @Environment(NextDayEventListViewState.self) private var state
    @Environment(NextDayEventListViewEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            self.dateInfoView()

            if self.state.cellViewModels.isEmpty {
                self.emptyView()
            } else {
                self.eventListView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(self.appearance.colorSet.bg0.asColor)
    }

    private func dateInfoView() -> some View {
        VStack(alignment: .leading) {

            if let holidayName = self.state.dayModel?.holidayName, self.appearance.showHoliday {
                Text(holidayName)
                    .font(appearance.eventSubNormalTextFontOnList().asFont)
                    .foregroundStyle(appearance.colorSet.holidayOrWeekEndWithAccent.asColor)
            }

            HStack {
                Text(self.state.dayModel?.dateText ?? "")
                    .font(self.appearance.fontSet.size(22+appearance.eventTextAdditionalSize, weight: .semibold).asFont)
                    .foregroundColor(self.appearance.colorSet.text0.asColor)

                if self.appearance.showLunarCalendarDate {
                    Text(self.state.dayModel?.lunarDateText ?? "")
                        .font(
                            self.appearance.fontSet.size(20+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.text2.asColor)
                }
            }
            .padding(.bottom, spacing: .xsmall)
        }
    }

    private func eventListView() -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            ForEach(self.state.cellViewModels, id: \.eventIdentifier) { cellViewModel in

                EventListCellView(cellViewModel: cellViewModel, foremostEventMarkingStatus: state.foremostEventMarkingStatus)
                    .eventHandler(\.requestDoneTodo, eventHandler.requestDoneTodo)
                    .eventHandler(\.requestCancelDoneTodo, eventHandler.requestCancelDoneTodo)
                    .eventHandler(\.requestShowDetail, eventHandler.requestShowDetail)
                    .eventHandler(\.handleMoreAction, eventHandler.handleMoreAction)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func emptyView() -> some View {
        Text("calendar::event_list::next_day::empty".localized())
            .font(self.appearance.eventTextFontOnList().asFont)
            .foregroundStyle(self.appearance.colorSet.text2.asColor)
    }
}


// MARK: - preview

final class DummyNextDayEventListViewModel: NextDayEventListViewModel, @unchecked Sendable {

    private let stubDayModel: SelectedDayModel
    private let stubCellViewModels: [any EventCellViewModel]

    init(dayModel: SelectedDayModel, cellViewModels: [any EventCellViewModel]) {
        self.stubDayModel = dayModel
        self.stubCellViewModels = cellViewModels
    }

    func nextDayChanged(_ nextDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent]) { }

    var dayModel: AnyPublisher<SelectedDayModel, Never> {
        return Just(self.stubDayModel).eraseToAnyPublisher()
    }

    var cellViewModels: AnyPublisher<[any EventCellViewModel], Never> {
        return Just(self.stubCellViewModels).eraseToAnyPublisher()
    }

    var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        return Just(.idle).eraseToAnyPublisher()
    }
}

#Preview {
    let calendar = CalendarAppearanceSettings(colorSetKey: .defaultLight, fontSetKey: .systemDefault)
    let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
    let viewAppearance = ViewAppearance(
        setting: AppearanceSettings(calendar: calendar, defaultTagColor: tag), isSystemDarkTheme: false
    )
    let viewModel = DummyNextDayEventListViewModel(
        dayModel: SelectedDayModel(dateText: "2026년 7월 13일(월)", lunarDateText: "🌕 5월 29일"),
        cellViewModels: [
            ScheduleEventCellViewModel("schedule", name: "next day schedule")
                |> \.periodText .~ .singleText(.init(text: "8:30", pmOram: "AM"))
        ]
    )
    return NextDayEventListContainerView(
        viewAppearance: viewAppearance,
        eventHandler: NextDayEventListViewEventHandler(),
        pendingDoneState: PendingCompleteTodoState()
    )
    .eventHandler(\.stateBinding) { $0.bind(viewModel, viewAppearance) }
}
