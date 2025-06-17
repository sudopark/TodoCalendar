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
import CommonPresentation


// MARK: - GoogleCalendarEventDetailViewState

final class GoogleCalendarEventDetailViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var hasDetailLink: Bool = false
    @Published var eventName: String?
    @Published var timeText: SelectedTime?
    @Published var repeatOptionText: String?
    @Published var calendarModel: GoogleCalendarModel?
    @Published var location: String?
    @Published var descriptionHTMLText: String?
    @Published var attachments: [AttachmentModel]?
    @Published var attendees: AttendeeListViewModel?
    @Published var conferenceData: ConferenceModel?
    
    func bind(_ viewModel: any GoogleCalendarEventDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.hasDetailLink
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] has in
                self?.hasDetailLink = has
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
        
        viewModel.repeatOPtion
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
                self?.location = text
            })
            .store(in: &self.cancellables)
        
        viewModel.descriptionHTMLText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.descriptionHTMLText = text
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
    }
}

// MARK: - GoogleCalendarEventDetailViewEventHandler

final class GoogleCalendarEventDetailViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var enterForeground: () -> Void = { }
    var editEvent: () -> Void = { }
    var selectURL: (URL) -> Void = { _ in }
    var selectAttachment: (AttachmentModel) -> Void = { _ in }
    var copyText: (String) -> Void = { _ in }
    var close: () -> Void = { }

    func bind(_ viewModel: any GoogleCalendarEventDetailViewModel) {
        // TODO: bind handlers
        onAppear = viewModel.refresh
        enterForeground = viewModel.refresh
        editEvent = viewModel.editEvent
        selectURL = viewModel.selectLink(_:)
        selectAttachment = viewModel.selectAttachment(_:)
        copyText = viewModel.copyText(_:)
        close = viewModel.close
    }
}


// MARK: - GoogleCalendarEventDetailContainerView

struct GoogleCalendarEventDetailContainerView: View {
    
    @StateObject private var state: GoogleCalendarEventDetailViewState = .init()
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - GoogleCalendarEventDetailView

struct GoogleCalendarEventDetailView: View {
    
    @EnvironmentObject private var state: GoogleCalendarEventDetailViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: GoogleCalendarEventDetailViewEventHandler
    
