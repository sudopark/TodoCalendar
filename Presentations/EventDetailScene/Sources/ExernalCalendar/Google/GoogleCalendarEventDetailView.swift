//
//
//  GoogleCalendarEventDetailView.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//


import UIKit
import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import Scenes
import CommonPresentation


// MARK: - GoogleCalendarEventDetailViewState

@Observable final class GoogleCalendarEventDetailViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    var isEditable: Bool = false
    var readOnlyCalendarMessage: String?
    var hasDetailLink: Bool = false
    var eventColor: GoogleCalendarEventColorModel?
    var eventName: String = ""
    var timeText: SelectedTime?
    var ddayText: String?
    var repeatOptionText: String = ""
    var calendarModel: GoogleCalendarModel?
    var location: String = ""
    var memo: String = ""
    var descriptionHTMLText: AttributedString?
    var attachments: [AttachmentModel]?
    var attendees: AttendeeListViewModel?
    var conferenceData: ConferenceModel?
    var isSavable: Bool = false
    var isSaving: Bool = false
    var liveActivityActionModel: LiveActivityActionModel?

    func bind(_ viewModel: any GoogleCalendarEventDetailViewModel) {

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

        viewModel.hasDetailLink
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] has in
                self?.hasDetailLink = has
            })
            .store(in: &self.cancellables)

        viewModel.eventColorModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.eventColor = model
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

        viewModel.repeatOption
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] option in
                self?.repeatOptionText = option
            })
            .store(in: &self.cancellables)

        viewModel.calendarModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.calendarModel = model
            })
            .store(in: &self.cancellables)

        viewModel.location
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.location = text ?? ""
            })
            .store(in: &self.cancellables)

        viewModel.descriptionModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                switch model {
                case .richText(let raw):
                    self?.descriptionHTMLText = raw.asHTMLAttributeText
                    self?.memo = raw
                case .plainText(let raw):
                    self?.descriptionHTMLText = nil
                    self?.memo = raw
                }
            })
            .store(in: &self.cancellables)

        viewModel.attachments
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.attachments = models
            })
            .store(in: &self.cancellables)

        viewModel.attendees
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.attendees = model
            })
            .store(in: &self.cancellables)

        viewModel.conferenceModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.conferenceData = model
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

        viewModel.liveActivityActionModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.liveActivityActionModel = model
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - GoogleCalendarEventDetailViewEventHandler

final class GoogleCalendarEventDetailViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var enterForeground: () -> Void = { }
    var viewOnGoogleCalendar: () -> Void = { }
    var selectURL: (URL) -> Void = { _ in }
    var selectAttachment: (AttachmentModel) -> Void = { _ in }
    var copyText: (String) -> Void = { _ in }
    var close: () -> Void = { }
    var enterName: (String) -> Void = { _ in }
    var selectStartTime: (Date) -> Void = { _ in }
    var selectEndTime: (Date) -> Void = { _ in }
    var toggleAllDay: () -> Void = { }
    var enterLocation: (String?) -> Void = { _ in }
    var enterMemo: (String?) -> Void = { _ in }
    var selectColor: (String?) -> Void = { _ in }
    var save: () -> Void = { }
    var remove: () -> Void = { }
    var selectNotEditableField: () -> Void = { }
    var selectRepeatOption: () -> Void = { }
    var startEditDescription: () -> Void = { }
    var share: () -> Void = { }
    var toggleLiveActivity: (Bool) -> Void = { _ in }

    func bind(_ viewModel: any GoogleCalendarEventDetailViewModel) {
        onAppear = viewModel.refresh
        enterForeground = viewModel.refresh
        viewOnGoogleCalendar = viewModel.viewOnGoogleCalendar
        selectURL = viewModel.selectLink(_:)
        selectAttachment = viewModel.selectAttachment(_:)
        copyText = viewModel.copyText(_:)
        close = viewModel.close
        enterName = viewModel.enter(name:)
        selectStartTime = viewModel.selectStartTime(_:)
        selectEndTime = viewModel.selectEndTime(_:)
        toggleAllDay = viewModel.toggleAllDay
        enterLocation = viewModel.enter(location:)
        enterMemo = viewModel.enter(memo:)
        selectColor = viewModel.select(colorId:)
        save = viewModel.save
        remove = viewModel.remove
        selectNotEditableField = viewModel.selectNotEditableField
        selectRepeatOption = viewModel.selectRepeatOption
        startEditDescription = viewModel.startEditDescription
        share = viewModel.share
        toggleLiveActivity = viewModel.toggleLiveActivity(isRegistered:)
    }
}


// MARK: - GoogleCalendarEventDetailContainerView

struct GoogleCalendarEventDetailContainerView: View {

    @State private var state: GoogleCalendarEventDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: GoogleCalendarEventDetailViewEventHandler

