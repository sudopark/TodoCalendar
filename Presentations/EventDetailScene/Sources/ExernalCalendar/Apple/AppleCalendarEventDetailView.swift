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

    var isEditable: Bool = false
    var readOnlyCalendarMessage: String?
    var eventName: String = ""
    var timeText: SelectedTime?
    var ddayText: String = ""
    var repeatText: String?
    var location: String = ""
    var url: String = ""
    var notes: String = ""
    var attendees: [AppleCalendar.Attendee] = []
    var tagModel: AppleCalendarTagModel?
    var isSavable: Bool = false
    var isSaving: Bool = false

    func bind(_ viewModel: any AppleCalendarEventDetailViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.isEditable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isEditable in
                self?.isEditable = isEditable
            })
            .store(in: &self.cancellables)

        viewModel.readOnlyCalendarMessage
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] message in
                self?.readOnlyCalendarMessage = message
            })
            .store(in: &self.cancellables)

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

        viewModel.repeatText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.repeatText = text
            })
            .store(in: &self.cancellables)

        viewModel.location
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.location = text ?? ""
            })
            .store(in: &self.cancellables)

        viewModel.url
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.url = text ?? ""
            })
            .store(in: &self.cancellables)

        viewModel.notes
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.notes = text ?? ""
            })
            .store(in: &self.cancellables)

        viewModel.attendees
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] list in
                self?.attendees = list
            })
            .store(in: &self.cancellables)

        viewModel.tagModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.tagModel = model
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


// MARK: - AppleCalendarEventDetailViewEventHandler

final class AppleCalendarEventDetailViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var openInAppleCalendar: () -> Void = { }
    var close: () -> Void = { }
    var enterName: (String) -> Void = { _ in }
    var selectStartTime: (Date) -> Void = { _ in }
    var selectEndTime: (Date) -> Void = { _ in }
    var toggleAllDay: () -> Void = { }
    var enterLocation: (String?) -> Void = { _ in }
    var enterURL: (String?) -> Void = { _ in }
    var enterNotes: (String?) -> Void = { _ in }
    var save: () -> Void = { }
    var remove: () -> Void = { }
    var selectNotEditableField: () -> Void = { }

    func bind(_ viewModel: any AppleCalendarEventDetailViewModel) {
        self.onAppear = viewModel.refresh
        self.openInAppleCalendar = viewModel.openInAppleCalendar
        self.close = viewModel.close
        self.enterName = viewModel.enter(name:)
        self.selectStartTime = viewModel.selectStartTime(_:)
        self.selectEndTime = viewModel.selectEndTime(_:)
        self.toggleAllDay = viewModel.toggleAllDay
        self.enterLocation = viewModel.enter(location:)
        self.enterURL = viewModel.enter(url:)
        self.enterNotes = viewModel.enter(notes:)
        self.save = viewModel.save
        self.remove = viewModel.remove
        self.selectNotEditableField = viewModel.selectNotEditableField
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

    private enum InputFields: String {
        case name
        case location
        case url
        case notes
        var id: String { "AppleCalendarEventDetailView::InputFields::\(self.rawValue)" }
    }
    @FocusState private var isFocusInput: InputFields?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Metric.Spacing.xlarge) {
                    self.nameInputView
                        .id(InputFields.name.id)
                        .disabled(!state.isEditable)

                    self.eventTypeView

                    VStack(spacing: Metric.Spacing.regular) {
                        self.timeSelectView
                            .disabled(!state.isEditable)

                        self.ddayView

                        if let repeatText = self.state.repeatText {
                            self.repeatView(repeatText)
                        }
                    }

                    self.locationInputView
                        .id(InputFields.location.id)
                        .disabled(!state.isEditable)

                    if !self.state.attendees.isEmpty {
                        self.attendeesView(self.state.attendees)
                    }

                    self.urlInputView
                        .id(InputFields.url.id)
                        .disabled(!state.isEditable)

                    self.memoInputView
                        .id(InputFields.notes.id)
                        .disabled(!state.isEditable)

                    if let tagModel = self.state.tagModel {
                        self.calendarNameView(tagModel)
                    }
                }
                .padding(.top, spacing: .xlarge)
                .padding(.horizontal, spacing: .regular)
                .padding(.bottom, 120)
            }
            .onChange(of: isFocusInput) { _, new in
                guard let id = new?.id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            self.bottomButtons
        }
        .allowsHitTesting(!state.isSaving)
        .background(appearance.colorSet.bg0.asColor)
    }

    private var bottomButtons: some View {
        VStack(spacing: Metric.Spacing.regular) {
            if let message = self.state.readOnlyCalendarMessage {
                DescriptionView(descriptions: [message])
            }
            HStack(spacing: Metric.Spacing.small) {
                if self.state.isEditable {
                    ConfirmButton(
                        title: "common.save".localized(),
                        isEnable: state.isSavable,
                        isProcessing: state.isSaving
                    )
                    .eventHandler(\.onTap, eventHandlers.save)
                }
                self.moreActionMenu
            }
        }
        .padding()
        .background(
            Rectangle()
                .fill(self.appearance.colorSet.dayBackground.asColor)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var moreActionMenu: some View {
        Menu {
            Section {
                Button {
                    eventHandlers.openInAppleCalendar()
                } label: {
                    Label(
                        state.isEditable
                            ? "eventDetail::appleCalendarEvent::editOnCalendar".localized()
                            : "eventDetail::appleCalendarEvent::viewOnCalendar".localized(),
                        systemImage: "arrow.up.forward.square"
                    )
                }
            }
            if state.isEditable {
                Section {
                    Button(role: .destructive) {
                        eventHandlers.remove()
                    } label: {
                        Label("common.remove".localized(), systemImage: "trash")
                    }
                }
            }
        } label: {
            MoreActionMenuLabel()
        }
    }

    private var nameInputView: some View {
        @Bindable var state = self.state
        let calendarColor: Color = self.state.tagModel
            .map { appearance.appleCalendarColor($0.calendarId).asColor }
            ?? appearance.colorSet.accent.asColor
        return EventNameInputView(
            name: $state.eventName,
            focusValue: InputFields.name,
            focusState: $isFocusInput
        ) {
            RoundedRectangle(cornerRadius: 3)
                .fill(calendarColor)
                .frame(width: 6)
        }
        .eventHandler(\.onChangeName, eventHandlers.enterName)
    }

    private var eventTypeView: some View {
        HStack(spacing: Metric.Spacing.small) {
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

    private var timeSelectView: some View {
        EventTimeSelectView(time: state.timeText)
            .eventHandler(\.onSelectStartTime, eventHandlers.selectStartTime)
            .eventHandler(\.onSelectEndTime, eventHandlers.selectEndTime)
            .eventHandler(\.onToggleAllDay, eventHandlers.toggleAllDay)
            .eventHandler(\.onBeginSelecting) { self.isFocusInput = nil }
    }

    private var ddayView: some View {
        HStack(spacing: Metric.Spacing.large) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(state.ddayText)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.normal.asFont)

            Spacer()
        }
    }

    private func repeatView(_ repeatText: String) -> some View {
        HStack(spacing: Metric.Spacing.large) {
            Image(systemName: "repeat")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(repeatText)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()
        }
        .onTapGesture {
            eventHandlers.selectNotEditableField()
        }
    }

    private var locationInputView: some View {
        @Bindable var state = self.state
        return EventTextInputRow(
            systemImageName: "location.fill",
            text: $state.location,
            placeholder: "eventDetail.place::placeholder".localized(),
            focusValue: InputFields.location,
            focusState: $isFocusInput
        )
        .eventHandler(\.onChangeText) { eventHandlers.enterLocation($0) }
    }

    private func attendeesView(_ attendees: [AppleCalendar.Attendee]) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            HStack(spacing: Metric.Spacing.large) {
                Image(systemName: "person.2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)

                Text("eventDetail::appleCalendarEvent::attendees".localized(with: attendees.count))
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                Spacer()
            }

            ForEach(Array(attendees.enumerated()), id: \.offset) { _, attendee in
                self.attendeeView(attendee)
            }
        }
        .onTapGesture {
            eventHandlers.selectNotEditableField()
        }
    }

    private func attendeeView(_ attendee: AppleCalendar.Attendee) -> some View {
        HStack(spacing: Metric.Spacing.small) {
            Image(systemName: attendee.status == .accepted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(attendee.status == .accepted
                    ? appearance.colorSet.accent.asColor
                    : appearance.colorSet.text1.asColor)

            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                Text(attendee.name ?? attendee.email ?? "")
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                if let email = attendee.email, attendee.name != nil {
                    Text(email)
                        .font(appearance.fontSet.size(13).asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                }
            }

            if attendee.isOrganizer {
                Text("eventDetail::appleCalendarEvent::attendees::organizer".localized())
                    .font(appearance.fontSet.size(12).asFont)
                    .foregroundStyle(appearance.colorSet.text1.asColor)
                    .padding(.horizontal, spacing: .small)
                    .padding(.vertical, spacing: .xxsmall)
                    .background(appearance.colorSet.bg1.asColor)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.leading, spacing: .indent)
    }

    private var urlInputView: some View {
        @Bindable var state = self.state
        return EventTextInputRow(
            systemImageName: "link",
            text: $state.url,
            placeholder: "eventDetail::appleCalendarEvent::url::placeholder".localized(),
            focusValue: InputFields.url,
            focusState: $isFocusInput
        )
        .eventHandler(\.onChangeText) { eventHandlers.enterURL($0) }
    }

    private var memoInputView: some View {
        @Bindable var state = self.state
        return EventMemoInputView(
            memo: $state.notes,
            placeholder: "eventDetail.edit::memo".localized(),
            focusValue: InputFields.notes,
            focusState: $isFocusInput
        )
        .eventHandler(\.onChangeMemo) { eventHandlers.enterNotes($0) }
    }

    private func calendarNameView(_ tagModel: AppleCalendarTagModel) -> some View {
        HStack(spacing: Metric.Spacing.large) {
            Image("apple_calendar_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 16, height: 16)

            Text(tagModel.name)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()
        }
        .onTapGesture {
            eventHandlers.selectNotEditableField()
        }
    }
}
