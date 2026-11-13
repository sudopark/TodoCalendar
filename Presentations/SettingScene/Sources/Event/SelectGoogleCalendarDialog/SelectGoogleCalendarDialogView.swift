//
//  SelectGoogleCalendarDialogView.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Extensions
import EventDomainInterface
import CommonPresentation


// MARK: - SelectGoogleCalendarDialogViewState

@Observable final class SelectGoogleCalendarDialogViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    var accountEmail: String = ""
    var calendars: [ExternalCalendarEventTagCellViewModel] = []

    func bind(_ viewModel: any SelectGoogleCalendarDialogViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        self.accountEmail = viewModel.accountId

        viewModel.calendars
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] calendars in
                self?.calendars = calendars
            })
            .store(in: self.cancellables)
    }
}


// MARK: - SelectGoogleCalendarDialogViewEventHandler

final class SelectGoogleCalendarDialogViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var toggleCalendar: (EventTagId) -> Void = { _ in }

    func bind(_ viewModel: any SelectGoogleCalendarDialogViewModel) {
        close = viewModel.close
        toggleCalendar = viewModel.toggleCalendar(_:)
    }
}


// MARK: - SelectGoogleCalendarDialogContainerView

struct SelectGoogleCalendarDialogContainerView: View {

    @State private var state: SelectGoogleCalendarDialogViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectGoogleCalendarDialogViewEventHandler

    var stateBinding: (SelectGoogleCalendarDialogViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectGoogleCalendarDialogViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return SelectGoogleCalendarDialogView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}


// MARK: - SelectGoogleCalendarDialogView

struct SelectGoogleCalendarDialogView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(SelectGoogleCalendarDialogViewState.self) private var state
    @Environment(SelectGoogleCalendarDialogViewEventHandler.self) private var eventHandlers

    var body: some View {
        BottomSlideView {

            VStack(alignment: .leading, spacing: Metric.Spacing.large) {
                SheetHeaderView(title: "event_setting::external_calendar::google::select_calendars::title".localized())
                    .eventHandler(\.onClose, eventHandlers.close)

                VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
                    Text(state.accountEmail)
                        .lineLimit(1)
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)

                    Text("event_setting::external_calendar::google::select_calendars::description".localized())
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                }

                ScrollView {
                    VStack(spacing: Metric.Spacing.small) {
                        ForEach(state.calendars) { calendar in
                            ExternalCalendarEventTagCellView(calendar)
                                .eventHandler(\.onTap) {
                                    eventHandlers.toggleCalendar(calendar.id)
                                }
                        }
                    }
                }
                .frame(maxHeight: 360)

                ConfirmButton(title: "common.confirm".localized())
                    .eventHandler(\.onTap, eventHandlers.close)
            }
        }
        .eventHandler(\.outsideTap, eventHandlers.close)
    }
}
