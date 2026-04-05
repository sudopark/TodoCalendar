//
//  AppleCalendarEventDetailView.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - AppleCalendarEventDetailViewState

@Observable final class AppleCalendarEventDetailViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var eventName: String = ""
    var timeText: SelectedTime?
    var ddayText: String = ""
    var location: String?
    var tagModel: AppleCalendarTagModel?

    func bind(_ viewModel: any AppleCalendarEventDetailViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.eventName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.eventName = name
            })
            .store(in: &self.cancellables)

        viewModel.timeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.timeText = text
            })
            .store(in: &self.cancellables)

        viewModel.ddayText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.ddayText = text
            })
            .store(in: &self.cancellables)

        viewModel.location
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.location = text
            })
            .store(in: &self.cancellables)

        viewModel.tagModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.tagModel = model
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - AppleCalendarEventDetailViewEventHandler

final class AppleCalendarEventDetailViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var openInAppleCalendar: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any AppleCalendarEventDetailViewModel) {
        self.onAppear = viewModel.refresh
        self.openInAppleCalendar = viewModel.openInAppleCalendar
        self.close = viewModel.close
    }
}


// MARK: - AppleCalendarEventDetailContainerView

struct AppleCalendarEventDetailContainerView: View {

    @State private var state: AppleCalendarEventDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: AppleCalendarEventDetailViewEventHandler

    var stateBinding: (AppleCalendarEventDetailViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: AppleCalendarEventDetailViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return AppleCalendarEventDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}


// MARK: - AppleCalendarEventDetailView

struct AppleCalendarEventDetailView: View {

    @Environment(ViewAppearance.self) private var appearance
    @Environment(AppleCalendarEventDetailViewState.self) private var state
    @Environment(AppleCalendarEventDetailViewEventHandler.self) private var eventHandlers

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 25) {
                    Spacer(minLength: 5)
                    self.nameView

                    self.eventTypeView

                    VStack(spacing: 16) {
                        if let timeText = self.state.timeText {
                            self.timeView(timeText)
                        }
                        self.ddayView

                        if let location = self.state.location {
                            self.locationView(location)
                        }

                        if let tagModel = self.state.tagModel {
                            self.calendarNameView(tagModel)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 12)

            VStack {
                Spacer()
                BottomConfirmButton(title: "eventDetail::appleCalendarEvent::viewOnCalendar".localized())
                    .eventHandler(\.onTap, self.eventHandlers.openInAppleCalendar)
            }
        }
        .background(appearance.colorSet.bg0.asColor)
    }

    private var eventTypeView: some View {
        HStack(spacing: 6) {
            Image("apple_calendar_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)

            Text("eventDetail::appleCalendarEvent::calendar::event".localized())
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.normal.asFont)

            Spacer()
        }
    }

    private var nameView: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(appearance.colorSet.accent.asColor)
                .frame(width: 6)

            Text(self.state.eventName)
                .font(appearance.fontSet.size(22, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()
        }
    }

    private func timeView(_ timeText: SelectedTime) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            switch timeText {
            case .at(let text):
                timeTextView(text)
                    .asAnyView()
            case .period(let start, let end):
                HStack(spacing: 8) {
                    timeTextView(start)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                    timeTextView(end)
                }
                .asAnyView()
            case .singleAllDay(let day):
                timeTextView(day)
                    .asAnyView()
            case .alldayPeriod(let start, let end):
                HStack(spacing: 8) {
                    timeTextView(start)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                    timeTextView(end)
                }
                .asAnyView()
            }

            Spacer()
        }
    }

    private func timeTextView(_ text: SelectTimeText) -> some View {
        VStack(alignment: .leading) {
            if let year = text.year {
                Text(year)
                    .font(appearance.fontSet.size(14).asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
            Text(text.day)
                .font(appearance.fontSet.size(14).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            if let time = text.time {
                Text(time)
                    .font(appearance.fontSet.size(16, weight: .semibold).asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
    }

    private var ddayView: some View {
        HStack(spacing: 16) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(state.ddayText)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.normal.asFont)

            Spacer()
        }
    }

    private func locationView(_ location: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(location)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()
        }
    }

    private func calendarNameView(_ tagModel: AppleCalendarTagModel) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(tagModel.name)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()
        }
    }
}