    var stateBinding: (GoogleCalendarEventDetailViewState) -> Void = { _ in }

    init(
        viewAppearance: ViewAppearance,
        eventHandlers: GoogleCalendarEventDetailViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }

    var body: some View {
        return GoogleCalendarEventDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - GoogleCalendarEventDetailView

struct GoogleCalendarEventDetailView: View {

    @Environment(GoogleCalendarEventDetailViewState.self) private var state
    @Environment(GoogleCalendarEventDetailViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance

    private enum InputFields: String {
        case name
        case location
        case memo
        var id: String { "GoogleCalendarEventDetailView::InputFields::\(self.rawValue)" }
    }
    @FocusState private var isFocusInput: InputFields?

    @State private var isColorSelecting: Bool = false

    /// Google Calendar 이벤트 색상은 계정과 무관하게 고정된 "1".."11" 팔레트다.
    private static let colorIdCandidates: [String] = (1...11).map(String.init)

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
                        if let dday = self.state.ddayText {
                            self.ddayView(dday)
                        }
                        self.repeatOptionText(state.repeatOptionText)
                    }

                    self.colorSelectView
                        .disabled(!state.isEditable)

                    self.locationInputView
                        .id(InputFields.location.id)
                        .disabled(!state.isEditable)

                    if let data = state.conferenceData {
                        self.conferenceView(data)
                    }

                    if let list = state.attendees, !list.attendees.isEmpty {
                        self.attendeesView(list)
                    }

                    self.descriptionRow

                    if let attachments = state.attachments, !attachments.isEmpty {
                        self.attachmentsView(attachments)
                    }

                    if let model = self.state.calendarModel {
                        self.calendarView(model)
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            self.eventHandlers.onAppear()
        }
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
            if state.hasDetailLink {
                Section {
                    Button {
                        eventHandlers.viewOnGoogleCalendar()
                    } label: {
                        Label(
                            state.isEditable
                                ? "eventDetail::gogoleEvent::editOnCalendar".localized()
                                : "eventDetail::gogoleEvent::viewOnCalendar".localized(),
                            systemImage: "arrow.up.forward.square"
                        )
                    }
                }
            }
            Section {
                if let model = self.state.liveActivityActionModel {
                    Button {
                        eventHandlers.toggleLiveActivity(model.isRegistered)
                    } label: {
                        Label(model.itemText, systemImage: "timer")
                    }
                }

                Button {
                    eventHandlers.share()
                } label: {
                    Label(
                        "calendar::event::more_action:share:item_name".localized(),
                        systemImage: "square.and.arrow.up"
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
        return EventNameInputView(
            name: $state.eventName,
            focusValue: InputFields.name,
            focusState: $isFocusInput
        ) {
            EventTagColorView(
                GoogleCalendarEventColorSource(
                    calendarId: state.eventColor?.calendarId ?? "",
                    colorId: state.eventColor?.colorId
                )
            ) { color in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 6)
            }
        }
        .eventHandler(\.onChangeName, eventHandlers.enterName)
    }

    private var eventTypeView: some View {
        HStack(spacing: Metric.Spacing.small) {
            Image("google_calendar_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)

            Text("eventDetail::gogoleEvent::calendar::event".localized())
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

    private func ddayView(_ text: String) -> some View {
        HStack(spacing: Metric.Spacing.large) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(text)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.normal.asFont)

            Spacer()
        }
    }

    private func repeatOptionText(_ text: String) -> some View {
        HStack {

            Text(text)
                .font(self.appearance.fontSet.size(14).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)

            Spacer()
        }
        .padding(.leading, spacing: .indent)
        .onTapGesture {
            eventHandlers.selectRepeatOption()
        }
    }

    private var colorSelectView: some View {
        HStack(alignment: .top, spacing: Metric.Spacing.large) {
            Image(systemName: "paintpalette")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)

            VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                self.selectedColorChip

                if self.isColorSelecting {
                    self.colorPaletteView
                }
            }

            Spacer()
        }
    }

    private var selectedColorChip: some View {
        HStack(spacing: Metric.Spacing.small) {
            EventTagColorView(
                GoogleCalendarEventColorSource(
                    calendarId: state.eventColor?.calendarId ?? "",
                    colorId: state.eventColor?.colorId
                )
            ) { color in
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
            }

            Image(systemName: self.isColorSelecting ? "chevron.up" : "chevron.down")
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
        }
        .padding(spacing: .small)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                .fill(appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.updateColorSelectingShowing()
        }
    }

    private func updateColorSelectingShowing() {
        appearance.withAnimationIfNeed {
            self.isColorSelecting.toggle()
        }
        self.isFocusInput = nil
    }

    private var colorPaletteView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 24), spacing: Metric.Spacing.regular)],
            alignment: .leading,
            spacing: Metric.Spacing.regular
        ) {
            ForEach(Self.colorIdCandidates, id: \.self) { colorId in
                self.colorSwatch(colorId)
            }
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(appearance.colorSet.bg1.asColor)
        )
    }

    private func colorSwatch(_ colorId: String) -> some View {
        let calendarId = state.eventColor?.calendarId ?? ""
        let isSelected = state.eventColor?.colorId == colorId
        return EventTagColorView(
            GoogleCalendarEventColorSource(calendarId: calendarId, colorId: colorId)
        ) { color in
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(appearance.colorSet.line.asColor, lineWidth: 1)
                )
                .padding(spacing: .xxsmall)
                .overlay(
                    Circle()
                        .stroke(
                            appearance.colorSet.text0.asColor,
                            lineWidth: isSelected ? 2 : 0
                        )
                )
        }
        .onTapGesture {
            eventHandlers.selectColor(colorId)
        }
    }

    private var locationInputView: some View {
        @Bindable var state = self.state
        return EventTextInputRow(
            systemImageName: "map",
            text: $state.location,
            placeholder: "eventDetail.place::placeholder".localized(),
            focusValue: InputFields.location,
            focusState: $isFocusInput
        )
        .eventHandler(\.onChangeText) { eventHandlers.enterLocation($0) }
    }

    private func conferenceView(_ model: ConferenceModel) -> some View {
        return VStack(spacing: Metric.Spacing.small) {

            HStack(spacing: Metric.Spacing.large) {
                RemoteImageView(model.iconURL)
                    .resize()
                    .scaledToFill()
                    .frame(width: 16, height: 16)
                    .clipped()

                Text(model.name)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                Spacer()
            }
            .onTapGesture {
                eventHandlers.selectNotEditableField()
            }


            VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                ForEach(model.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
                            Text(entry.uri)
                                .foregroundStyle(appearance.colorSet.primaryBtnBackground.asColor)
                                .font(appearance.fontSet.subNormal.asFont)
                                .underline()
                                .onTapGesture {
                                    guard let url = URL(string: entry.uri) else { return }
                                    self.eventHandlers.selectURL(url)
                                }

                            if let key = entry.entryCodeKey, let value = entry.entryCodeValue {

                                Text("\(key): \(value)")
                                    .foregroundStyle(appearance.colorSet.text1.asColor)
                                    .font(appearance.fontSet.subNormal.asFont)
                                    .onTapGesture {
                                        self.eventHandlers.copyText(value)
                                    }
                            }
                        }

                        Spacer()
                    }
                }
                .padding(.leading, spacing: .indent)
            }
        }
    }

    private func attendeesView(_ list: AttendeeListViewModel) -> some View {
        VStack(spacing: Metric.Spacing.small) {
            HStack(spacing: Metric.Spacing.small) {
                Image(systemName: "person.2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)

                Text("eventDetail::gogoleEvent::attendees".localized(with: list.totalCounts))
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                Spacer()
            }


            VStack(spacing: Metric.Spacing.xsmall) {
                ForEach(list.attendees) {
                    attendeeView($0)
                }
                .padding(.leading, spacing: .indent)
            }
        }
        .onTapGesture {
            eventHandlers.selectNotEditableField()
        }
    }

    private func attendeeView(_ attendee: AttendeeViewModelModel) -> some View {
        HStack {

            Image(systemName: attendee.isAccepted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            VStack(alignment: .leading) {
                Text(attendee.name)
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text1.asColor)

                if attendee.isOrganizer {
                    Text("eventDetail::gogoleEvent::attendees::organizer".localized())
                        .font(appearance.fontSet.subSubNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                }
            }

            Spacer()
        }
    }

    private func calendarView(_ model: GoogleCalendarModel) -> some View {
        HStack(spacing: Metric.Spacing.large) {
            Image("google_calendar_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
                Text("eventDetail::gogoleEvent::calendar".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text1.asColor)

                Text(model.name)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }

            Spacer()
        }
        .onTapGesture {
            eventHandlers.selectNotEditableField()
        }
    }

    private var descriptionRow: some View {
        Group {
            if let html = state.descriptionHTMLText {
                self.descriptionHTMLView(html)
                    .onTapGesture {
                        eventHandlers.startEditDescription()
                    }
            } else {
                self.memoInputView
                    .id(InputFields.memo.id)
                    .disabled(!state.isEditable)
            }
        }
    }

    private func descriptionHTMLView(_ html: AttributedString) -> some View {
        return HStack(alignment: .top, spacing: Metric.Spacing.large) {

            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)

            Text(self.styledHTML(html))

            Spacer()
        }
        .asAnyView()
    }

    private func styledHTML(_ html: AttributedString) -> AttributedString {
        var styled = html
        styled.foregroundColor = appearance.colorSet.text1
        styled.font = appearance.fontSet.subNormal
        for run in styled.runs {
            if run.link != nil {
                styled[run.range].foregroundColor = appearance.colorSet.accent
            }
        }
        return styled
    }

    private var memoInputView: some View {
        @Bindable var state = self.state
        return EventMemoInputView(
            memo: $state.memo,
            placeholder: "eventDetail.edit::memo".localized(),
            focusValue: InputFields.memo,
            focusState: $isFocusInput
        )
        .eventHandler(\.onChangeMemo) { eventHandlers.enterMemo($0) }
    }

    private func attachmentsView(_ attachments: [AttachmentModel]) -> some View {
        return ForEach(attachments) { attach in
            HStack {
                HStack(spacing: Metric.Spacing.small) {
                    if let iconPath = attach.iconLink {
                        RemoteImageView(iconPath)
                            .resize()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .clipped()
                    }

                    Text(attach.title)
                        .lineLimit(1)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                        .font(appearance.fontSet.subNormal.asFont)
                }
                .padding(spacing: .small)
                .cornerRadius(Metric.Radius.chip)
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.Radius.chip)
                        .stroke(appearance.colorSet.line.asColor, lineWidth: 0.5)
                )
                .onTapGesture {
                    eventHandlers.selectAttachment(attach)
                }


                Spacer()
            }
            .padding(.leading, spacing: .indent)
        }
    }
}