    var body: some View {
        ZStack {
            
            ScrollView {
                VStack(spacing: 25) {
                    self.nameView
                        .padding(.top, 20)
                    
                    self.eventTypeView
                    
                    VStack(spacing: 12) {
                        if let time = self.state.timeText {
                            self.eventTimeView(time)
                        }
                        if let repeatOption = self.state.repeatOptionText {
                            self.repeatOptionText(repeatOption)
                        }
                    }
                    if let location = state.location {
                        self.locationView(location)
                    }
                    
                    if let data = state.conferenceData {
                        self.conferenceView(data)
                    }
                    
                    if let list = state.attendees, !list.attendees.isEmpty {
                        self.attendeesView(list)
                    }
                    
                    if let description = state.descriptionHTMLText {
                        VStack(spacing: 8) {
                            self.descriptionHTMLView(description)
                            self.attachmentsView(state.attachments ?? [])
                        }
                    }
                    
                    if let model = self.state.calendarModel {
                        self.calendarView(model)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 12)
            .padding(.bottom, 120)
            
            VStack {
                Spacer()
                
                if self.state.hasDetailLink {
                    BottomConfirmButton(
                        title: "eventDetail::gogoleEvent::viewOnCalendar".localized(),
                    )
                    .eventHandler(\.onTap, self.eventHandlers.editEvent)
                }
            }
        }
        .background(appearance.colorSet.bg0.asColor)
    }
    
    private var selectedTagColor: Color {
        guard let model = self.state.calendarModel else { return .clear }
        return self.appearance.googleEventColor(model.colorId, model.calenarId).asColor
    }
    
    private var nameView: some View {
        HStack {
            
            RoundedRectangle(cornerRadius: 3)
                .fill(self.selectedTagColor)
                .frame(width: 6)
            
            Text(self.state.eventName ?? "")
                .font(appearance.fontSet.size(22, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer()
        }
    }
    
    private var eventTypeView: some View {
        HStack(spacing: 6) {
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
    
    private func eventTimeView(_ time: SelectedTime) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            switch time {
            case .period(let start, let end):
                HStack(spacing: 16) {
                    timeView(start)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(self.appearance.colorSet.text1.asColor)
                    timeView(end)
                }
                .asAnyView()
                
            case .singleAllDay(let day):
                HStack(spacing: 16) {
                    timeView(day)
                    Spacer()
                }
                .asAnyView()
                
            case .alldayPeriod(let start, let end):
                HStack(spacing: 16) {
                    timeView(start)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(self.appearance.colorSet.text1.asColor)
                    timeView(end)
                }
                .asAnyView()
                
            default:
                EmptyView()
                    .asAnyView()
            }
            
            Spacer()
        }
    }
    
    private func timeView(_ time: SelectTimeText) -> some View {
        VStack(alignment: .leading) {
            if let year = time.year {
                Text(year)
                    .font(appearance.fontSet.size(14).asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
            
            Text(time.day)
                .lineLimit(1)
                .font(self.appearance.fontSet.size(14).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            if let timeValue = time.time {
                Text(timeValue)
                    .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
    }
    
    private func repeatOptionText(_ text: String) -> some View {
        HStack {
            
            Text(text)
                .font(self.appearance.fontSet.size(14).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer()
        }
        .padding(.leading, 32)
    }
    
    private func locationView(_ location: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            Text(location)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .onTapGesture {
                    self.eventHandlers.copyText(location)
                }
            
            Spacer()
        }
    }
    
    private func conferenceView(_ model: ConferenceModel) -> some View {
        return VStack(spacing: 8) {
         
            HStack(spacing: 16) {
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
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
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
                .padding(.leading, 32)
            }
        }
    }
    
    private func attendeesView(_ list: AttendeeListViewModel) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                
                Text("eventDetail::gogoleEvent::attendees".localized(with: list.totalCounts))
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                Spacer()
            }
            
            VStack(spacing: 4) {
                ForEach(list.attendees) {
                    attendeeView($0)
                }
                .padding(.leading, 32)
            }
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
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("eventDetail::gogoleEvent::calendar".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text1.asColor)
                
                Text(model.name)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
            
            Spacer()
        }
    }
    
    private func descriptionHTMLView(_ html: String) -> some View {
        return HStack(alignment: .top, spacing: 16) {
            
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            HTMLAttributedTextView(htmlText: html) { url in
                self.eventHandlers.selectURL(url)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .asAnyView()
    }
    
    private func attachmentsView(_ attachments: [AttachmentModel]) -> some View {
        return ForEach(attachments) { attach in
            HStack {
                HStack(spacing: 6) {
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
                .padding(6)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(appearance.colorSet.line.asColor, lineWidth: 0.5)
                )
                .onTapGesture {
                    eventHandlers.selectAttachment(attach)
                }
                
                Spacer()
            }
            .padding(.leading, 32)
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
            calendars: [
                "colorId": .init(foregroundHex: "#ff0000", backgroudHex: "#ff00ff")
            ],
            events: [
                "colorId": .init(foregroundHex: "#ff0000", backgroudHex: "#ff00ff")
            ]
        )
        viewAppearance.googleCalendarColor = colors
        let state = GoogleCalendarEventDetailViewState()
        state.eventName = "google calendar event"
        state.hasDetailLink = true
        state.timeText = .period(.init(100, .current), .init(500, .current))
        state.repeatOptionText = "반복 옵션 텍스트"
        state.location = "장소 텍스트"
        state.calendarModel = .init(
            calenarId: "some", name: "some@calendar.com", colorId: "colorId"
        )
        state.descriptionHTMLText = """
        그냥 텍스트<br><b>볼드</b><br>첨부파일도 있을거다잉<br>마크다운임?<br><ol><li>목차1</li><li>목차2</li></ol><br><ul><li>목차3</li><li>목차4</li></ul><br><a href="https://www.google.com">링크다잉</a>
        """
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
        let attendees = (0..<10).map { int -> AttendeeViewModelModel in
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

