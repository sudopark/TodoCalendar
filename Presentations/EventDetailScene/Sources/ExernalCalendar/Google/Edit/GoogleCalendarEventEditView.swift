//
//  GoogleCalendarEventEditView.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - GoogleCalendarEventEditViewState

@Observable final class GoogleCalendarEventEditViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var eventName: String = ""
    var selectedTime: SelectedTime?
    var location: String = ""
    var memo: String = ""
    var selectedColorModel: GoogleCalendarEventColorModel?
    var isSavable: Bool = false
    var isSaving: Bool = false

    func bind(_ viewModel: any GoogleCalendarEventEditViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.eventName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.eventName = name
            })
            .store(in: &self.cancellables)

        viewModel.selectedTime
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] time in
                self?.selectedTime = time
            })
            .store(in: &self.cancellables)

        viewModel.location
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.location = text ?? ""
            })
            .store(in: &self.cancellables)

        viewModel.memo
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.memo = text ?? ""
            })
            .store(in: &self.cancellables)

        viewModel.selectedColorModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.selectedColorModel = model
            })
            .store(in: &self.cancellables)

        viewModel.isSavable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isSavable in
                self?.isSavable = isSavable
            })
            .store(in: &self.cancellables)

        viewModel.isSaving
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isSaving in
                self?.isSaving = isSaving
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - GoogleCalendarEventEditViewEventHandler

final class GoogleCalendarEventEditViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var enterName: (String) -> Void = { _ in }
    var selectStartTime: (Date) -> Void = { _ in }
    var selectEndTime: (Date) -> Void = { _ in }
    var toggleAllDay: () -> Void = { }
    var enterLocation: (String?) -> Void = { _ in }
    var enterMemo: (String?) -> Void = { _ in }
    var selectColor: (String?) -> Void = { _ in }
    var save: () -> Void = { }
    var remove: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any GoogleCalendarEventEditViewModel) {
        self.onAppear = viewModel.prepare
        self.enterName = viewModel.enter(name:)
        self.selectStartTime = viewModel.selectStartTime(_:)
        self.selectEndTime = viewModel.selectEndTime(_:)
        self.toggleAllDay = viewModel.toggleAllDay
        self.enterLocation = viewModel.enter(location:)
        self.enterMemo = viewModel.enter(memo:)
        self.selectColor = viewModel.select(colorId:)
        self.save = viewModel.save
        self.remove = viewModel.remove
        self.close = viewModel.close
    }
}


// MARK: - GoogleCalendarEventEditContainerView

struct GoogleCalendarEventEditContainerView: View {

    @State private var state: GoogleCalendarEventEditViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: GoogleCalendarEventEditViewEventHandler

    var stateBinding: (GoogleCalendarEventEditViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: GoogleCalendarEventEditViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return GoogleCalendarEventEditView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}


// MARK: - GoogleCalendarEventEditView

struct GoogleCalendarEventEditView: View {