extension AttachmentModel: Identifiable {}
extension AttendeeViewModelModel: Identifiable { }
extension ConferenceEntryModel: Identifiable {
    var id: String { self.uri }
}

// MARK: - preview

struct GoogleCalendarEventDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendarSetting = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let setting = AppearanceSettings(
            calendar: calendarSetting,
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let colors = GoogleCalendar.Colors(
            ownerId: "preview@google.com",
            calendars: [
                "colorId": .init(foregroundHex: "#ff0000", backgroudHex: "#ff00ff")
            ],
            events: [
                "colorId": .init(foregroundHex: "#ff0000", backgroudHex: "#ff00ff")
            ]
        )
        viewAppearance.googleCalendarColors[colors.ownerId] = colors
        let state = GoogleCalendarEventDetailViewState()
        state.eventName = "google calendar event"
        state.isEditable = true
        state.isSavable = true
        state.isSaving = false
        state.timeText = .period(.init(100, .current), .init(500, .current))
        state.ddayText = "D+3"
        state.repeatOptionText = "반복 옵션 텍스트"
        state.location = "장소 텍스트"
        state.calendarModel = .init(
            calenarId: "some", name: "some@calendar.com"
        )
        let text = """
                그냥 텍스트<br><b>볼드</b><br>첨부파일도 있을거다잉<br>마크다운임?<br><ol><li>목차1</li><li>목차2</li></ol><br><ul><li>목차3</li><li>목차4</li></ul><br><a href="https://www.google.com">링크다잉</a>
        """
//        let text = "plain text"
        state.descriptionHTMLText = text.asHTMLAttributeText
        state.memo = text
        state.attachments = [
            .init(
                id: "1VwH4QR5_vOrdbl94z3aKJfFt8PvE7F7I",
                fileURL: "some",
                title: "매우 긴 이름의 파일이름 하나둘셋넷 다섯 여섯 일곱 여덟 아홉 열 일",
                iconLink: "https://drive-thirdparty.googleusercontent.com/16/type/image/png"
            ),
            .init(
                id: "1VwH4QR5_vOrdbl94z3aKJfFt8PvE7F7I-2",
                fileURL: "some",
                title: "appstore.png",
                iconLink: "https://drive-thirdparty.googleusercontent.com/16/type/image/png"
            )
        ]
        let attendees = (0..<2).map { int -> AttendeeViewModelModel in
            return AttendeeViewModelModel("id:\(int)", "name:\(int)")
                |> \.isOrganizer .~ (int == 0)
                |> \.isAccepted .~ (int < 4)

        }
        state.attendees = .init(attendees: attendees, totalCounts: 100)

        let entries = (0..<1).map { int -> ConferenceEntryModel in
            return .init(uri: "https://some.uri.com")
                |> \.entryCodeKey .~ "Pin Code"
                |> \.entryCodeValue .~ "xifurrb"
        }
        let data = ConferenceModel(
            iconURL: "https://drive-thirdparty.googleusercontent.com/32/type/image/png",
            name: "Google meet",
            entries: entries
        )
        state.conferenceData = data

        let eventHandlers = GoogleCalendarEventDetailViewEventHandler()
        eventHandlers.selectAttachment = { _ in
            state.attachments?.removeLast()
        }

        let view = GoogleCalendarEventDetailView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}