    @Environment(GoogleCalendarEventEditViewState.self) private var state
    @Environment(GoogleCalendarEventEditViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    private enum InputFields: Hashable {
        case name
        case location
        case memo
    }
    @FocusState private var isFocusInput: InputFields?

    private enum TimeSelecting {
        case start
        case end
    }
    @State private var isTimeSelecting: TimeSelecting?

    /// Google Calendar 이벤트 색상은 계정과 무관하게 고정된 "1".."11" 팔레트다.
    private static let colorIdCandidates: [String] = (1...11).map(String.init)

    var body: some View {
        ScrollView {
            VStack(spacing: Metric.Spacing.xlarge) {
                self.nameInputView
                self.timeSelectView
                self.colorSelectView
                self.locationInputView
                self.memoInputView
            }
            .padding(.top, spacing: .xlarge)
            .padding(.horizontal, spacing: .regular)
            .padding(.bottom, spacing: .xlarge)
        }
        .safeAreaInset(edge: .bottom) {
            self.bottomButtons
        }
        .allowsHitTesting(!state.isSaving)
        .background(appearance.colorSet.bg0.asColor)
    }

    private var nameInputView: some View {
        @Bindable var state = self.state
        return TextField(
            "",
            text: $state.eventName,
            prompt: Text("eventDetail.edit::add_new_name::placeholder".localized())
                .foregroundStyle(appearance.colorSet.placeHolder.asColor)
        )
        .focused($isFocusInput, equals: .name)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .font(appearance.fontSet.size(22, weight: .semibold).asFont)
        .foregroundStyle(appearance.colorSet.text0.asColor)
        .onChange(of: state.eventName) { _, new in
            eventHandlers.enterName(new)
        }
        .onSubmit { self.isFocusInput = nil }
    }

    private var timeSelectView: some View {
        VStack(spacing: Metric.Spacing.small) {
            HStack(spacing: Metric.Spacing.large) {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(appearance.colorSet.text1.asColor)

                self.selectedTimeView()

                Spacer()

                self.toggleAllDayView
            }

            if let selecting = self.isTimeSelecting {
                self.timePickerView(selecting)
            }
        }
    }

    private func selectedTimeView() -> some View {
        guard let time = state.selectedTime else {
            return EmptyView().asAnyView()
        }
        switch time {
        case .period(let start, let end), .alldayPeriod(let start, let end):
            return HStack(spacing: Metric.Spacing.large) {
                self.timeView(start, .start)
                Image(systemName: "chevron.right")
                    .foregroundStyle(appearance.colorSet.text1.asColor)
                self.timeView(end, .end)
            }
            .asAnyView()

        case .singleAllDay(let day):
            return HStack(spacing: Metric.Spacing.large) {
                self.timeView(day, .start)
                Spacer()
            }
            .asAnyView()

        case .at(let day):
            return self.timeView(day, .start).asAnyView()
        }
    }

    private func timeView(_ text: SelectTimeText, _ position: TimeSelecting) -> some View {
        let isSelecting = self.isTimeSelecting == position
        let textColor = isSelecting ? appearance.colorSet.text1.asColor : appearance.colorSet.text0.asColor
        return EventTimeTextView(text, textColor: textColor)
            .onTapGesture {
                self.appearance.impactIfNeed()
                self.updateTimePickerShowing(position)
            }
    }

    private func updateTimePickerShowing(_ selecting: TimeSelecting) {
        appearance.withAnimationIfNeed {
            self.isTimeSelecting = self.isTimeSelecting == selecting ? nil : selecting
        }
        self.isFocusInput = nil
    }

    private var toggleAllDayView: some View {
        let isAllDay = state.selectedTime?.isAllDay ?? false
        return Button {
            eventHandlers.toggleAllDay()
        } label: {
            Text("calendar::event_time::allday".localized())
                .foregroundStyle(
                    isAllDay ? appearance.colorSet.selectedDayText.asColor : appearance.colorSet.text2.asColor
                )
                .padding(.vertical, spacing: .small)
                .padding(.horizontal, spacing: .large)
        }
        .background(self.toggleAllDayBackgroundView(isAllDay))
    }

    private func toggleAllDayBackgroundView(_ isAllDay: Bool) -> some View {
        Group {
            if isAllDay {
                RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                    .fill(appearance.colorSet.selectedDayBackground.asColor)
            } else {
                RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                    .stroke(appearance.colorSet.text2.asColor, lineWidth: 1)
            }
        }
    }

    private func timePickerView(_ selecting: TimeSelecting) -> some View {
        let isAllDay = state.selectedTime?.isAllDay ?? false
        let binding = Binding<Date>(
            get: {
                switch selecting {
                case .start: return state.selectedTime?.startDate ?? Date()
                case .end: return state.selectedTime?.endDate ?? Date()
                }
            },
            set: { newDate in
                switch selecting {
                case .start: eventHandlers.selectStartTime(newDate)
                case .end: eventHandlers.selectEndTime(newDate)
                }
            }
        )
        return DatePicker(
            "", selection: binding,
            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
        )
        .datePickerStyle(.compact)
        .labelsHidden()
        .invertColorIfNeed(appearance)
    }

    private var colorSelectView: some View {
        HStack(spacing: Metric.Spacing.small) {
            Image(systemName: "paintpalette")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metric.Spacing.small) {
                    ForEach(Self.colorIdCandidates, id: \.self) { colorId in
                        self.colorSwatch(colorId)
                    }
                }
            }
        }
    }

    private func colorSwatch(_ colorId: String) -> some View {
        let calendarId = state.selectedColorModel?.calendarId ?? ""
        let isSelected = state.selectedColorModel?.colorId == colorId
        return EventTagColorView(
            GoogleCalendarEventColorSource(calendarId: calendarId, colorId: colorId)
        ) { color in
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(appearance.colorSet.text0.asColor, lineWidth: isSelected ? 2 : 0)
                )
        }
        .onTapGesture {
            eventHandlers.selectColor(colorId)
        }
    }

    private var locationInputView: some View {
        HStack(spacing: Metric.Spacing.large) {
            Image(systemName: "map")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)

            @Bindable var state = self.state
            TextField(
                "",
                text: $state.location,
                prompt: Text("eventDetail.place::placeholder".localized())
                    .foregroundStyle(appearance.colorSet.placeHolder.asColor)
            )
            .focused($isFocusInput, equals: .location)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .foregroundStyle(appearance.colorSet.text0.asColor)
            .font(appearance.fontSet.size(14).asFont)
            .onChange(of: state.location) { _, new in
                eventHandlers.enterLocation(new)
            }
            .onSubmit { self.isFocusInput = nil }
        }
    }

    private var memoInputView: some View {
        HStack(alignment: .top, spacing: Metric.Spacing.large) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .padding(.top, spacing: .small)

            ZStack(alignment: .topLeading) {

                if state.memo.isEmpty {
                    Text("eventDetail.edit::memo".localized())
                        .foregroundStyle(appearance.colorSet.placeHolder.asColor)
                        .font(appearance.fontSet.size(14).asFont)
                        .padding(.leading, spacing: .xsmall)
                        .padding(.top, spacing: .regular)
                }

                @Bindable var state = self.state
                TextEditor(text: $state.memo)
                    .focused($isFocusInput, equals: .memo)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                    .font(appearance.fontSet.size(14).asFont)
                    .textInputAutocapitalization(.never)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .onChange(of: state.memo) { _, new in
                        eventHandlers.enterMemo(new)
                    }
            }
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: Metric.Spacing.small) {
            Button(role: .destructive) {
                eventHandlers.remove()
            } label: {
                Text("common.remove".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.accentWarn.asColor)
            }

            BottomConfirmButton(
                title: "common.save".localized(),
                isEnable: state.isSavable,
                isProcessing: state.isSaving
            )
            .eventHandler(\.onTap, eventHandlers.save)
        }
    }
}


private extension SelectedTime {

    var startDate: Date {
        switch self {
        case .at(let time): return time.date
        case .singleAllDay(let time): return time.date
        case .period(let start, _): return start.date
        case .alldayPeriod(let start, _): return start.date
        }
    }

    var endDate: Date? {
        switch self {
        case .period(_, let end): return end.date
        case .alldayPeriod(_, let end): return end.date
        default: return nil
        }
    }
}
